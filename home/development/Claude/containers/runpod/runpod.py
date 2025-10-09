#!/usr/bin/env python3
"""
RunPod Deployment Tool
"""

import json
import logging
import os
import re
import shlex
import subprocess
import sys
import textwrap
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import boto3
import requests
from dotenv import load_dotenv

logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(asctime)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

try:
    import runpod
except ImportError:
    runpod = None

# Constants
DEFAULT_IMAGE_NAME = "runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04"

# GPU display name to ID mapping from https://docs.runpod.io/references/gpu-types
GPU_DISPLAY_NAME_TO_ID = {
    "MI300X": "AMD Instinct MI300X OAM",
    "A100 PCIe": "NVIDIA A100 80GB PCIe",
    "A100 SXM": "NVIDIA A100-SXM4-80GB",
    "A30": "NVIDIA A30",
    "A40": "NVIDIA A40",
    "B200": "NVIDIA B200",
    "RTX 3070": "NVIDIA GeForce RTX 3070",
    "RTX 3080": "NVIDIA GeForce RTX 3080",
    "RTX 3080 Ti": "NVIDIA GeForce RTX 3080 Ti",
    "RTX 3090": "NVIDIA GeForce RTX 3090",
    "RTX 3090 Ti": "NVIDIA GeForce RTX 3090 Ti",
    "RTX 4070 Ti": "NVIDIA GeForce RTX 4070 Ti",
    "RTX 4080": "NVIDIA GeForce RTX 4080",
    "RTX 4080 SUPER": "NVIDIA GeForce RTX 4080 SUPER",
    "RTX 4090": "NVIDIA GeForce RTX 4090",
    "RTX 5080": "NVIDIA GeForce RTX 5080",
    "RTX 5090": "NVIDIA GeForce RTX 5090",
    "H100 SXM": "NVIDIA H100 80GB HBM3",
    "H100 NVL": "NVIDIA H100 NVL",
    "H100 PCIe": "NVIDIA H100 PCIe",
    "H200 SXM": "NVIDIA H200",
    "L4": "NVIDIA L4",
    "L40": "NVIDIA L40",
    "L40S": "NVIDIA L40S",
    "RTX 2000 Ada": "NVIDIA RTX 2000 Ada Generation",
    "RTX 4000 Ada": "NVIDIA RTX 4000 Ada Generation",
    "RTX 5000 Ada": "NVIDIA RTX 5000 Ada Generation",
    "RTX 6000 Ada": "NVIDIA RTX 6000 Ada Generation",
    "RTX A2000": "NVIDIA RTX A2000",
    "RTX A4000": "NVIDIA RTX A4000",
    "RTX A4500": "NVIDIA RTX A4500",
    "RTX A5000": "NVIDIA RTX A5000",
    "RTX A6000": "NVIDIA RTX A6000",
    "RTX PRO 6000": "NVIDIA RTX PRO 6000 Blackwell Workstation Edition",
    "V100 FHHL": "Tesla V100-FHHL-16GB",
    "Tesla V100": "Tesla V100-PCIE-16GB",
    "V100 SXM2": "Tesla V100-SXM2-16GB",
}
GPU_ID_TO_DISPLAY_NAME = {v: k for k, v in GPU_DISPLAY_NAME_TO_ID.items()}


def find_config() -> Optional[Path]:
    """Find .runpod_config.json in git repository root or current directory."""
    # First check current directory
    cwd_config = Path.cwd() / ".runpod_config.json"
    if cwd_config.is_file():
        return cwd_config

    try:
        # Find git repository root
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        repo_root = Path(result.stdout.strip())
        config_file = repo_root / ".runpod_config.json"
        return config_file if config_file.is_file() else None
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Not in a git repo or git not available
        return None


def load_config(config_file: Path) -> Dict[str, str]:
    """Load and validate JSON configuration."""
    # Security check: ensure config file is a regular file, not a symlink/device
    if not config_file.is_file() or config_file.is_symlink():
        print(
            f"❌ Config file must be a regular file (not symlink/device): {config_file}"
        )
        sys.exit(1)

    try:
        with open(config_file) as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON in {config_file}: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error reading {config_file}: {e}")
        sys.exit(1)

    # Validate required fields
    required = ["user", "host", "port", "ssh_key", "remote_dir"]
    missing = [field for field in required if not config.get(field)]
    if missing:
        print(f"❌ Missing required fields in {config_file}: {', '.join(missing)}")
        sys.exit(1)

    # Validate config values for security (before quoting)
    validate_config_values(config)

    # Make all config values shell-safe by quoting them
    config["user"] = shlex.quote(config["user"])
    config["host"] = shlex.quote(config["host"])
    config["port"] = shlex.quote(config["port"])
    config["remote_dir"] = shlex.quote(config["remote_dir"])
    # SSH key will be quoted when expanded to Path

    return config


def validate_ssh_key_path(ssh_key_path: str) -> Path:
    """Validate SSH key is in expected locations only."""
    # Check if running in container and key is available
    container_key = Path("/home/node/.ssh/runpod_key")
    if container_key.is_file():
        return container_key

    ssh_key = Path(ssh_key_path).expanduser().resolve()

    # Only allow keys in standard SSH directories
    allowed_dirs = [
        Path.home() / ".ssh",
        Path("/etc/ssh"),  # System keys
    ]

    for allowed_dir in allowed_dirs:
        try:
            ssh_key.relative_to(allowed_dir.resolve())
            # Additional check that file exists and is readable
            if not ssh_key.is_file():
                print(f"❌ SSH key not found: {ssh_key}")
                sys.exit(1)
            return ssh_key  # Path is within allowed directory
        except ValueError:
            continue

    print(f"❌ SSH key must be in ~/.ssh/ or /etc/ssh/, got: {ssh_key}")
    sys.exit(1)


def validate_config_values(config: Dict[str, str]) -> None:
    """Validate configuration values for security."""

    # Validate hostname (alphanumeric, dots, hyphens only)
    if not re.match(r"^[a-zA-Z0-9.-]+$", config["host"]):
        print(f"❌ Invalid host format: {config['host']}")
        sys.exit(1)

    # Validate port (numeric, 1-65535)
    try:
        port = int(config["port"])
        if not (1 <= port <= 65535):
            raise ValueError()
    except ValueError:
        print(f"❌ Invalid port: {config['port']} (must be 1-65535)")
        sys.exit(1)

    # Validate username (alphanumeric and common safe chars)
    if not re.match(r"^[a-zA-Z0-9_.-]+$", config["user"]):
        print(f"❌ Invalid user format: {config['user']}")
        sys.exit(1)

    # Validate SSH key path is in allowed directories
    validate_ssh_key_path(config["ssh_key"])

    # Validate remote directory (allow tilde for home directory)
    if not re.match(r"^[a-zA-Z0-9_.~/-]+$", config["remote_dir"]):
        print(f"❌ Invalid remote directory format: {config['remote_dir']}")
        sys.exit(1)


def validate_source_path(source_path: str) -> Path:
    """Validate source path is within current directory tree."""
    current_real = Path.cwd().resolve()
    try:
        source_real = Path(source_path).resolve()
    except Exception:
        print(f"❌ Invalid source directory: {source_path}")
        sys.exit(1)

    # Check if source is current directory or subdirectory
    try:
        source_real.relative_to(current_real)
    except ValueError:
        print(f"❌ Security error: Can only sync current directory or subdirectories")
        print(f"   Attempted: {source_path}")
        print(f"   Resolved to: {source_real}")
        print(f"   Current dir: {current_real}")
        print(f"   Use 'cd' to change to the directory you want to sync")
        sys.exit(1)

    return source_real


def ensure_host_in_known_hosts(config: Dict[str, str]) -> None:
    """Ensure the host is in known_hosts."""
    host = config["host"]
    port = config["port"]

    ssh_dir = Path.home() / ".ssh"
    known_hosts = ssh_dir / "known_hosts"

    # Check if host is already in known_hosts
    if known_hosts.exists():
        with open(known_hosts) as f:
            content = f.read()
            if f"[{host}]:{port}" in content or f"{host}" in content:
                return

    print(f"🔑 Adding {host}:{port} to known_hosts...")
    try:
        # Run ssh-keyscan and append to known_hosts
        result = subprocess.run(
            ["ssh-keyscan", "-p", port, host],
            capture_output=True,
            text=True,
            check=True,
        )

        # Append to known_hosts
        with open(known_hosts, "a") as f:
            f.write(result.stdout)

        print(f"✅ Added {host}:{port} to known_hosts")
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Warning: Could not scan host keys: {e}")
        print("   You may need to manually accept the host key on first connection")
    except Exception as e:
        print(f"⚠️  Warning: Could not update known_hosts: {e}")


def run_ssh_command(
    config: Dict[str, str], command: str, force_tty: bool = False
) -> None:
    """Run command on remote server via SSH."""
    ensure_host_in_known_hosts(config)
    ssh_key = Path(config["ssh_key"]).expanduser()

    cmd = [
        "ssh",
        "-i",
        str(ssh_key),
        "-p",
        config["port"],
    ]

    # Force pseudo-TTY allocation for interactive commands
    if force_tty:
        cmd.append("-t")

    cmd.append(f"{config['user']}@{config['host']}")

    # Only add command if it's not empty (for interactive sessions)
    if command.strip():
        cmd.append(command)

    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ SSH command failed with exit code {e.returncode}")
        sys.exit(1)
    except FileNotFoundError:
        print("❌ ssh command not found")
        sys.exit(1)


def push_directory(config: Dict[str, str], source_dir: str, dest_dir: str) -> None:
    """Push directory to remote server via rsync."""
    ensure_host_in_known_hosts(config)
    source_path = validate_source_path(source_dir)
    ssh_key = Path(config["ssh_key"]).expanduser()

    print(f"📤 Pushing {source_dir} to RunPod:{dest_dir}")

    cmd = [
        "rsync",
        "-avz",
        "--progress",
        # Exclude sensitive files
        "--exclude=*.key",  # No key files
        "--exclude=*.pem",  # No PEM files
        "--exclude=.ssh/",  # No SSH keys
        "--exclude=__pycache__/",  # No Python cache
        "--exclude=.git/",  # No git directory
        "--exclude=venv/",  # No venv (created on remote)
        "--exclude=.direnv/",  # No direnv
        "-e",
        f"ssh -i {shlex.quote(str(ssh_key))} -p {config['port']}",
        f"{shlex.quote(str(source_path))}/",
        f"{config['user']}@{config['host']}:{shlex.quote(dest_dir)}",
    ]

    try:
        subprocess.run(cmd, check=True)
        print("✅ Push complete")

    except subprocess.CalledProcessError as e:
        print(f"❌ Rsync failed with exit code {e.returncode}")
        sys.exit(1)
    except FileNotFoundError:
        print("❌ rsync command not found")
        sys.exit(1)


def pull_directory(config: Dict[str, str], source_dir: str, dest_dir: str) -> None:
    """Pull directory from remote server via rsync."""
    dest_path = validate_source_path(dest_dir)
    ssh_key = Path(config["ssh_key"]).expanduser()

    print(f"📥 Pulling RunPod:{source_dir} to {dest_dir}")

    cmd = [
        "rsync",
        "-avz",
        "--progress",
        # Exclude sensitive files
        "--exclude=*.key",  # No key files
        "--exclude=*.pem",  # No PEM files
        "--exclude=.ssh/",  # No SSH keys
        "--exclude=__pycache__/",  # No Python cache
        "--exclude=.git/",  # No git directory
        "--exclude=venv/",  # No venv (created on remote)
        "--exclude=.direnv/",  # No direnv
        "-e",
        f"ssh -i {shlex.quote(str(ssh_key))} -p {config['port']}",
        f"{config['user']}@{config['host']}:{shlex.quote(source_dir)}",
        f"{shlex.quote(str(dest_path))}/",
    ]

    try:
        subprocess.run(cmd, check=True)
        print("✅ Pull complete")

    except subprocess.CalledProcessError as e:
        print(f"❌ Rsync failed with exit code {e.returncode}")
        sys.exit(1)
    except FileNotFoundError:
        print("❌ rsync command not found")
        sys.exit(1)


def getenv(key: str) -> str:
    """Get required environment variable or fail."""
    value = os.getenv(key)
    if not value:
        raise ValueError(f"{key} not found in environment. Set it in your .env file.")
    return value


def load_env_file(env_path: Optional[str] = None) -> None:
    """Load .env file for API credentials."""
    if env_path:
        logging.info(f"Using .env file: {env_path}")
        env_path_expanded = os.path.expanduser(env_path)
        if not os.path.exists(env_path_expanded):
            raise FileNotFoundError(
                f"Specified .env file not found: {env_path_expanded}"
            )
        load_dotenv(override=True, dotenv_path=env_path_expanded)
    else:
        xdg_config_dir = os.environ.get(
            "XDG_CONFIG_HOME", os.path.expanduser("~/.config")
        )
        env_paths = [".env", os.path.join(xdg_config_dir, "runpod_cli/.env")]
        env_exists = [os.path.exists(os.path.expanduser(path)) for path in env_paths]
        if not any(env_exists):
            raise FileNotFoundError(f"No .env file found in {env_paths}")
        if env_exists.count(True) > 1:
            raise FileExistsError(f"Multiple .env files found in {env_paths}")
        load_dotenv(
            override=True,
            dotenv_path=os.path.expanduser(env_paths[env_exists.index(True)]),
        )


def get_region_from_volume_id(volume_id: str) -> str:
    """Get region from network volume ID."""
    api_key = os.getenv("RUNPOD_API_KEY")
    url = f"https://rest.runpod.io/v1/networkvolumes/{volume_id}"
    headers = {"Authorization": f"Bearer {api_key}"}
    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        raise ValueError(f"Failed to get volume info: {response.text}")
    volume_info = response.json()
    return volume_info.get("dataCenterId")


def get_s3_endpoint_from_volume_id(volume_id: str) -> str:
    """Get S3 endpoint from network volume ID."""
    data_center_id = get_region_from_volume_id(volume_id)
    s3_endpoint = f"https://s3api-{data_center_id.lower()}.runpod.io/"
    return s3_endpoint


def get_gpu_id(gpu_type: str) -> Tuple[str, str]:
    """Convert GPU type name or ID to standardized ID and display name."""
    gpu_type = str(gpu_type)
    if gpu_type in GPU_DISPLAY_NAME_TO_ID:
        gpu_id = GPU_DISPLAY_NAME_TO_ID[gpu_type]
        gpu_name = gpu_type
    elif gpu_type in GPU_ID_TO_DISPLAY_NAME:
        gpu_id = gpu_type
        gpu_name = GPU_ID_TO_DISPLAY_NAME[gpu_id]
    else:
        matches = [
            gpu_id
            for gpu_name, gpu_id in GPU_DISPLAY_NAME_TO_ID.items()
            if gpu_type.lower() in gpu_id.lower()
            or gpu_type.lower() in gpu_name.lower()
        ]
        if len(matches) == 1:
            gpu_id = matches[0]
            gpu_name = GPU_ID_TO_DISPLAY_NAME[gpu_id]
        elif len(matches) > 1:
            raise ValueError(
                f"Ambiguous GPU type: {gpu_type} matches {matches}. Please use a full name or ID from https://docs.runpod.io/references/gpu-types"
            )
        else:
            raise ValueError(f"Unknown GPU type: {gpu_type}")
    return gpu_id, gpu_name


def parse_time_remaining(pod: Dict) -> str:
    """Parse time remaining from pod docker args and status."""
    _sleep_re = re.compile(r"\bsleep\s+(\d+)\b")
    _date_re = re.compile(
        r":\s*(\w{3}\s+\w{3}\s+\d{2}\s+\d{4}\s+\d{2}:\d{2}:\d{2})\s+GMT"
    )
    start_dt = None
    sleep_secs = None
    last_status_change = pod.get("lastStatusChange", "")
    if isinstance(last_status_change, str):
        match = _date_re.search(last_status_change)
        if match:
            start_dt = datetime.strptime(
                match.group(1), "%a %b %d %Y %H:%M:%S"
            ).replace(tzinfo=timezone.utc)
    docker_args = pod.get("dockerArgs", "")
    if isinstance(docker_args, str):
        match = _sleep_re.search(docker_args)
        if match:
            sleep_secs = int(match.group(1))
    if start_dt is not None and sleep_secs is not None:
        now_dt = datetime.now(timezone.utc)
        shutdown_dt = start_dt + timedelta(seconds=sleep_secs)
        remaining = shutdown_dt - now_dt
        total = int(remaining.total_seconds())
        remaining_str = f"{total // 3600}h {(total % 3600) // 60}m"
        return remaining_str if total > 0 else "Unknown"
    else:
        return "Unknown"


def show_config(config: Dict[str, str], config_file: Path) -> None:
    """Show current configuration."""
    print(f"📋 RunPod Configuration ({config_file}):")
    print(f"   User: {config['user']}")
    print(f"   Host: {config['host']}")
    print(f"   Port: {config['port']}")
    print(f"   SSH Key: {config['ssh_key']}")
    print(f"   Remote Dir: {config['remote_dir']}")


def ensure_gitignore(pattern: str) -> None:
    """Ensure pattern is in .gitignore."""
    gitignore_path = Path(".gitignore")

    # Check if we're in a git repo
    if not Path(".git").exists():
        return

    # Read existing gitignore
    if gitignore_path.exists():
        with open(gitignore_path, "r") as f:
            content = f.read()
        if pattern in content:
            return

    # Add pattern
    with open(gitignore_path, "a") as f:
        if gitignore_path.exists() and not content.endswith("\n"):
            f.write("\n")
        f.write(f"{pattern}\n")

    logging.info(f"Added {pattern} to .gitignore")


def mount_directory(config: Dict[str, str], mount_point: Optional[str] = None) -> None:
    """Mount RunPod remote directory using SSHFS."""
    if mount_point is None:
        mount_point = "./.runpod-mount"

    mount_path = Path(mount_point).resolve()

    # Check if already mounted
    result = subprocess.run(
        ["mount"],
        capture_output=True,
        text=True,
    )
    if str(mount_path) in result.stdout:
        print(f"⚠️  {mount_path} is already mounted")
        print(f"   To unmount: fusermount -u {mount_path}")
        return

    # Create mount point if it doesn't exist
    mount_path.mkdir(parents=True, exist_ok=True)

    # Check if directory is empty
    if list(mount_path.iterdir()):
        print(f"❌ Mount point {mount_path} is not empty")
        sys.exit(1)

    # Ensure .runpod-mount is in .gitignore
    ensure_gitignore(".runpod-mount/")

    ensure_host_in_known_hosts(config)
    ssh_key = Path(config["ssh_key"]).expanduser()

    print(f"🔗 Mounting {config['user']}@{config['host']}:{config['remote_dir']}")
    print(f"   to {mount_path}")

    cmd = [
        "sshfs",
        f"{config['user']}@{config['host']}:{config['remote_dir']}",
        str(mount_path),
        "-p", config["port"],
        "-o", f"IdentityFile={ssh_key}",
        "-o", "reconnect",
        "-o", "ServerAliveInterval=15",
        "-o", "ServerAliveCountMax=3",
    ]

    subprocess.run(cmd, check=True)
    print(f"✅ Mounted successfully")
    print(f"   Work in: cd {mount_path}")
    print(f"   Unmount: fusermount -u {mount_path}")


def unmount_directory(mount_point: Optional[str] = None) -> None:
    """Unmount SSHFS mount."""
    if mount_point is None:
        mount_point = "./.runpod-mount"

    mount_path = Path(mount_point).resolve()

    print(f"🔌 Unmounting {mount_path}")

    cmd = ["fusermount", "-u", str(mount_path)]

    subprocess.run(cmd, check=True)
    print(f"✅ Unmounted successfully")


def show_help() -> None:
    """Show usage information."""
    print("🔬 RunPod Deployment Tool")
    print("=" * 50)
    print()
    print("Usage:")
    print("  Integrated Workflow:")
    print("    runpod claudepod create [--gpu_type=TYPE] [--runtime=MINS]")
    print("                                   - Create pod, sync code, mount, start Claude in container")
    print("    runpod claudepod start         - Start Claude in existing mount (reuse setup)")
    print()
    print("  SSH Commands (requires .runpod_config.json):")
    print("    runpod mount [mount_point]     - Mount remote directory via SSHFS (default: ./.runpod-mount)")
    print("    runpod unmount [mount_point]   - Unmount SSHFS mount")
    print("    runpod push [source] [dest]    - Push directory to RunPod")
    print("    runpod pull [source] [dest]    - Pull directory from RunPod")
    print("    runpod run 'command'           - Execute command on RunPod")
    print("    runpod python                  - Open interactive Python REPL on RunPod")
    print("    runpod config                  - Show current configuration")
    print("    runpod                         - Open interactive SSH session")
    print()
    print("  API Commands (requires .env file with RUNPOD_API_KEY):")
    print("    runpod create [options]        - Create a new pod")
    print("    runpod list                    - List all pods")
    print("    runpod terminate <pod_id>      - Terminate a pod")
    print()
    print("Recommended Workflow:")
    print("  1. cd ~/code/my-project")
    print("  2. runpod claudepod create --gpu_type='RTX A4000' --runtime=120")
    print("     → Creates pod, syncs code, mounts to ./.runpod-mount")
    print("  3. cd .runpod-mount && claude")
    print("     → Work in mount (single source of truth on RunPod)")
    print("  4. git commit -am 'Work' && git push local main")
    print("     → Backup work to local repo")
    print("  5. runpod terminate <pod_id>")
    print("     → Clean up (local backup remains)")
    print()
    print("SSH Configuration:")
    print("  Create .runpod_config.json with:")
    print("  {")
    print('    "user": "root",')
    print('    "host": "xxx.xxx.xxx.xxx",')
    print('    "port": "xxxxx",')
    print('    "ssh_key": "~/.ssh/id_ed25519",')
    print('    "remote_dir": "/workspace/your-project/"')
    print("  }")
    print()
    print("API Configuration:")
    print(
        "  Create .env file (in current directory or ~/.config/runpod_cli/.env) with:"
    )
    print("  RUNPOD_API_KEY=your_api_key")
    print("  RUNPOD_NETWORK_VOLUME_ID=your_volume_id")
    print("  RUNPOD_S3_ACCESS_KEY_ID=your_s3_key")
    print("  RUNPOD_S3_SECRET_KEY=your_s3_secret")


def list_pods() -> None:
    """List all pods in your RunPod account."""
    if runpod is None:
        print("❌ runpod module not installed. Install with: pip install runpod")
        sys.exit(1)

    load_env_file()
    runpod.api_key = getenv("RUNPOD_API_KEY")

    pods = runpod.get_pods()

    for i, pod in enumerate(pods):
        logging.info(f"Pod {i + 1}:")
        logging.info(f"  ID: {pod.get('id')}")
        logging.info(f"  Name: {pod.get('name')}")
        time_remaining = parse_time_remaining(pod)
        logging.info(f"  Time remaining (est.): {time_remaining}")
        logging.info(
            f"  GPUs: {pod.get('gpuCount')} x {pod.get('machine', {}).get('gpuDisplayName')}"
        )
        for key in [
            "memoryInGb",
            "vcpuCount",
            "containerDiskInGb",
            "volumeMountPath",
            "costPerHr",
        ]:
            logging.info(f"  {key}: {pod.get(key)}")
        logging.info("")


def terminate_pod(pod_id: str) -> None:
    """Terminate a specific RunPod instance."""
    if runpod is None:
        print("❌ runpod module not installed. Install with: pip install runpod")
        sys.exit(1)

    load_env_file()
    runpod.api_key = getenv("RUNPOD_API_KEY")

    logging.info(f"Terminating pod {pod_id}")
    runpod.terminate_pod(pod_id)


def create_pod(
    name: Optional[str] = None,
    runtime: int = 60,
    gpu_type: str = "RTX A4000",
    cpus: int = 1,
    disk: int = 30,
    image_name: str = DEFAULT_IMAGE_NAME,
    memory: int = 1,
    num_gpus: int = 1,
    volume_mount_path: str = "/network",
) -> Dict:
    """Create a new RunPod instance with the specified parameters. Returns pod info."""
    if runpod is None:
        print("❌ runpod module not installed. Install with: pip install runpod")
        sys.exit(1)

    load_env_file()
    runpod.api_key = getenv("RUNPOD_API_KEY")
    network_volume_id = getenv("RUNPOD_NETWORK_VOLUME_ID")
    s3_access_key_id = getenv("RUNPOD_S3_ACCESS_KEY_ID")
    s3_secret_key = getenv("RUNPOD_S3_SECRET_KEY")

    region = get_region_from_volume_id(network_volume_id)
    s3_endpoint_url = get_s3_endpoint_from_volume_id(network_volume_id)
    s3 = boto3.client(
        "s3",
        aws_access_key_id=s3_access_key_id,
        aws_secret_access_key=s3_secret_key,
        endpoint_url=s3_endpoint_url,
        region_name=region,
    )

    gpu_id, gpu_name = get_gpu_id(gpu_type)
    name = name or f"{os.getenv('USER')}-{gpu_name}"
    runpodcli_dir = f".tmp_{name.replace(' ', '_')}"

    logging.info("Creating pod with:")
    logging.info(f"  Name: {name}")
    logging.info(f"  Image: {image_name}")
    logging.info(f"  Network volume ID: {network_volume_id}")
    logging.info(f"  Region: {region}")
    logging.info(f"  GPU Type: {gpu_type}")
    logging.info(f"  GPU Count: {num_gpus}")
    logging.info(f"  Disk: {disk} GB")
    logging.info(f"  Min CPU: {cpus}")
    logging.info(f"  Min Memory: {memory} GB")
    logging.info(f"  runpodcli directory: {runpodcli_dir}")
    logging.info(f"  Time limit: {runtime} minutes")

    git_email = os.getenv("GIT_EMAIL", "")
    git_name = os.getenv("GIT_NAME", "")
    remote_scripts_path = f"{volume_mount_path}/{runpodcli_dir}"

    # Generate setup scripts (simplified versions of the utils.py functions)
    scripts = [
        (
            "start_pod.sh",
            f"#!/bin/bash\necho 'Pod started'\nsleep {max(runtime * 60, 20)}\n",
        ),
    ]

    for script_name, script_content in scripts:
        s3_key = f"{runpodcli_dir}/{script_name}"
        s3.put_object(
            Bucket=network_volume_id, Key=s3_key, Body=script_content.encode("utf-8")
        )

    docker_args = (
        "/bin/bash -c '"
        + (
            f"mkdir -p {remote_scripts_path}; bash {remote_scripts_path}/start_pod.sh; sleep {max(runtime * 60, 20)}"
        )
        + "'"
    )

    pod = runpod.create_pod(
        name=name,
        image_name=image_name,
        gpu_type_id=gpu_id,
        cloud_type="SECURE",
        gpu_count=num_gpus,
        container_disk_in_gb=disk,
        min_vcpu_count=cpus,
        min_memory_in_gb=memory,
        docker_args=docker_args,
        ports="8888/http,22/tcp",
        volume_mount_path=volume_mount_path,
        network_volume_id=network_volume_id,
    )

    pod_id = pod.get("id")
    logging.info("Pod created. Provisioning...")

    # Wait for provisioning
    for _ in range(60):
        pod = runpod.get_pod(pod_id)
        pod_runtime = pod.get("runtime")
        if pod_runtime is None or not pod_runtime.get("ports"):
            time.sleep(5)
        else:
            break

    logging.info("Pod provisioned.")
    public_ips = [i for i in pod["runtime"]["ports"] if i["isIpPublic"]]
    if len(public_ips) == 1:
        ip = public_ips[0].get("ip")
        port = public_ips[0].get("publicPort")
        logging.info(f"Public IP: {ip}:{port}")

    return pod


def claudepod_start() -> None:
    """Start claudebox in existing .runpod-mount (if already set up)."""
    current_dir = Path.cwd()
    mount_path = current_dir / ".runpod-mount"
    config_path = current_dir / ".runpod_config.json"

    # Check if setup exists
    if not config_path.exists():
        print("❌ No .runpod_config.json found")
        print("   Run: runpod claudepod create")
        sys.exit(1)

    if not mount_path.exists():
        print("❌ No .runpod-mount directory found")
        print("   Run: runpod mount")
        sys.exit(1)

    # Check if mount is actually mounted
    result = subprocess.run(["mount"], capture_output=True, text=True)
    if str(mount_path.resolve()) not in result.stdout:
        print("⚠️  .runpod-mount exists but is not mounted")
        print("   Mounting now...")
        config = load_config(config_path)
        mount_directory(config)

    print("🚀 Starting Claude in container with mounted RunPod filesystem...")
    print()

    # Run claudebox in the mount
    try:
        subprocess.run(["claudebox"], cwd=mount_path, check=True)
    except FileNotFoundError:
        print("⚠️  claudebox not found in PATH")
        print("   Run manually: cd .runpod-mount && claudebox")
    except subprocess.CalledProcessError:
        print("⚠️  claudebox exited with error")


def claudepod_create(
    gpu_type: str = "RTX A4000",
    runtime: int = 60,
    ssh_key: str = "~/.ssh/runpod_key",
    cpus: int = 1,
    disk: int = 30,
    memory: int = 1,
    num_gpus: int = 1,
) -> None:
    """Create pod, sync code, mount, and set up git remote - all in one command."""
    # Get current directory name for pod naming
    current_dir = Path.cwd()
    project_name = current_dir.name
    remote_project_dir = f"/workspace/{project_name}"
    mount_path = current_dir / ".runpod-mount"
    config_path = current_dir / ".runpod_config.json"

    # Check if already set up
    if config_path.exists() and mount_path.exists():
        print("✅ Found existing setup")
        print(f"   Config: {config_path}")
        print(f"   Mount: {mount_path}")
        print()
        print("Starting claudebox with existing setup...")
        claudepod_start()
        return

    # Create the pod
    logging.info(f"Creating pod for project: {project_name}")
    pod = create_pod(
        name=f"{project_name}-{gpu_type.replace(' ', '-')}",
        runtime=runtime,
        gpu_type=gpu_type,
        cpus=cpus,
        disk=disk,
        memory=memory,
        num_gpus=num_gpus,
        volume_mount_path="/workspace",
    )

    # Extract connection details
    pod_id = pod.get("id")
    public_ips = [i for i in pod["runtime"]["ports"] if i["isIpPublic"]]
    if len(public_ips) != 1:
        print(f"❌ Expected 1 public IP, got {len(public_ips)}")
        sys.exit(1)

    ip = public_ips[0].get("ip")
    port = public_ips[0].get("publicPort")
    user = "root"

    # Create .runpod_config.json
    config = {
        "user": user,
        "host": ip,
        "port": str(port),
        "ssh_key": ssh_key,
        "remote_dir": remote_project_dir,
    }

    config_path = current_dir / ".runpod_config.json"
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
    logging.info(f"Created {config_path}")

    # Ensure .runpod_config.json is in .gitignore
    ensure_gitignore(".runpod_config.json")

    # Load config for subsequent operations
    loaded_config = load_config(config_path)

    # Wait a bit for SSH to be ready
    logging.info("Waiting for SSH to be ready...")
    time.sleep(10)

    # Rsync current directory to RunPod
    logging.info(f"Syncing {current_dir} → RunPod:{remote_project_dir}")
    push_directory(loaded_config, ".", remote_project_dir)

    # Mount the remote directory
    logging.info("Mounting RunPod filesystem...")
    mount_directory(loaded_config)

    # Set up git remote in the mount
    mount_path = current_dir / ".runpod-mount"
    if (mount_path / ".git").exists():
        logging.info("Setting up git remote 'local' in mount...")
        subprocess.run(
            ["git", "remote", "add", "local", str(current_dir)],
            cwd=mount_path,
            capture_output=True,
        )
        logging.info("Git remote 'local' added")

    print()
    print("✅ Setup complete!")
    print()
    print(f"📁 Pod ID: {pod_id}")
    print(f"🔗 Connection: {user}@{ip}:{port}")
    print(f"📂 Remote dir: {remote_project_dir}")
    print(f"💾 Mount: {mount_path}")
    print()
    print("🚀 Starting Claude in container with mounted RunPod filesystem...")
    print()

    # Change to mount directory and run claudebox
    try:
        subprocess.run(["claudebox"], cwd=mount_path, check=True)
    except FileNotFoundError:
        print("⚠️  claudebox not found in PATH")
        print("   Run manually: cd .runpod-mount && claudebox")
    except subprocess.CalledProcessError:
        print("⚠️  claudebox exited with error")

    print()
    print("To backup work to local:")
    print(f"  cd .runpod-mount && git commit -am 'Work' && git push local main")
    print()
    print(f"To terminate pod:")
    print(f"  runpod terminate {pod_id}")


def main():
    """Main entry point."""
    # Check if this is a claudepod command
    if len(sys.argv) > 1 and sys.argv[1] == "claudepod":
        if len(sys.argv) < 3:
            print("Usage:")
            print("  runpod claudepod create [--gpu_type=TYPE] [--runtime=MINS]")
            print("  runpod claudepod start")
            sys.exit(1)
        if sys.argv[2] == "create":
            # Simple argument parsing for claudepod create
            gpu_type = "RTX A4000"
            runtime = 60
            for arg in sys.argv[3:]:
                if arg.startswith("--gpu_type="):
                    gpu_type = arg.split("=", 1)[1]
                elif arg.startswith("--runtime="):
                    runtime = int(arg.split("=", 1)[1])
            claudepod_create(gpu_type=gpu_type, runtime=runtime)
            return
        elif sys.argv[2] == "start":
            claudepod_start()
            return

    # Check if this is an API command
    if len(sys.argv) > 1 and sys.argv[1] in ["create", "list", "terminate"]:
        if sys.argv[1] == "list":
            list_pods()
            return
        elif sys.argv[1] == "terminate":
            if len(sys.argv) < 3:
                print("Usage: runpod terminate <pod_id>")
                sys.exit(1)
            terminate_pod(sys.argv[2])
            return
        elif sys.argv[1] == "create":
            # Parse create options (simplified - could use argparse for more options)
            create_pod()
            return

    # Find and load configuration for SSH commands
    config_file = find_config()
    if not config_file:
        print("❌ No .runpod_config.json found in git repository root")
        print()
        show_help()
        sys.exit(1)

    config = load_config(config_file)

    # Parse command line arguments
    if len(sys.argv) == 1:
        # Interactive SSH session
        run_ssh_command(config, "")
    elif sys.argv[1] == "config":
        show_config(config, config_file)
    elif sys.argv[1] == "help" or sys.argv[1] == "--help" or sys.argv[1] == "-h":
        show_help()
    elif sys.argv[1] == "mount":
        mount_point = sys.argv[2] if len(sys.argv) > 2 else None
        mount_directory(config, mount_point)
    elif sys.argv[1] == "unmount":
        mount_point = sys.argv[2] if len(sys.argv) > 2 else None
        unmount_directory(mount_point)
    elif sys.argv[1] == "push":
        source_dir = sys.argv[2] if len(sys.argv) > 2 else "."
        # Quote command line dest_dir for consistency with config values
        dest_dir = (
            shlex.quote(sys.argv[3]) if len(sys.argv) > 3 else config["remote_dir"]
        )
        push_directory(config, source_dir, dest_dir)
    elif sys.argv[1] == "pull":
        source_dir = (
            shlex.quote(sys.argv[2]) if len(sys.argv) > 2 else config["remote_dir"]
        )
        dest_dir = sys.argv[3] if len(sys.argv) > 3 else "."
        pull_directory(config, source_dir, dest_dir)
    elif sys.argv[1] == "run":
        if len(sys.argv) < 3:
            print("Usage: runpod run 'command to execute'")
            sys.exit(1)
        # Intentionally allow arbitrary command execution on remote server
        # This is the core feature - let Claude/user run whatever they want
        command = " ".join(sys.argv[2:])
        run_ssh_command(config, command)
    elif sys.argv[1] == "python":
        # Interactive Python REPL on remote server (needs TTY)
        run_ssh_command(config, "python3", force_tty=True)
    else:
        print(f"❌ Unknown command: {sys.argv[1]}")
        show_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
