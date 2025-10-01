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
   - Store main secrets in parent directory: `../.env` or `~/.config/secrets/`
   - Only put safe/read-only tokens in project `.env` (if any)
   - **Golden rule: Nothing sensitive should be in the synced folder**

## Usage:
- `runpod config` - Show current configuration
- `runpod push [source] [dest]` - Push directory to RunPod
- `runpod pull [source] [dest]` - Pull directory from RunPod
- `runpod run "command"` - Execute command on RunPod
- `runpod` - Open interactive SSH session

## Security Features:
- **Automatic exclusions**: `*.key`, `*.pem`, `.ssh/` files never synced
- **No sensitive data**: Keep all sensitive secrets outside the project directory
- **Read-only tokens**: Only use limited-scope API tokens in synced files

## Example Workflow:
```bash
cd ~/code/investigatingOwlalignment
runpod push                                    # Upload code
runpod run "cd ~/project && python script.py" # Run script
runpod pull ~/project/results/ ./results/      # Download results
```
