# RunPod Deployment

When working with projects that need GPU resources, use the `runpod` command:

When working with projects that need GPU resources, use the `runpod sync` command
to sync the code over, and then run it with `runpod run`. Avoid editing code remotely, do it
locally and then push. You can pull the results back with rsync.

## Setup:
1. Create a `.runpod_config` file in project root with RunPod's **direct TCP connection** details:
   ```bash
   RUNPOD_USER="root"
   RUNPOD_HOST="xxx.xxx.xxx.xxx"  # Direct IP from RunPod (NOT ssh.runpod.io)
   RUNPOD_PORT="xxxxx"             # Port from "SSH over exposed TCP" section
   SSH_KEY="~/.ssh/id_ed25519"
   REMOTE_PROJECT_DIR="~/project_name/"
   ```

   ⚠️ Must use the "SSH over exposed TCP" connection from RunPod dashboard, NOT the proxy endpoint.

## Usage:
- `runpod config` - Show current configuration
- `runpod sync` - Sync current directory to RunPod
- `runpod run "command"` - Execute command on RunPod
- `runpod` - Open interactive SSH session

## Example Workflow:
```bash
cd ~/code/investigatingOwlalignment
runpod sync                                                    # Upload code
runpod run "cd ~/project && python script.py"  # Run script
runpod sync ./results ~/project/results/       # Download results
```