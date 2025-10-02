# SSH Sidecar Design

## Problem
Currently, the SSH key for RunPod is mounted into the main container where Claude runs. If Claude is compromised or tricked, it could:
- Read the SSH key
- Open arbitrary SSH connections to any host
- Exfiltrate the key

## Solution
Use a sidecar container that holds the SSH key and exposes a limited HTTP API for RunPod operations.

## Architecture

```
Main Container          Sidecar Container         Host           RunPod
┌─────────────┐        ┌──────────────┐      ┌─────────┐    ┌─────────┐
│ Claude      │        │ SSH Client   │      │ Real    │    │         │
│             │        │              │      │ SSH Key │    │         │
│ runpod.py   │──HTTP──► API Server   │──SSH─┼────────►│    │ :port   │
│             │        │              │      │         │    │         │
│ Mounts:     │        │ Mounts:      │      │         │    │         │
│ - workspace │        │ - ssh key    │      │         │    │         │
│ - config    │        │   (ro)       │      │         │    │         │
│   (ro)      │        │ - config     │      │         │    │         │
│             │        │   (ro)       │      │         │    │         │
└─────────────┘        └──────────────┘      └─────────┘    └─────────┘
```

## Components

### 1. Sidecar Container
**Image:** Based on Alpine or similar minimal image
**Contains:**
- SSH client (openssh)
- Python HTTP server (simple API)
- rsync for file transfers

**Mounts:**
- `/ssh-key` - Real SSH key from host (read-only)
- `/config` - .runpod_config.json from host (read-only)
- `/workspace` - Shared workspace with main container

**API Endpoints:**
- `POST /push` - Push files to RunPod
  - Body: `{"source": "/workspace/path", "dest": "/remote/path"}`
- `POST /pull` - Pull files from RunPod
  - Body: `{"source": "/remote/path", "dest": "/workspace/path"}`
- `POST /run` - Execute command on RunPod
  - Body: `{"command": "string"}`
- `GET /config` - Return RunPod host/port (for display only)

**Security:**
- No shell access
- API only accepts operations to the host in .runpod_config.json
- No arbitrary SSH connections
- Validates all paths are within /workspace

### 2. Main Container Changes
**runpod.py:**
- Instead of executing SSH commands, make HTTP requests to sidecar
- Example: `http://runpod-sidecar:8080/push`
- No SSH key mounted
- No SSH client needed

### 3. claudebox Changes
**Startup sequence:**
1. Start sidecar container first (if .runpod_config.json exists)
2. Start main container with `--link` to sidecar
3. Pass sidecar URL as environment variable

**Docker run command:**
```bash
# Start sidecar
docker run -d \
  --name claude-ssh-sidecar-$$ \
  -v "$SSH_KEY:/ssh-key:ro" \
  -v "$(pwd)/.runpod_config.json:/config:ro" \
  -v "$(pwd):/workspace" \
  ssh-sidecar

# Start main container
docker run \
  --link claude-ssh-sidecar-$$:runpod-sidecar \
  -e RUNPOD_SIDECAR_URL=http://runpod-sidecar:8080 \
  ...
```

## Implementation Plan

1. Create sidecar Dockerfile
2. Create sidecar API server (Python)
3. Modify runpod.py to use HTTP API instead of SSH
4. Update claudebox to manage sidecar lifecycle
5. Test push/pull/run operations

## Security Properties

**Isolation:**
- Main container: No SSH key, no SSH client
- Sidecar: Has SSH key but no access to main container filesystem (except shared /workspace)
- Claude cannot read SSH key (different container)
- Claude cannot open arbitrary SSH connections (only via API)

**Blast radius:**
- If Claude compromised: Can only call RunPod API operations to configured host
- Cannot exfiltrate SSH key
- Cannot connect to arbitrary hosts

**Trust boundary:**
- Trust: SSH key stays on host + sidecar
- Don't trust: Main container where Claude runs
