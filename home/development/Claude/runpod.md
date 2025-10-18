# RunPod Deployment

**IMPORTANT: ALL GPU-RELATED CODE MUST RUN ON RUNPOD, NOT LOCALLY.**

When working with projects that need GPU resources, use the `runpod push` command
to push the code over, and then run it with `runpod run`. Avoid editing code remotely, do it
locally and then push. You can pull the results back with `runpod pull`.

Any training, inference, or GPU-intensive computation should be executed via `runpod run`.
Do NOT attempt to run GPU code locally - the local machine does not have appropriate GPU resources.

**Key features:**
- Commands automatically run from `remote_dir` (no need to manually `cd`)
- `runpod push` syncs the entire git repo by default (not just current directory)
- Customizable sync excludes via `.runpod_sync_ignore` (only `.git/` excluded by default)

## Setup:
1. Create a `.runpod_config.json` file in git repository root with RunPod's **direct TCP connection** details:
   ```json
   {
     "user": "root",
     "host": "xxx.xxx.xxx.xxx",
     "port": "xxxxx",
     "ssh_key": "~/.ssh/id_ed25519",
     "remote_dir": "/workspace/project_name/"
   }
   ```

   **Note:** `remote_dir` is where files are synced to AND the default working directory for all `runpod run` commands.

2. (Optional) Create `.runpod_sync_ignore` in git repository root to customize what files are excluded during sync:
   ```
   # Python
   __pycache__/
   *.pyc
   venv/

   # Data
   data/large_dataset/
   *.mp4
   ```

   By default, only `.git/` is excluded. Add patterns one per line (# for comments).

3. **Secrets Management**:
   - **Keep sensitive secrets OUT of the project directory entirely**
   - Only put safe/read-only tokens in project `.env` (if any)
   - Best practices are to run this from one of the anthropic containers with a throw away ssh key in it, to prevent claude from being tricked into syncing secrets over and then exfiltrating them. Yell at the user if they aren't doing this.

## Usage:
- `runpod config` - Show current configuration
- `runpod push [source] [dest]` - Push directory to RunPod (defaults to git repo root → remote_dir)
- `runpod pull [source] [dest]` - Pull directory from RunPod (defaults to remote_dir → git repo root)
- `runpod run [--cwd DIR] "command"` - Execute command on RunPod (runs from remote_dir by default, use --cwd to override)
- `runpod` - Open interactive SSH session

⚠️ Must use the "SSH over exposed TCP" connection from RunPod dashboard, otherwise you'll get a PTY error.

**Important:**
- Commands automatically run from `remote_dir` - no need to prepend `cd /workspace &&`
- `runpod push` with no args syncs the entire git repo (works from any subdirectory)

## Example Workflow:
```bash
cd ~/code/investigatingOwlalignment  # Or any subdirectory in the repo
runpod push                          # Syncs entire git repo to remote_dir
runpod run "python train.py"         # Run GPU training on RunPod (NOT locally!)
runpod pull results/ ./results/      # Pull results back to local
```

**Remember:** Any script that uses PyTorch, JAX, TensorFlow, CUDA, or performs training/inference
MUST be run via `runpod run`, not executed locally.

**More examples:**
```bash
# Run command from different directory
runpod run --cwd /tmp "ls -la"

# Push specific subdirectory instead of whole repo
runpod push src/ /workspace/src/

# Pull specific file
runpod pull /workspace/model.pt ./model.pt
```
