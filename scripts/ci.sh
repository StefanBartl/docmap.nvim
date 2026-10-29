#!/usr/bin/env bash
#
# Every gate CI runs, in one command.
#
#   scripts/ci.sh              the whole pipeline, stopping at the first failure
#   scripts/ci.sh --fast       only stylua and luacheck (what a pre-push hook runs)
#   scripts/ci.sh stylua       one gate (a step of the `ci` section in .testing.lua)
#   scripts/ci.sh luacheck
#   scripts/ci.sh tests        the step `suite`
#   scripts/ci.sh conformance
#   scripts/ci.sh map
#   scripts/ci.sh standalone
#   scripts/ci.sh <options>    anything else goes to `testing ci` (--keep-going, --json=<file>, ...)
#
# A shim, not the definition. **What each gate is lives in the `ci` section of `.testing.lua`** and runs with
# `testing ci` (testing.nvim, docs/CI.md); the one gate without a preset, `standalone`, is `scripts/ci.lua`.
# `.github/workflows/ci.yml` calls this, one stage per job, so the jobs keep their independent red/green marks and
# their parallelism.
#
# Exit code 0: green. 1: a gate failed. 2: configuration error. 3: nvim or testing.nvim was not found (a gate that
# did not run must never look green). A single gate is a partial run: it is green for that gate only.
# testing.nvim is looked up in, in this order: $TESTING_NVIM_DIR, <repo>/.deps/testing.nvim, <repo>/../testing.nvim.
# The other dependencies (lib.nvim, ...) are found by `testing ci` itself.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

fail() {
  printf '\033[31m%s\033[0m\n' "$1" >&2
  exit 3
}

command -v nvim >/dev/null 2>&1 || fail "nvim is not on PATH."

DRIVER=""
for dir in "${TESTING_NVIM_DIR:-}" "$(pwd)/.deps/testing.nvim" "$(pwd)/../testing.nvim"; do
  if [[ -n "$dir" && -f "$dir/scripts/testing.lua" ]]; then
    DRIVER="$dir/scripts/testing.lua"
    break
  fi
done
[[ -n "$DRIVER" ]] || fail "testing.nvim not found (set TESTING_NVIM_DIR, clone it to .deps/testing.nvim, or put it beside this repo)."

args=()
for a in "$@"; do
  case "$a" in
    --fast) args+=("--profile=fast") ;;
    all) ;;
    tests) args+=("--step=suite") ;;
    stylua | luacheck | conformance | map | standalone) args+=("--step=$a") ;;
    *) args+=("$a") ;;
  esac
done

exec nvim -n -i NONE --headless -u NONE -l "$DRIVER" ci ${args[@]+"${args[@]}"}
