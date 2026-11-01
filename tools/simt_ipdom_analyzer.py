#!/usr/bin/env python3
"""Infer structured SIMT JOIN regions and reconvergence PCs from assembly.

Supported structured form:
  conditional branch -> forward target
  fallthrough path ends at a JOIN
  taken path ends at a JOIN
  reconvergence PC is the instruction immediately after the later JOIN

Nested conditional regions are skipped recursively. This deliberately rejects
unsupported/unstructured control flow instead of guessing hardware metadata.
"""
import argparse
import json
import re
import sys
from pathlib import Path

BRANCHES = {"beq", "bne", "blt", "bge", "bltu", "bgeu"}
LABEL_RE = re.compile(r"[A-Za-z_.$][A-Za-z0-9_.$]*")


def parse_source(path):
    instructions, labels = [], {}
    pc = 0
    for line_no, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].split("//", 1)[0].strip()
        while line and ":" in line:
            name, rest = line.split(":", 1)
            name = name.strip()
            if not LABEL_RE.fullmatch(name):
                break
            if name in labels:
                raise ValueError(f"line {line_no}: duplicate label {name!r}")
            labels[name] = pc
            line = rest.strip()
            if not line:
                break
        if not line:
            continue
        parts = line.split(None, 1)
        mnemonic = parts[0].lower()
        operands = [x.strip() for x in parts[1].split(",")] if len(parts) > 1 else []
        instructions.append({
            "pc": pc, "line": line_no, "mnemonic": mnemonic,
            "operands": operands, "source": raw.strip()
        })
        pc += 4
    return instructions, labels


def target_pc(ins, labels):
    if ins["mnemonic"] not in BRANCHES:
        return None
    if len(ins["operands"]) != 3:
        raise ValueError(f'line {ins["line"]}: {ins["mnemonic"]} expects 3 operands')
    token = ins["operands"][2]
    if token in labels:
        target = labels[token]
    else:
        try:
            target = ins["pc"] + int(token, 0)
        except ValueError:
            raise ValueError(f'line {ins["line"]}: unknown branch target {token!r}')
    if target <= ins["pc"]:
        raise ValueError(
            f'line {ins["line"]}: backward branch at 0x{ins["pc"]:08x} '
            "is not supported by this structured-region pass"
        )
    return target


def analyze(instructions, labels, source_path):
    by_pc = {i["pc"]: i for i in instructions}
    pcs = sorted(by_pc)
    branches = {pc: target_pc(ins, labels) for pc, ins in by_pc.items()
                if ins["mnemonic"] in BRANCHES}
    join_pcs = {pc for pc, ins in by_pc.items() if ins["mnemonic"] == "join"}
    memo, visiting = {}, set()

    def next_pc(pc):
        idx = pcs.index(pc)
        return pcs[idx + 1] if idx + 1 < len(pcs) else None

    def region(branch_pc):
        if branch_pc in memo:
            return memo[branch_pc]
        if branch_pc in visiting:
            raise ValueError(f"cyclic/nested control-flow dependency at 0x{branch_pc:08x}")
        visiting.add(branch_pc)
        target = branches[branch_pc]

        # Find the first JOIN reached along fallthrough, skipping complete
        # nested regions. A JOIN at or beyond the branch target cannot qualify.
        cursor = next_pc(branch_pc)
        fall_join = None
        while cursor is not None and cursor < target:
            ins = by_pc[cursor]
            if ins["mnemonic"] == "join":
                fall_join = cursor
                break
            if cursor in branches:
                nested = region(cursor)
                if nested["reconvergence_pc"] <= cursor or nested["reconvergence_pc"] > target:
                    raise ValueError(
                        f"line {ins['line']}: nested region at 0x{cursor:08x} "
                        "crosses its parent branch target"
                    )
                cursor = nested["reconvergence_pc"]
                continue
            cursor = next_pc(cursor)
        if fall_join is None:
            raise ValueError(
                f"branch 0x{branch_pc:08x}: no fallthrough JOIN before target "
                f"0x{target:08x}"
            )

        # Walk the taken path. When another conditional is encountered,
        # skip that complete nested region, including its two JOINs.
        cursor = target
        taken_join = None
        while cursor is not None:
            if cursor not in by_pc:
                raise ValueError(
                    f"branch 0x{branch_pc:08x}: target-side path leaves known "
                    "instructions before reaching its JOIN"
                )
            ins = by_pc[cursor]
            if ins["mnemonic"] == "join":
                taken_join = cursor
                break
            if cursor in branches and cursor != branch_pc:
                nested = region(cursor)
                if nested["reconvergence_pc"] <= cursor:
                    raise ValueError(f"invalid nested region at 0x{cursor:08x}")
                cursor = nested["reconvergence_pc"]
                continue
            cursor = next_pc(cursor)
        if taken_join is None:
            raise ValueError(
                f"branch 0x{branch_pc:08x}: no taken-path JOIN found"
            )

        # Both paths must be distinct and the reconvergence address must be
        # the instruction after the later-addressed JOIN.
        if fall_join == taken_join:
            raise ValueError(f"branch 0x{branch_pc:08x}: both paths resolve to one JOIN")
        later_join = max(fall_join, taken_join)
        reconv = next_pc(later_join)
        if reconv is None:
            reconv = later_join + 4
        result = {
            "branch_pc": branch_pc,
            "branch_target_pc": target,
            "fallthrough_join_pc": fall_join,
            "taken_join_pc": taken_join,
            "reconvergence_pc": reconv,
        }
        visiting.remove(branch_pc)
        memo[branch_pc] = result
        return result

    regions = [region(pc) for pc in sorted(branches)]
    owned = {}
    for r in regions:
        for key in ("fallthrough_join_pc", "taken_join_pc"):
            join_pc = r[key]
            if join_pc in owned and owned[join_pc] != r["branch_pc"]:
                raise ValueError(
                    f"JOIN 0x{join_pc:08x} is assigned to multiple branches; "
                    "the source is not a valid structured region under this model"
                )
            owned[join_pc] = r["branch_pc"]

    return {
        "format": "simt-ipdom-v1",
        "source": str(source_path),
        "instruction_count": len(instructions),
        "labels": {k: f"0x{v:08x}" for k, v in labels.items()},
        "regions": [
            {k: (f"0x{v:08x}" if k.endswith("_pc") else v)
             for k, v in r.items()}
            for r in regions
        ],
        "branch_to_reconvergence": {
            f"0x{r['branch_pc']:08x}": f"0x{r['reconvergence_pc']:08x}"
            for r in regions
        },
        "hardware_metadata_safe": True,
        "assumptions": [
            "Only forward conditional branches are supported.",
            "Each conditional branch owns one fallthrough-path JOIN and one taken-path JOIN.",
            "Nested regions must be properly contained and may not share JOIN instructions.",
            "This output is valid only for assembly following this structured JOIN convention.",
            "Indirect jumps, loops, early exits, and unstructured control flow are rejected or unsupported."
        ]
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="input .asm file")
    parser.add_argument("-o", "--output", type=Path, help="JSON output (default: source .ipdom)")
    args = parser.parse_args()
    out = args.output or args.source.with_suffix(".ipdom")
    try:
        instructions, labels = parse_source(args.source)
        result = analyze(instructions, labels, args.source)
        out.write_text(json.dumps(result, indent=2) + "\n")
        print(f"Analyzed {len(instructions)} instructions -> {out}")
        print("JOIN-aware reconvergence:")
        for pc, reconv in result["branch_to_reconvergence"].items():
            region = next(r for r in result["regions"] if r["branch_pc"] == pc)
            print(f"  branch {pc} -> reconvergence {reconv} "
                  f"(fall JOIN {region['fallthrough_join_pc']}, "
                  f"taken JOIN {region['taken_join_pc']})")
        print("Structured JOIN metadata generated; validate against the kernel's intended control flow.")
    except (OSError, ValueError) as exc:
        print(f"ipdom analyzer error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
