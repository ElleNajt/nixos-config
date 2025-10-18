# Research Principles

When conducting research experiments (training runs, data analysis, evaluations, etc.), follow these principles to maintain reproducibility and clear record-keeping.

## Results Organization

Save all experiment results to a structured directory:
```
/results/{commithash}_{date}/
```

**Format:**
- `commithash`: First 7 characters of git commit hash (e.g., `a1b2c3d`)
- `date`: ISO format YYYY-MM-DD (e.g., `2025-10-17`)
- Example: `/results/a1b2c3d_2025-10-17/`

**What to save:**
- Model checkpoints
- Training logs and metrics
- Evaluation results
- Generated outputs/samples
- Configuration files used
- Any plots or visualizations

**Why this structure:**
- Git hash links results to exact code version
- Date provides chronological ordering
- Easy to reproduce: `git checkout a1b2c3d` + check config

## Research Journal

Maintain a `research_journal.org` (or `.md`) file in the repository root.

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
  :RESULTS: /results/a1b2c3d_2025-10-17/
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
```

## Workflow

**Before running experiments:**
1. Ensure code is committed: `git add relevant_files && git commit -m "description"`
2. Get commit hash: `git rev-parse --short HEAD`
3. Create results directory: `mkdir -p /results/{hash}_{date}/`
4. Save config to results dir: `cp config.yaml /results/{hash}_{date}/`

**During experiments:**
1. Run code via `runpod run` if using GPU
2. Save all outputs to the results directory
3. Monitor progress and note any unexpected behavior

**After experiments:**
1. Review results in `/results/{hash}_{date}/`
2. Write journal entry documenting findings
3. Commit journal updates: `git add research_journal.org && git commit -m "Journal: {brief description}"`
4. Reference the git hash in journal entry

## Example Workflow

```bash
# 1. Make changes and commit
git add train.py config.yaml
git commit -m "Increase learning rate to 5e-4"
HASH=$(git rev-parse --short HEAD)  # e.g., a1b2c3d
DATE=$(date +%Y-%m-%d)              # e.g., 2025-10-17

# 2. Create results directory
mkdir -p /results/${HASH}_${DATE}
cp config.yaml /results/${HASH}_${DATE}/

# 3. Run experiment
runpod push
runpod run "python train.py --output-dir /workspace/results/${HASH}_${DATE}"

# 4. Pull results back
runpod pull results/${HASH}_${DATE}/ ./results/${HASH}_${DATE}/

# 5. Document in journal (use Edit tool)
# Add entry to research_journal.org with hash, date, and findings

# 6. Commit journal
git add research_journal.org
git commit -m "Journal: Higher LR experiment (${HASH})"
```

## Important Notes

- **Always commit before running experiments** - you need a hash to reference
- **Don't edit journal entries retroactively** - preserve the historical record
- **Be specific in observations** - numbers and examples > vague descriptions
- **Link results and code explicitly** - future-you will thank you
- **Journal negative results too** - knowing what doesn't work is valuable
