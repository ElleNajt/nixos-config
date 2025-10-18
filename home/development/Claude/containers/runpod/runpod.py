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
from pathlib import Path
from typing import Dict, List, Optional, Tuple

logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(asctime)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


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


def find_sync_ignore() -> Optional[Path]:
    """Find .runpod_sync_ignore in current directory or git repository root."""
    # First check current directory
    cwd_ignore = Path.cwd() / ".runpod_sync_ignore"
    if cwd_ignore.is_file():
        return cwd_ignore

    try:
        # Find git repository root
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        repo_root = Path(result.stdout.strip())
        ignore_file = repo_root / ".runpod_sync_ignore"
        return ignore_file if ignore_file.is_file() else None
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Not in a git repo or git not available
        return None


def load_sync_ignore() -> List[str]:
    """Load exclude patterns from .runpod_sync_ignore file.

    Returns list of patterns to exclude. Defaults to just .git/ if no file exists.
    """
    # Default excludes if no ignore file exists
    default_excludes = [
        ".git/",
    ]

    ignore_file = find_sync_ignore()

    if ignore_file is None:
        # No ignore file found, use defaults
        return default_excludes

    # Read patterns from file
    patterns = []
    try:
        with open(ignore_file) as f:
            for line in f:
                line = line.strip()
                # Skip empty lines and comments
                if line and not line.startswith("#"):
                    patterns.append(line)
    except Exception as e:
        logging.warning(f"Could not read {ignore_file}: {e}")
        return default_excludes

    return patterns


def get_rsync_excludes() -> List[str]:
    """Build rsync exclude flags from sync ignore patterns."""
    excludes = []
    for pattern in load_sync_ignore():
        excludes.extend(["--exclude", pattern])
    return excludes


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


def has_ssh_agent() -> bool:
    """Check if SSH agent is available."""
    return "SSH_AUTH_SOCK" in os.environ and Path(os.environ["SSH_AUTH_SOCK"]).exists()


def validate_ssh_key_path(ssh_key_path: str) -> Optional[Path]:
    """Validate SSH key is in expected locations only. Returns None if using SSH agent."""
    # If SSH agent is available, prefer it over key files
    if has_ssh_agent():
        return None

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
    ssh_key = validate_ssh_key_path(config["ssh_key"])

    cmd = ["ssh"]

    # Only add key if not using agent
    if ssh_key is not None:
        cmd.extend(["-i", str(ssh_key)])

    cmd.extend(["-p", config["port"]])

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
    ssh_key = validate_ssh_key_path(config["ssh_key"])

    print(f"📤 Pushing {source_dir} to RunPod:{dest_dir}")

    # Build SSH command for rsync
    if ssh_key is not None:
        ssh_cmd = f"ssh -i {shlex.quote(str(ssh_key))} -p {config['port']}"
    else:
        ssh_cmd = f"ssh -p {config['port']}"

    cmd = [
        "rsync",
        "-avz",
        "--progress",
    ]

    # Add exclude patterns from .runpod_sync_ignore
    cmd.extend(get_rsync_excludes())

    cmd.extend([
        "-e",
        ssh_cmd,
        f"{shlex.quote(str(source_path))}/",
        f"{config['user']}@{config['host']}:{shlex.quote(dest_dir)}",
    ])

    try:
        result = subprocess.run(cmd, check=False)

        # Handle rsync exit codes
        # 0 = success
        # 23 = partial transfer due to error (often permission warnings, but files transferred)
        # 24 = source files vanished before transfer
        if result.returncode == 0:
            print("✅ Push complete")
        elif result.returncode == 23:
            print("⚠️  Push complete with warnings (exit code 23: partial transfer)")
            print("   Files were transferred successfully, but some warnings occurred")
        else:
            print(f"❌ Rsync failed with exit code {result.returncode}")
            sys.exit(1)

    except FileNotFoundError:
        print("❌ rsync command not found")
        sys.exit(1)


def pull_directory(config: Dict[str, str], source_dir: str, dest_dir: str) -> None:
    """Pull directory from remote server via rsync."""
    dest_path = validate_source_path(dest_dir)
    ssh_key = validate_ssh_key_path(config["ssh_key"])

    print(f"📥 Pulling RunPod:{source_dir} to {dest_dir}")

    # Build SSH command for rsync
    if ssh_key is not None:
        ssh_cmd = f"ssh -i {shlex.quote(str(ssh_key))} -p {config['port']}"
    else:
        ssh_cmd = f"ssh -p {config['port']}"

    cmd = [
        "rsync",
        "-avz",
        "--progress",
    ]

    # Add exclude patterns from .runpod_sync_ignore
    cmd.extend(get_rsync_excludes())

    cmd.extend([
        "-e",
        ssh_cmd,
        f"{config['user']}@{config['host']}:{shlex.quote(source_dir)}",
        f"{shlex.quote(str(dest_path))}/",
    ])

    try:
        result = subprocess.run(cmd, check=False)

        # Handle rsync exit codes
        # 0 = success
        # 23 = partial transfer due to error (often permission warnings, but files transferred)
        # 24 = source files vanished before transfer
        if result.returncode == 0:
            print("✅ Pull complete")
        elif result.returncode == 23:
            print("⚠️  Pull complete with warnings (exit code 23: partial transfer)")
            print("   Files were transferred successfully, but some warnings occurred")
        else:
            print(f"❌ Rsync failed with exit code {result.returncode}")
            sys.exit(1)

    except FileNotFoundError:
        print("❌ rsync command not found")
        sys.exit(1)


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
    ssh_key = validate_ssh_key_path(config["ssh_key"])

    print(f"🔗 Mounting {config['user']}@{config['host']}:{config['remote_dir']}")
    print(f"   to {mount_path}")

    cmd = [
        "sshfs",
        f"{config['user']}@{config['host']}:{config['remote_dir']}",
        str(mount_path),
        "-p",
        config["port"],
    ]

    # Only add IdentityFile if not using agent
    if ssh_key is not None:
        cmd.extend(["-o", f"IdentityFile={ssh_key}"])

    cmd.extend(
        [
            "-o",
            "reconnect",
            "-o",
            "ServerAliveInterval=15",
            "-o",
            "ServerAliveCountMax=3",
        ]
    )

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
    print("  SSH Commands (requires .runpod_config.json):")
    print(
        "    runpod mount [mount_point]     - Mount remote directory via SSHFS (default: ./.runpod-mount)"
    )
    print("    runpod unmount [mount_point]   - Unmount SSHFS mount")
    print("    runpod push [source] [dest]    - Push directory to RunPod")
    print("    runpod pull [source] [dest]    - Pull directory from RunPod")
    print("    runpod run 'command'           - Execute command on RunPod")
    print("    runpod python                  - Open interactive Python REPL on RunPod")
    print("    runpod config                  - Show current configuration")
    print("    runpod                         - Open interactive SSH session")
    print()
    print("  API Commands (use runpodctl):")
    print("    runpodctl create               - Create a new pod")
    print("    runpodctl list                 - List all pods")
    print("    runpodctl remove <pod_id>      - Terminate a pod")
    print()
    print("Recommended Workflow:")
    print("  1. Create pod with runpodctl")
    print("  2. Get SSH connection details from RunPod dashboard")
    print("  3. Create .runpod_config.json (see below)")
    print("  4. runpod mount                → Mount remote directory")
    print("  5. cd .runpod-mount && claude  → Work in mount")
    print("  6. runpod unmount              → Unmount when done")
    print()
    print("SSH Configuration:")
    print("  Create .runpod_config.json with:")
    print("  {")
    print('    "user": "root",')
    print('    "host": "xxx.xxx.xxx.xxx",')
    print('    "port": "xxxxx",')
    print('    "ssh_key": "~/.ssh/runpod_key",')
    print('    "remote_dir": "/workspace/your-project/"')
    print("  }")
    print()
    print("Sync Ignore Configuration:")
    print("  Create .runpod_sync_ignore to customize what files to exclude")
    print("  (one pattern per line, # for comments)")
    print("  Default: only .git/ is excluded")


def main():
    """Main entry point."""
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
