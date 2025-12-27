#!/usr/bin/env bash
# agent-decompile wrapper script for container
cd /code/agent-compile
exec python -m src.cli.decompile "$@"
