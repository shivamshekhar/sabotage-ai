#!/usr/bin/env bash
# Turns the project's git hooks on (once per clone): git then runs tools/hooks/pre-commit before every commit.
# Also checks that the tools the hook needs are there. Usage: tools/install_hooks.sh
cd "$(dirname "$0")/.." || exit 2
chmod +x tools/hooks/* tools/*.sh
git config core.hooksPath tools/hooks
ok=0
python -c "import gdtoolkit" 2> /dev/null || { echo "missing: python -m pip install --user gdtoolkit" >&2; ok=1; }
command -v npm > /dev/null || { echo "missing: node and npm (https://nodejs.org)" >&2; ok=1; }
[ "$ok" -eq 0 ] && echo "Hooks on: tools/hooks/pre-commit runs before every commit."
exit "$ok"
