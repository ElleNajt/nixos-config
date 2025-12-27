#!/usr/bin/env bash
# agent-compile wrapper script for container
cd /code/agent-compile
exec python -m src.cli.compile "$@"
