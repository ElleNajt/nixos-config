# claudebox - Run Claude Code in Docker with auth proxy

Run Claude Code in Docker containers such that your API credentials stay on your host machine and are injected via proxy.

## Quick Start

```bash
# Run from your project directory
cd /path/to/your/project
claudebox

# With your CLAUDE.md
claudebox --mount-claude-md

# Continue previous conversation
claudebox --continue

# Run bash instead of claude
claudebox --bash

# With network firewall enabled
claudebox --firewall
```

Claude Code runs in a container with access to your current directory. API credentials stay on the host.

## How It Works

```
Host Machine                 Container                    Anthropic API
┌─────────────┐             ┌─────────────┐             ┌─────────────┐
│ Real Creds  │             │ Dummy Creds │             │             │
│ (Keychain)  │             │ (Dummy)     │             │             │
│             │             │             │             │             │
│  ┌───────┐  │             │  ┌───────┐  │             │             │
│  │ Proxy │◄─┼─────────────┼──┤Claude │  │             │             │
│  │       │  │ Intercept   │  │ Code  │  │             │             │
│  └───┬───┘  │ & Replace   │  └───────┘  │             │             │
│      │      │             │             │             │             │
│      └──────┼─────────────┼─────────────┼─────────────┤             │
│             │             │             │             │             │
└─────────────┘             └─────────────┘             └─────────────┘
```

### The Process

1. **Setup**: `claudebox` starts an authentication proxy on your host machine
2. **Container**: Docker container gets dummy credentials and proxy URL
3. **Interception**: When Claude Code makes API calls, they go to the proxy first
4. **Injection**: Proxy retrieves real credentials via `get-claude-credentials.sh` and replaces dummy access tokens in API requests
5. **Forwarding**: Proxy sends the request to Anthropic with real credentials
6. **Response**: API response flows back through proxy to Claude Code

### Components

- `claudebox` - Main script that manages Docker container and proxy
- `claude-auth-proxy.py` - Authentication proxy that injects real credentials
- `get-claude-credentials.sh` - Shared credential retrieval script (supports macOS Keychain, Linux config files)

## Prerequisites

- Docker Desktop running
- macOS (uses Keychain) or Linux (uses config files) with Claude Code credentials
- Python 3.6+

Your existing Claude Code setup should already have credentials configured. The container gets minimal config (just `hasCompletedOnboarding`) to skip setup screens.

## Options

```bash
claudebox [OPTIONS] [CLAUDE_OPTIONS]

Options:
  --mount-claude-md Mount your real CLAUDE.md file (default: none)
  --bash            Run bash instead of claude
  --verbose         Enable verbose proxy logging
  --firewall        Enable firewall (blocks most network access)
  --continue        Continue previous conversation (also -c, --resume, -r)
  --help            Show this help
```

## Security

### Security Model

**Workspace = Not Sensitive (Read-Write)**
- Your project directory (`pwd`) is mounted as read-write at `/workspace`
- Claude can create, modify, and delete code files
- This assumes project code is not sensitive

**Security-Sensitive Files = Protected (Read-Only)**

Even though the workspace is mounted read-write, specific sensitive files are remounted read-only to prevent tampering:

```bash
# These paths are remounted read-only (cannot be modified by container)
.git/hooks/            # Prevents malicious git hook injection
.git/config            # Prevents tampering with git settings (user, remotes)
.ssh/                  # Prevents SSH key/config tampering
.env*                  # Prevents credential file modification (.env, .env.local, etc.)
.runpod_config.json    # Prevents RunPod SSH key path tampering
```

Docker allows subdirectories to be remounted with different permissions, so these files are protected even though their parent directory is read-write.

**What goes into the container:**
- Dummy credentials (both access and refresh tokens replaced with dummy values)
- Minimal config (`hasCompletedOnboarding` only)
- Your current directory mounted as `/workspace` (read-write for code editing)
- Your `CLAUDE.md` file if `--mount-claude-md` is used (read-only)
- Your Claude settings, agents, and markdown files (read-only)
- Project-specific configs if they exist (read-only, excluding conversations)
- Security-sensitive files listed above (read-only)

**What stays on the host:**
- Real API credentials (retrieved from macOS Keychain or Linux config files)
- Conversation history (`.claude/projects/`)
- Security-sensitive files are read-only in container

**Resource Limits:**
- Memory: 2GB
- CPUs: 2 cores

### RunPod Integration

If a `.runpod_config.json` file exists in your project directory:

1. Config is mounted read-only to prevent tampering
2. SSH key specified in config is loaded into a shared SSH agent container
3. Agent socket is forwarded to main container via volume mount
4. Multiple claudebox instances can share the same SSH agent

The SSH agent container persists across claudebox sessions for performance.

### Conversation Continuity

When using `--continue` (or `-c`, `--resume`, `-r`):

1. Conversations are saved from container back to host on exit
2. Saved to `~/.claude/projects/<project-name>/`
3. Project name derived from current directory path
4. Future sessions can access previous conversations

**Security Note**: Saved conversations could contain sensitive information discussed during the session. They are stored outside the container on the host filesystem.

## Troubleshooting

### Proxy fails to start
```bash
# Check if Docker is running
docker info

# Run with verbose logging
claudebox --verbose
```

### No credentials found
```bash
# Verify keychain access (macOS)
security find-generic-password -s "Claude Code-credentials" -a "$(whoami)" -w

# Check Linux config file
cat ~/.claude/.credentials.json
```

### Container can't modify workspace
This is expected for protected files (`.git/hooks`, `.env`, etc.). They are intentionally read-only. For regular code files, ensure the directory permissions allow Docker to write.

### SSH agent issues with RunPod
```bash
# Check if SSH agent container is running
docker ps --filter "name=claudebox-ssh-agent"

# Restart SSH agent container
docker rm -f claudebox-ssh-agent
# Will be recreated on next claudebox run
```

## Advanced Usage

### Running Multiple Projects

Each project directory gets its own container and project-specific config:

```bash
cd ~/project-a
claudebox  # Uses ~/.claude/projects/project-a/ configs

cd ~/project-b
claudebox  # Uses ~/.claude/projects/project-b/ configs
```

### Firewall Mode

Enable firewall to block most network access (only allows Anthropic API):

```bash
claudebox --firewall
```

This initializes iptables rules inside the container to restrict outbound connections.

### Debug Mode

Run bash inside the container to debug issues:

```bash
claudebox --bash
```

This gives you a shell in the container with all mounts and environment configured.
