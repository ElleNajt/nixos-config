#!/usr/bin/env python3
"""
RunPod Deployment Tool

Tool for syncing code to RunPod and running commands remotely.

⚠️ Must use the "SSH over exposed TCP" connection from RunPod dashboard, otherwise you'll get a PTY error.

The intention for this tool is to add thse to the allowed commands for claude

"Bash(runpod:*)"

This way claude can edit files how it likes locally, and rsync them over and
execute code on the runpod machine without human intervention.

Instructions for claude in nixos-config/home/development/Claude/runpod.md

I think this is reasonably safe, as long as nothing too sensitive ends up on the runpod machine, but still:

**SECURITY CONSIDERATIONS**

1. Everything in the repo gets sent to the cloud machine, and there are no restrictions at all prevent it from being exfiltrated there.

You might be able to use a runpod image that blocks all connections except to desired endpoints,
Or just set things up so that nothing you are worried about ends up in the runpod machine.

E.g. I'm only sending over a read-only huggingface token.

2. If claude can read stuff on your computer, it can move that stuff into the repo and send it over.
Maybe mitigate with one of the anthropic containers, putting a one off ssh key into it.
(Note that your claude credentials end up in the container when you log in unless you use a fancy interception proxy.
 Unclear if you should be concerned about this.)

I don't trust the claude permissions to prevent it from reading sensitive stuff.
There are lots of issues abouts bugs in it, and claude can edit its own permissions file (!).

3. You should probably make the .runpod_config.json file uneditable by claude
(e.g. with bwrap --bind-ro, or read only owned by root, or mounted as read only in the container),
so that claude doesn't get tricked into connecting to another machine.


"""

import json
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Dict, Optional


def find_config() -> Optional[Path]:
    """Find .runpod_config.json in git repository root."""
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


def run_ssh_command(config: Dict[str, str], command: str) -> None:
    """Run command on remote server via SSH."""
    ssh_key = Path(config["ssh_key"]).expanduser()

    cmd = [
        "ssh",
        "-i",
        str(ssh_key),
        "-p",
        config["port"],
        f"{config['user']}@{config['host']}",
    ]

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


def show_config(config: Dict[str, str], config_file: Path) -> None:
    """Show current configuration."""
    print(f"📋 RunPod Configuration ({config_file}):")
    print(f"   User: {config['user']}")
    print(f"   Host: {config['host']}")
    print(f"   Port: {config['port']}")
    print(f"   SSH Key: {config['ssh_key']}")
    print(f"   Remote Dir: {config['remote_dir']}")


def show_help() -> None:
    """Show usage information."""
    print("🔬 RunPod Deployment Tool")
    print("=" * 50)
    print()
    print("Usage:")
    print("  runpod push [source] [dest]    - Push directory to RunPod")
    print("  runpod pull [source] [dest]    - Pull directory from RunPod")
    print("  runpod run 'command'           - Execute command on RunPod")
    print("  runpod config                  - Show current configuration")
    print("  runpod                         - Open interactive SSH session")
    print()
    print("Configuration:")
    print("  Create .runpod_config.json with:")
    print("  {")
    print('    "user": "root",')
    print('    "host": "xxx.xxx.xxx.xxx",')
    print('    "port": "xxxxx",')
    print('    "ssh_key": "~/.ssh/id_ed25519",')
    print('    "remote_dir": "/workspace/your-project/"')
    print("  }")


def main():
    """Main entry point."""
    # Find and load configuration
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
    else:
        print(f"❌ Unknown command: {sys.argv[1]}")
        show_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
