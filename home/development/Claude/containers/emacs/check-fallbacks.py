#!/usr/bin/env python3
"""Check for forbidden fallback patterns in code using AST parsing."""

import ast
import json
import re
import sys
from pathlib import Path

LOG_FILE = Path("/tmp/fallback-hook.log")

def log(msg: str):
    """Log to file for debugging."""
    with LOG_FILE.open("a") as f:
        from datetime import datetime
        f.write(f"=== {datetime.now()} ===\n{msg}\n")

def check_try_except_pass(tree: ast.AST) -> list[tuple[int, str]]:
    """Find try-except blocks that only contain 'pass'."""
    issues = []

    for node in ast.walk(tree):
        if isinstance(node, ast.Try):
            for handler in node.handlers:
                # Check if except body is only 'pass'
                if len(handler.body) == 1 and isinstance(handler.body[0], ast.Pass):
                    exc_type = "bare except" if handler.type is None else ast.unparse(handler.type)
                    issues.append((handler.lineno, f"except {exc_type}: pass"))

    return issues

def check_graceful_fallback(content: str) -> list[tuple[int, str]]:
    """Find mentions of 'graceful fallback' in comments or strings."""
    pattern = re.compile(r'graceful.{0,10}fallback', re.IGNORECASE)
    issues = []

    for i, line in enumerate(content.split('\n'), 1):
        if pattern.search(line):
            issues.append((i, f"Contains 'graceful fallback': {line.strip()}"))

    return issues

def check_bash_fallbacks(content: str) -> list[tuple[int, str]]:
    """Find bash fallback patterns like || true, || :, etc."""
    issues = []

    # Pattern for || true or || : (error suppression)
    suppress_pattern = re.compile(r'\|\|\s*(true|:)(?:\s|;|$)')

    for i, line in enumerate(content.split('\n'), 1):
        # Skip comments
        code_part = line.split('#')[0]

        # Allow rm -f ... || true pattern (cleanup is okay)
        if 'rm -f' in code_part and suppress_pattern.search(code_part):
            continue

        if suppress_pattern.search(code_part):
            issues.append((i, f"Error suppression with '|| true/:': {line.strip()}"))

    return issues

def main():
    # Read hook data
    hook_data = json.load(sys.stdin)

    tool_name = hook_data.get("tool_name", "unknown")
    log(f"Tool: {tool_name}")

    # Only check Write/Edit tools
    if tool_name not in ["Write", "Edit"]:
        sys.exit(0)

    # Get content and filename
    tool_input = hook_data.get("tool_input", {})
    content = tool_input.get("content") or tool_input.get("new_string", "")
    filename = tool_input.get("file_path", "unknown")

    if not content:
        sys.exit(0)

    # Skip this script itself
    if "check-fallbacks" in filename:
        log(f"Skipping self: {filename}")
        sys.exit(0)

    # Determine file type
    is_python = filename.endswith(".py")
    is_bash = filename.endswith(".sh")

    if not is_python and not is_bash:
        log(f"Skipping non-Python/non-bash file: {filename}")
        sys.exit(0)

    # Check for graceful fallback mentions (applies to all languages)
    fallback_mentions = check_graceful_fallback(content)
    if fallback_mentions:
        lineno, desc = fallback_mentions[0]
        log(f"DETECTED: graceful fallback in {filename}:{lineno}")
        print(f"""❌ FALLBACK DETECTED in {filename}:{lineno}

Found: {desc}

Core principle: Code should FAIL, not hide errors.
- No try-except without explicit error handling
- No graceful fallbacks unless requested
- Let errors surface immediately

If this fallback is truly needed, ask the user first.""", file=sys.stderr)
        sys.exit(2)

    # Python-specific checks
    if is_python:
        # Parse Python code
        try:
            tree = ast.parse(content, filename=filename)
        except SyntaxError:
            # If code has syntax errors, let it through - other tools will catch it
            log(f"Syntax error in {filename}, skipping check")
            sys.exit(0)

        # Check for try-except-pass patterns
        issues = check_try_except_pass(tree)
        if issues:
            lineno, desc = issues[0]
            log(f"DETECTED: except-pass in {filename}:{lineno}")
            print(f"""❌ POSSIBLE FALLBACK in {filename}:{lineno}

Found: {desc}

Core principle: Code should FAIL, not hide errors.
If this is legitimate error handling, make it explicit with logging/re-raising.""", file=sys.stderr)
            sys.exit(2)

    # Bash-specific checks
    if is_bash:
        issues = check_bash_fallbacks(content)
        if issues:
            lineno, desc = issues[0]
            log(f"DETECTED: bash fallback in {filename}:{lineno}")
            print(f"""❌ BASH FALLBACK in {filename}:{lineno}

Found: {desc}

Core principle: Code should FAIL, not hide errors.
Using || true or || : suppresses errors silently.

If this is truly needed, ask the user first.""", file=sys.stderr)
            sys.exit(2)

    log("No fallbacks detected")
    sys.exit(0)

if __name__ == "__main__":
    main()
