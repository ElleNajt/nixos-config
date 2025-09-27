# RunPod Deployment

When working with projects that need GPU resources, use the `runpod sync` command
to sync the code over, and then run it with `runpod run`. Avoid editing code remotely, do it
locally and then push. You can pull the results back with rsync.

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

2. **Dual Environment Setup** for security:
   - `.env` (local only, never synced): Contains sensitive keys like OpenAI, Anthropic
   - `.env.runpod` (synced to remote): Contains only read-only/safe keys like HF read-only token

   ```bash
   # .env (stays local)
   OPENAI_API_KEY=sk-expensive-key-here
   ANTHROPIC_API_KEY=sk-expensive-key-here
   HF_TOKEN=hf_full_write_access_token

   # .env.runpod (gets synced, becomes .env on remote)
   HF_TOKEN=hf_read_only_token_here
   TOGETHER_API_KEY=safe-inference-key
   ```

## Usage:
- `runpod config` - Show current configuration
- `runpod sync` - Sync current directory to RunPod
- `runpod run "command"` - Execute command on RunPod
- `runpod` - Open interactive SSH session

## Security Features:
- **Automatic exclusions**: `.env`, `*.key`, `*.pem`, `.ssh/` files never synced
- **Safe environment**: Only `.env.runpod` contents available on remote
- **Read-only tokens**: Use limited-scope API tokens in `.env.runpod`

## Example Workflow:
```bash
cd ~/code/investigatingOwlalignment
runpod sync                                    # Upload code (excludes .env)
runpod run "cd ~/project && python script.py" # Run script (uses .env.runpod)
runpod sync ./results ~/project/results/      # Download results
```
