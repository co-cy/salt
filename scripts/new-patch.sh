#!/usr/bin/env bash
# Create a new patch with a pre-filled header.
#
# Usage: scripts/new-patch.sh <slug> [<file-to-edit>...]
#
# Example:
#   scripts/new-patch.sh fix-pillar-cache-race salt/pillar/__init__.py
#
# Steps performed:
#   1. push the existing series so quilt is at the top of the stack
#   2. quilt new NNNN-<slug>.patch    (next free number, picked from patches/)
#   3. quilt add <files>              (so the first refresh captures them)
#   4. write our header template into the patch
#
# After this, edit the file(s), then `quilt refresh` to capture the diff,
# and edit the Description / Internal-Ticket fields in the patch header.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <slug> [<file-to-edit>...]" >&2
    exit 2
fi

slug="$1"
shift
files_to_add=("$@")

if ! command -v quilt >/dev/null 2>&1; then
    echo "quilt not found (install: brew install quilt)" >&2
    exit 127
fi

if [[ ! -f patches/series ]]; then
    echo "patches/series not found — bootstrap quilt infra first" >&2
    exit 1
fi

# Make sure existing patches are applied so quilt new lands on top of them.
if [[ "$(grep -cEv '^\s*(#|$)' patches/series || true)" -gt 0 ]]; then
    if [[ ! -d .pc ]] || [[ -z "$(quilt applied 2>/dev/null || true)" ]]; then
        quilt push -a
    fi
fi

# Pick next 4-digit prefix.
last_num=$(ls patches/ 2>/dev/null \
    | grep -oE '^[0-9]{4}' \
    | sort -n \
    | tail -1 \
    || true)
last_num=${last_num:-0000}
next_num=$(printf "%04d" $((10#${last_num} + 1)))
patch_name="${next_num}-${slug}.patch"

quilt new "$patch_name"

if [[ ${#files_to_add[@]} -gt 0 ]]; then
    quilt add "${files_to_add[@]}"
fi

# Header template.
upstream_base=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "<unknown>")
if date -v +6m '+%Y-%m-%d' >/dev/null 2>&1; then
    review_due=$(date -v +6m '+%Y-%m-%d')   # macOS / BSD date
else
    review_due=$(date -d '+6 months' '+%Y-%m-%d')   # GNU date
fi
today=$(date '+%Y-%m-%d')
author=$(git config user.email 2>/dev/null || echo "<unknown>")

quilt header --replace -- <<EOF
Patch: ${patch_name}
Status: NEW
Upstream-PR: not yet submitted
Upstream-Issue: -
Author: ${author}
Internal-Ticket: -
Submitted: -
Created: ${today}
Last-rebased-on: ${upstream_base}
Review-due: ${review_due}

Description:
  <одним абзацем: какую проблему решает, как воспроизводится>
EOF

cat <<EOF

Created patches/${patch_name}
Series updated, header written.

Next steps:
  \$EDITOR patches/${patch_name}    # заполни Description / Internal-Ticket
  quilt edit <file>                # отредактируй файлы Salt
  quilt refresh                    # сохрани diff в patch
  pytest tests/patches/test_${next_num}_${slug//-/_}.py   # добавь тест
EOF
