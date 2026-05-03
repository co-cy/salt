#!/usr/bin/env bash
# Apply (or dry-run check) all patches from patches/series via quilt.
#
# Usage:
#   scripts/apply-patches.sh           # push the whole series
#   scripts/apply-patches.sh --check   # push then pop; exit non-zero on failure
#   scripts/apply-patches.sh --pop     # pop the whole series
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

mode="apply"
case "${1:-}" in
    "")          mode="apply" ;;
    --check)     mode="check" ;;
    --pop)       mode="pop"   ;;
    -h|--help)
        sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "unknown argument: $1 (use --check, --pop, or no args)" >&2
        exit 2
        ;;
esac

if ! command -v quilt >/dev/null 2>&1; then
    echo "quilt not found in PATH (install with: brew install quilt)" >&2
    exit 127
fi

if [[ ! -f patches/series ]]; then
    echo "patches/series not found — quilt infrastructure missing" >&2
    exit 1
fi

patch_count=$(grep -cEv '^\s*(#|$)' patches/series || true)
upstream_base=$(git describe --tags --always HEAD 2>/dev/null || echo "<unknown>")

if [[ "$mode" == "pop" ]]; then
    if [[ -d .pc ]] && quilt applied >/dev/null 2>&1; then
        quilt pop -a
        echo "Popped all patches."
    else
        echo "Nothing applied."
    fi
    exit 0
fi

if [[ "$patch_count" -eq 0 ]]; then
    echo "patches/series is empty — nothing to apply (base: $upstream_base)."
    exit 0
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree has uncommitted changes — refuse to push patches." >&2
    echo "Commit or stash first, or run: scripts/apply-patches.sh --pop" >&2
    exit 1
fi

# If something is already applied, pop it first to start clean.
if [[ -d .pc ]] && [[ -n "$(quilt applied 2>/dev/null || true)" ]]; then
    quilt pop -a
fi

if [[ "$mode" == "check" ]]; then
    if quilt push -a; then
        quilt pop -a
        echo "OK: all $patch_count patch(es) apply cleanly to $upstream_base"
    else
        echo "FAIL: some patches did not apply cleanly to $upstream_base" >&2
        exit 1
    fi
else
    quilt push -a
    echo "Applied $patch_count patch(es) on top of $upstream_base"
fi
