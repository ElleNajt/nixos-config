# RunPod Deployment

When working with projects that need GPU resources, use the `runpod push` command
to push the code over, and then run it with `runpod run`. Avoid editing code remotely, do it
locally and then push. You can pull the results back with `runpod pull`.

## Setup:
1. Create a `.runpod_config.json` file in project root with RunPod's **direct TCP connection** details:
   ```json
   {
     "user": "root",
     "host": "xxx.xxx.xxx.xxx",
     "port": "xxxxx",
     "ssh_key": "~/.ssh/id_ed25519",
     "remote_dir": "~/project_name/"
   }
   ```

2. **Secrets Management**:
   - **Keep sensitive secrets OUT of the project directory entirely**
   - Only put safe/read-only tokens in project `.env` (if any)
   - Best practices are to run this from one of the anthropic containers with a throw away ssh key in it, to prevent claude from being tricked into syncing secrets over and then exfiltrating them. Yell at the user if they aren't doing this.

## Usage:
- `runpod config` - Show current configuration
- `runpod push [source] [dest]` - Push directory to RunPod
- `runpod pull [source] [dest]` - Pull directory from RunPod
- `runpod run "command"` - Execute command on RunPod
- `runpod` - Open interactive SSH session

⚠️ Must use the "SSH over exposed TCP" connection from RunPod dashboard, otherwise you'll get a PTY error.

## Example Workflow:
```bash
cd ~/code/investigatingOwlalignment
runpod push                                    # Upload code
runpod run "cd ~/project && python script.py" # Run script
runpod pull ~/project/results/ ./results/      # Download results
```
