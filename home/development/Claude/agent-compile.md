# Agent-Compile Workflow

This project uses agent-compile for spec-driven development. The spec is the source of truth, code is compiled output.

## When to use agent-compile

Use agent-compile when:
- Building a new module or feature from scratch
- You want the implementation to be reproducible from a clear specification
- You want to collaborate on design (via specs) rather than implementation details

## Workflow

1. **Create a spec file** (e.g., `spec.py`):
   ```python
   from src.core import Module
   
   my_module = Module(
       name="my_module",
       purpose="Clear, specific description of what this module does...",
       tests=[
           "Test case 1: specific behavior to verify",
           "Test case 2: edge case handling",
       ],
       language="python"  # or "rust", "javascript", etc.
   )
   ```

2. **Compile the spec**:
   ```bash
   agent-compile spec.py --output-dir compiled_src/
   ```

3. **Review the compiled code**:
   - Check `compiled_src/` for generated implementation and tests
   - Review `COMPILE_*.log` files to see compilation process
   - Verify tests pass

4. **If compilation fails** (ambiguities detected):
   - Read the ambiguity feedback
   - Refine the spec to be more specific
   - Re-compile

5. **If you need to modify**:
   - Edit the **spec** (not the compiled code)
   - Re-compile to regenerate code
   - The compiled code is throwaway - the spec is the source of truth

## Key principles

- **Never manually edit compiled code** - always edit the spec and recompile
- **Be specific in the purpose** - vague specs lead to ambiguous compilation
- **Use natural language tests** - describe behavior clearly
- **Commit both spec and compiled code** - for now, commit both (compilation not yet deterministic)

## Decompiling existing code

If you have existing code you want to spec-ify:

```bash
agent-decompile src/ --output spec.py
```

This generates a spec from your code that you can refine and re-compile.

## Commands

- `agent-compile spec.py --output-dir compiled_src/` - Compile spec to code
- `agent-decompile src/ --output spec.py` - Decompile code to spec
- `agent-compile spec.py --force` - Skip ambiguity checking
- `agent-compile spec.py --claude-command claudebox` - Use containerized Claude

## Examples

See https://github.com/ElleNajt/agent-compile/tree/master/examples for complete examples:
- calculator/ - Simple single module
- data_processor/ - Multi-module with dependencies
- ml_classifier/ - System-level modules
