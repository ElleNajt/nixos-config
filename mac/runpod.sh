#!/usr/bin/env bash


### CLAUDE.MD

# # RunPod Deployment:

# When working with projects that need GPU resources, use the `runpod` command:

# ## Setup:
# 1. Create a `.runpod_config` file in project root with RunPod's **direct TCP connection** details:
#    ```bash
#    RUNPOD_USER="root"
#    RUNPOD_HOST="xxx.xxx.xxx.xxx"  # Direct IP from RunPod (NOT ssh.runpod.io)
#    RUNPOD_PORT="xxxxx"             # Port from "SSH over exposed TCP" section
#    SSH_KEY="~/.ssh/id_ed25519"
#    REMOTE_PROJECT_DIR="~/project_name/"
#    ```

# ## Usage:
# - `runpod config` - Show current configuration
# - `runpod sync` - Sync current directory to RunPod
# - `runpod run "command"` - Execute command on RunPod
# - `runpod` - Open interactive SSH session

# ## Example Workflow:
# ```bash
# cd ~/code/investigatingOwlalignment
# runpod sync                                                    # Upload code
# runpod run "cd ~/project && python script.py"  # Run script
# runpod sync ./results ~/project/results/       # Download results
# ```

# Look for .runpod_config in current directory tree
find_config() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.runpod_config" ]; then
      echo "$dir/.runpod_config"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# Load configuration
CONFIG_FILE=$(find_config)
if [ -z "$CONFIG_FILE" ]; then
  echo "❌ No .runpod_config found in current directory or parent directories"
  echo ""
  echo "Create a .runpod_config file with RunPod's DIRECT TCP connection details:"
  echo "  RUNPOD_USER=\"root\""
  echo "  RUNPOD_HOST=\"xxx.xxx.xxx.xxx\"  # The direct IP from RunPod (NOT ssh.runpod.io)"
  echo "  RUNPOD_PORT=\"xxxxx\"            # The exposed TCP port from RunPod"
  echo "  SSH_KEY=\"~/.ssh/id_ed25519\""
  echo "  REMOTE_PROJECT_DIR=\"~/your-project/\""
  echo ""
  echo "⚠️  This script requires the 'SSH over exposed TCP' connection from RunPod,"
  echo "   NOT the proxy connection (ssh.runpod.io) which doesn't support commands."
  exit 1
fi

# Source the config file
source "$CONFIG_FILE"

# Validate required variables (RUNPOD_PORT is now required)
if [ -z "$RUNPOD_USER" ] || [ -z "$RUNPOD_HOST" ] || [ -z "$RUNPOD_PORT" ] || [ -z "$SSH_KEY" ] || [ -z "$REMOTE_PROJECT_DIR" ]; then
  echo "❌ Missing required variables in $CONFIG_FILE"
  echo "Required: RUNPOD_USER, RUNPOD_HOST, RUNPOD_PORT, SSH_KEY, REMOTE_PROJECT_DIR"
  echo ""
  echo "⚠️  RUNPOD_PORT is required - this script only works with RunPod's direct TCP connection."
  echo "   Get these details from RunPod's 'SSH over exposed TCP' section."
  exit 1
fi

# Expand tilde in SSH_KEY path
SSH_KEY="${SSH_KEY/#\~/$HOME}"

# Set up port option if RUNPOD_PORT is defined
PORT_OPT=""
if [ -n "$RUNPOD_PORT" ]; then
  PORT_OPT="-p $RUNPOD_PORT"
fi

case "$1" in
sync)
  # Sync current directory to RunPod
  shift
  SOURCE_DIR="${1:-.}"
  DEST_DIR="${2:-$REMOTE_PROJECT_DIR}"
  echo "📤 Syncing $SOURCE_DIR to RunPod:$DEST_DIR"
  echo "   Config: $CONFIG_FILE"
  rsync -avz --progress -e "ssh -i $SSH_KEY $PORT_OPT" "$SOURCE_DIR/" "$RUNPOD_USER@$RUNPOD_HOST:$DEST_DIR"
  echo "✅ Sync complete"
  ;;
run)
  # Run command on RunPod
  shift
  if [ $# -eq 0 ]; then
    echo "Usage: runpod run 'command to execute'"
    exit 1
  fi
  ssh -i "$SSH_KEY" $PORT_OPT "$RUNPOD_USER@$RUNPOD_HOST" "$@"
  ;;
config)
  # Show current configuration
  echo "📋 RunPod Configuration ($CONFIG_FILE):"
  echo "   User: $RUNPOD_USER"
  echo "   Host: $RUNPOD_HOST"
  [ -n "$RUNPOD_PORT" ] && echo "   Port: $RUNPOD_PORT"
  echo "   Key: $SSH_KEY"
  echo "   Remote Dir: $REMOTE_PROJECT_DIR"
  ;;
"")
  # Interactive shell
  ssh -i "$SSH_KEY" $PORT_OPT "$RUNPOD_USER@$RUNPOD_HOST"
  ;;
*)
  # Direct command execution
  ssh -i "$SSH_KEY" $PORT_OPT "$RUNPOD_USER@$RUNPOD_HOST" "$@"
  ;;
esac
