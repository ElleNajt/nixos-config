# Research Principles

When conducting research experiments (training runs, data analysis, evaluations, etc.), follow these principles to maintain reproducibility and clear record-keeping.

## Results Organization

**CRITICAL: When writing code for experiments, always configure output paths to save to:**
```
/results/{commithash}_{timestamp}/
```

**Format:**
- `commithash`: First 7 characters of git commit hash (e.g., `a1b2c3d`)
- `timestamp`: Unix timestamp format (e.g., `1729180800`)
- Example: `/results/a1b2c3d_1729180800/`

**This means:**
- Set `--output-dir`, `--save-dir`, `--checkpoint-dir` arguments to this path
- Configure logging to write to `{results_dir}/train.log`
- Save plots/visualizations to `{results_dir}/figures/`
- Copy config files to `{results_dir}/config.yaml`
- All model checkpoints go to `{results_dir}/checkpoints/`

**What should be saved there:**
- Model checkpoints
- Training logs and metrics
- Evaluation results
- Generated outputs/samples
- Configuration files used
- Any plots or visualizations

**Why this structure:**
- Git hash links results to exact code version
- Timestamp provides precise chronological ordering (no timezone ambiguity)
- Easy to reproduce: `git checkout a1b2c3d` + check config
- All experiment artifacts in one place

## Research Journal

Maintain a `research_journal.org`  file in the repository root.

**When to write to the journal:**

1. **Notable Observations:**
   - Unexpected behavior or results
   - Successful experiments worth remembering
   - Failed experiments with important lessons
   - Interesting patterns in data or model behavior
   - Performance breakthroughs or regressions

2. **Technical Challenges Overcome:**
   - Bugs that were hard to track down
   - Configuration issues that took time to resolve
   - Workarounds for library incompatibilities
   - Memory or performance optimizations
   - Any problem that future-you would want to know about

3. **Important Decisions:**
   - Why a particular approach was chosen
   - Architecture decisions and their rationale
   - Hyperparameter choices and reasoning
   - Dataset preprocessing decisions

**Journal Entry Format:**
```org
* [2025-10-17] Experiment: Training with increased learning rate
  :PROPERTIES:
  :GIT_HASH: a1b2c3d
  :RESULTS: /results/a1b2c3d_1729180800/
  :END:

** What was done
   Increased learning rate from 1e-4 to 5e-4 to see if training converges faster.

** Observations
   - Training converged 30% faster
   - Final loss slightly higher (0.45 vs 0.42)
   - Model outputs show more diversity but occasionally less coherent

** Technical challenges
   - Had to reduce batch size to prevent OOM errors
   - Found bug in gradient accumulation (fixed in commit xyz1234)

** Conclusions
   Higher LR trades off convergence speed for final performance. Worth exploring
   learning rate schedules that start high and decay.

** Next steps
   - Try cosine annealing schedule
   - Investigate if gradient clipping helps at higher LR

** TODOs
   For especially important follow-up tasks, add TODO items with scheduled dates:

   - TODO Try cosine annealing schedule
     SCHEDULED: <2025-10-20 Sun>
   - TODO Investigate gradient clipping at higher LR
     SCHEDULED: <2025-10-21 Mon>
```

## Workflow

**Before running experiments:**
1. Ensure code is committed: `git add relevant_files && git commit -m ""`
2. Get commit hash: `git rev-parse --short HEAD`
3. Create results directory: `mkdir -p /results/{hash}_{timestamp}/`
4. Save config to results dir: `cp config.yaml /results/{hash}_{timestamp}/`

**During experiments:**
1. Run code via `runpod run` if using GPU
2. Save all outputs to the results directory
3. Monitor progress and note any unexpected behavior

**After experiments:**
1. Review results in `/results/{hash}_{timestamp}/`
2. Write journal entry documenting findings
3. Add TODOs with scheduled dates for important follow-up work
4. Commit journal updates: `git add research_journal.org && git commit -m "Journal: {brief description}"`
5. Reference the git hash in journal entry

## Example Workflow

```bash
# 1. Make changes and commit
git add train.py config.yaml
git commit -m "Increase learning rate to 5e-4"
HASH=$(git rev-parse --short HEAD)     # e.g., a1b2c3d
TIMESTAMP=$(date +%s)                  # e.g., 1729180800

# 2. Update code to use results directory
# Edit train.py to set output_dir = f"/workspace/results/{HASH}_{TIMESTAMP}"
# OR pass as command-line argument

# 3. Run experiment (code automatically saves to correct directory)
runpod push
runpod run "python train.py --output-dir /workspace/results/${HASH}_${TIMESTAMP}"

# 4. Pull results back
runpod pull results/${HASH}_${TIMESTAMP}/ ./results/${HASH}_${TIMESTAMP}/

# 5. Document in journal (use Edit tool)
# Add entry to research_journal.org with hash, timestamp, and findings
# Add TODO items with SCHEDULED dates for important follow-up work

# 6. Commit journal
git add research_journal.org
git commit -m "Journal: Higher LR experiment (${HASH})"
```

**Key point:** The training script itself should save all outputs to the results directory.
Don't manually copy files afterward - configure the code to write there directly.

## Important Notes

- **Always commit before running experiments** - you need a hash to reference
- **Don't edit journal entries retroactively** - preserve the historical record
- **Be specific in observations** - numbers and examples > vague descriptions
- **Link results and code explicitly** - future-you will thank you
- **Journal negative results too** - knowing what doesn't work is valuable
