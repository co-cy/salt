#!/usr/bin/env python3
"""Print a summary table of all patches in patches/series.

Reads the header of every patch (lines before the first blank-line-then-diff
or '---' separator), parses the 'Field: value' pairs, and renders a table.

Exit codes:
    0  everything fine
    1  --check-overdue requested and at least one Review-due is in the past
    2  patches/ or patches/series missing
"""
from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
PATCHES_DIR = REPO_ROOT / "patches"
SERIES = PATCHES_DIR / "series"

FIELD_RE = re.compile(r"^([A-Z][A-Za-z-]+):\s*(.*)$")
DIFF_START_RE = re.compile(r"^(diff --git |--- |Index: )")


def list_series() -> list[str]:
    return [
        line.strip()
        for line in SERIES.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


def parse_header(patch_path: Path) -> dict[str, str]:
    fields: dict[str, str] = {}
    for raw in patch_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if DIFF_START_RE.match(raw):
            break
        line = raw.lstrip("#").strip()
        m = FIELD_RE.match(line)
        if m:
            fields[m.group(1)] = m.group(2).strip()
    return fields


def render_table(rows: list[tuple[str, ...]], headers: tuple[str, ...]) -> str:
    widths = [
        max(len(str(r[i])) for r in (rows + [headers]))
        for i in range(len(headers))
    ]
    fmt = "  ".join("{:<" + str(w) + "}" for w in widths)
    out = [fmt.format(*headers), fmt.format(*("-" * w for w in widths))]
    out.extend(fmt.format(*r) for r in rows)
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check-overdue",
        action="store_true",
        help="exit 1 if any patch has Review-due in the past",
    )
    args = parser.parse_args()

    if not PATCHES_DIR.is_dir() or not SERIES.is_file():
        print(f"patches/series not found at {SERIES}", file=sys.stderr)
        return 2

    today = dt.date.today()
    rows: list[tuple[str, ...]] = []
    overdue: list[str] = []

    for name in list_series():
        path = PATCHES_DIR / name
        if not path.is_file():
            rows.append((name, "MISSING", "-", "-", "-"))
            continue
        h = parse_header(path)
        review = h.get("Review-due", "-")
        rows.append((
            name,
            h.get("Status", "?"),
            h.get("Last-rebased-on", "-"),
            review,
            h.get("Internal-Ticket", "-"),
        ))
        try:
            if dt.date.fromisoformat(review) < today:
                overdue.append(name)
        except ValueError:
            pass

    print(render_table(
        rows,
        headers=("Patch", "Status", "Rebased-on", "Review-due", "Ticket"),
    ))
    print(f"\nTotal: {len(rows)} patch(es)")

    if overdue:
        print(f"\nOVERDUE Review-due ({len(overdue)}): {', '.join(overdue)}",
              file=sys.stderr)
        if args.check_overdue:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
