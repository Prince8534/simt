#!/usr/bin/env python3
"""Convert SIMT IPDOM JSON into loadable branch and JOIN memory files."""

import argparse
import json
import re
import sys
from pathlib import Path

HEX_PC = re.compile(r"^0x[0-9a-fA-F]{1,8}$")
MAX_ENTRIES = 256
EMPTY_BRANCH = "ffffffffffffffff"
EMPTY_JOIN = "ffffffffffffffffffffffff"


def parse_pc(value, where):
    if not isinstance(value, str) or not HEX_PC.fullmatch(value):
        raise ValueError(f"invalid PC for {where}: {value!r}")
    return int(value, 16)


def convert(data):
    if not isinstance(data, dict) or data.get("format") != "simt-ipdom-v1":
        raise ValueError("unsupported metadata format; expected simt-ipdom-v1")
    if data.get("hardware_metadata_safe") is not True:
        raise ValueError("metadata is not marked hardware_metadata_safe")

    regions = data.get("regions")
    mapping = data.get("branch_to_reconvergence")
    if not isinstance(regions, list) or not isinstance(mapping, dict):
        raise ValueError("missing IPDOM regions or branch mapping")
    if len(regions) > MAX_ENTRIES or len(regions) * 2 > MAX_ENTRIES:
        raise ValueError(f"metadata exceeds hardware limits ({MAX_ENTRIES} branches/JOINs)")

    branches = []
    joins = []
    seen_branches = set()
    seen_joins = set()

    for index, region in enumerate(regions):
        if not isinstance(region, dict):
            raise ValueError(f"region {index} is not an object")

        branch = parse_pc(region.get("branch_pc"), f"region {index} branch_pc")
        reconv = parse_pc(region.get("reconvergence_pc"), f"region {index} reconvergence_pc")
        fall_join = parse_pc(region.get("fallthrough_join_pc"), f"region {index} fallthrough_join_pc")
        taken_join = parse_pc(region.get("taken_join_pc"), f"region {index} taken_join_pc")

        key = f"0x{branch:08x}"
        expected = f"0x{reconv:08x}"
        if mapping.get(key, "").lower() != expected:
            raise ValueError(f"inconsistent branch_to_reconvergence entry for {key}")
        if branch in seen_branches:
            raise ValueError(f"duplicate branch PC 0x{branch:08x}")
        seen_branches.add(branch)
        branches.append((branch, reconv))

        for join in (fall_join, taken_join):
            if join in seen_joins:
                raise ValueError(f"duplicate/overlapping JOIN PC 0x{join:08x}")
            seen_joins.add(join)
            joins.append((join, branch, reconv))

    branches.sort()
    joins.sort()
    branch_lines = [f"{branch:08x}{reconv:08x}" for branch, reconv in branches]
    join_lines = [f"{join:08x}{owner:08x}{reconv:08x}" for join, owner, reconv in joins]

    # Sentinel records make empty tables explicit and avoid zero-length $readmemh files.
    if not branch_lines:
        branch_lines = [EMPTY_BRANCH]
    if not join_lines:
        join_lines = [EMPTY_JOIN]

    return branch_lines, join_lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("metadata", type=Path, help="input .ipdom JSON file")
    parser.add_argument("--branch-output", type=Path, default=Path("simt_branch_metadata.mem"))
    parser.add_argument("--join-output", type=Path, default=Path("simt_join_metadata.mem"))
    args = parser.parse_args()

    try:
        data = json.loads(args.metadata.read_text(encoding="utf-8"))
        branch_lines, join_lines = convert(data)
        args.branch_output.write_text("\n".join(branch_lines) + "\n", encoding="ascii")
        args.join_output.write_text("\n".join(join_lines) + "\n", encoding="ascii")
        print(f"Wrote {len(branch_lines) if branch_lines[0] != EMPTY_BRANCH else 0} branch record(s) -> {args.branch_output}")
        print(f"Wrote {len(join_lines) if join_lines[0] != EMPTY_JOIN else 0} JOIN record(s) -> {args.join_output}")
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"IPDOM memory converter error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
