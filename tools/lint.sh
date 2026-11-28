#!/usr/bin/env bash
# Checks the code and the text files without running the game: GDScript lint (gdlint, settings in gdlintrc), formatting of the docs and
# settings files (prettier, settings in .prettierrc.json). Exit code 0 = clean.
#
# Usage (Git Bash, from anywhere):  tools/lint.sh          to fix the formatting too:  tools/lint.sh --fix
# Needs: python with `pip install --user gdtoolkit`, and node (`npm ci` is run when node_modules is missing). tools/install_hooks.sh checks both.
cd "$(dirname "$0")/.." || exit 2

fix=0
[ "${1:-}" = "--fix" ] && fix=1

failed=0

echo "== gdlint =="
git ls-files '*.gd' | xargs python -c "
import sys
from gdtoolkit.linter.__main__ import main
sys.argv = ['gdlint'] + sys.argv[1:]
main()" || failed=1

echo "== prettier =="
[ -d node_modules ] || npm ci --no-audit --no-fund > /dev/null || exit 2
if [ "$fix" -eq 1 ]; then
  npx prettier --write . > /dev/null || failed=1
else
  npx prettier --check . || failed=1
fi
exit "$failed"
