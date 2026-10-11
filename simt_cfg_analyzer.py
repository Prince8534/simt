#!/usr/bin/env python3
"""Build a basic-block CFG and post-dominator report for SIMT assembly.

This is the first compiler-analysis pass. It deliberately reports conventional
CFG post-dominators separately from SIMT JOIN semantics; do not use its IPDOM
output as hardware metadata until JOIN regions have been structurally validated.
"""
import argparse
import json
import re
import sys
from pathlib import Path

CONDITIONAL_BRANCHES = {"beq", "bne", "blt", "bge", "bltu", "bgeu"}
UNCONDITIONAL_JUMPS = {"jal"}
TERMINATORS = CONDITIONAL_BRANCHES | UNCONDITIONAL_JUMPS | {"jalr", "join", "ebreak", "ecall"}
LABEL_RE = re.compile(r"[A-Za-z_.$][A-Za-z0-9_.$]*")
REG_RE = re.compile(r"^(?:x(?:[0-9]|[12][0-9]|3[01])|zero|ra|sp|gp|tp|t[0-6]|s(?:[0-9]|1[01])|a[0-7]|fp)$", re.I)


def parse_source(path):
    instructions = []
    labels = {}
    pc = 0
    for line_no, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].split("//", 1)[0].strip()
        while line and ":" in line:
            candidate, rest = line.split(":", 1)
            candidate = candidate.strip()
            if not LABEL_RE.fullmatch(candidate):
                break
            if candidate in labels:
                raise ValueError(f"line {line_no}: duplicate label {candidate!r}")
            labels[candidate] = pc
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


def branch_target(ins, labels):
    if ins["mnemonic"] in CONDITIONAL_BRANCHES:
        if len(ins["operands"]) != 3:
            raise ValueError(f'line {ins["line"]}: {ins["mnemonic"]} expects 3 operands')
        token = ins["operands"][2]
    elif ins["mnemonic"] == "jal":
        if len(ins["operands"]) == 1:
            token = ins["operands"][0]
        elif len(ins["operands"]) == 2:
            token = ins["operands"][1]
        else:
            raise ValueError(f'line {ins["line"]}: jal expects target or rd,target')
    else:
        return None
    if token in labels:
        return labels[token]
    try:
        value = int(token, 0)
    except ValueError:
        raise ValueError(f'line {ins["line"]}: unknown branch target {token!r}')
    # Assembly branch/jal immediates are offsets relative to the current PC.
    return ins["pc"] + value


def build_cfg(instructions, labels, source_path):
    if not instructions:
        raise ValueError("source contains no instructions")
    by_pc = {i["pc"]: i for i in instructions}
    pcs = [i["pc"] for i in instructions]
    next_pc = {pc: (pcs[idx + 1] if idx + 1 < len(pcs) else None)
               for idx, pc in enumerate(pcs)}
    leaders = {pcs[0]}
    targets = {}
    for ins in instructions:
        pc, m = ins["pc"], ins["mnemonic"]
        target = branch_target(ins, labels) if m in CONDITIONAL_BRANCHES | UNCONDITIONAL_JUMPS else None
        if target is not None:
            targets[pc] = target
            if target in by_pc:
                leaders.add(target)
        if m in TERMINATORS and next_pc[pc] is not None:
            leaders.add(next_pc[pc])
    leaders = sorted(leaders)
    leader_set = set(leaders)
    blocks = []
    current = None
    for ins in instructions:
        if ins["pc"] in leader_set:
            if current:
                blocks.append(current)
            current = {"start": ins["pc"], "instructions": []}
        current["instructions"].append(ins)
    if current:
        blocks.append(current)
    block_by_pc = {b["start"]: b for b in blocks}
    instruction_to_block = {}
    for b in blocks:
        for ins in b["instructions"]:
            instruction_to_block[ins["pc"]] = b["start"]

    edges = {b["start"]: set() for b in blocks}
    for idx, block in enumerate(blocks):
        last = block["instructions"][-1]
        pc, m = last["pc"], last["mnemonic"]
        fallthrough = next_pc[pc]
        if m in CONDITIONAL_BRANCHES:
            target = targets[pc]
            if target in instruction_to_block:
                edges[block["start"]].add(instruction_to_block[target])
            if fallthrough is not None:
                edges[block["start"]].add(instruction_to_block[fallthrough])
        elif m == "jal":
            target = targets[pc]
            if target in instruction_to_block:
                edges[block["start"]].add(instruction_to_block[target])
            # jal with rd=x0 is a jump; other forms may return via a register.
            ops = last["operands"]
            rd = ops[0].lower() if len(ops) == 2 else "ra"
            if rd not in {"x0", "zero"}:
                if fallthrough is not None:
                    edges[block["start"]].add(instruction_to_block[fallthrough])
        elif m in {"jalr", "ebreak", "ecall"}:
            pass
        else:
            if fallthrough is not None:
                edges[block["start"]].add(instruction_to_block[fallthrough])

    # Add a virtual exit so terminal blocks have a well-defined post-dominator.
    exit_node = -1
    all_nodes = set(edges) | {exit_node}
    for node, succs in edges.items():
        if not succs:
            succs.add(exit_node)
    postdom = {n: ({n} if n == exit_node else set(all_nodes)) for n in all_nodes}
    changed = True
    while changed:
        changed = False
        for node in edges:
            succs = edges[node]
            common = set.intersection(*(postdom[s] for s in succs)) if succs else {exit_node}
            updated = {node} | common
            if updated != postdom[node]:
                postdom[node] = updated
                changed = True

    ipdom = {}
    for node in edges:
        strict = postdom[node] - {node}
        immediate = None
        # Immediate post-dominator is the strict post-dominator not post-dominated
        # by another strict post-dominator candidate.
        for candidate in strict:
            if all(candidate == other or candidate not in postdom[other]
                   for other in strict):
                immediate = candidate
                break
        ipdom[str(node)] = None if immediate in (None, exit_node) else immediate

    for b in blocks:
        start = b["start"]
        b["end"] = b["instructions"][-1]["pc"]
        b["successors"] = sorted(edges[start] - {exit_node})
        b["post_dominators"] = sorted(x for x in postdom[start] if x != exit_node)
        b["immediate_post_dominator"] = ipdom[str(start)]
        b["instructions"] = [
            {"pc": i["pc"], "line": i["line"], "mnemonic": i["mnemonic"],
             "operands": i["operands"], "source": i["source"]}
            for i in b["instructions"]
        ]

    has_join = any(i["mnemonic"] == "join" for i in instructions)
    branch_ipdom = {}
    for ins in instructions:
        if ins["mnemonic"] in CONDITIONAL_BRANCHES:
            block = instruction_to_block[ins["pc"]]
            branch_ipdom[f"0x{ins['pc']:08x}"] = (
                None if ipdom[str(block)] is None else f"0x{ipdom[str(block)]:08x}"
            )

    return {
        "format": "simt-cfg-v1",
        "source": str(source_path),
        "instruction_count": len(instructions),
        "labels": {k: f"0x{v:08x}" for k, v in labels.items()},
        "blocks": blocks,
        "branch_ipdom_candidates": branch_ipdom,
        "notes": [
            "CFG edges currently model conventional branch/jump flow.",
            "JOIN is treated as a basic-block terminator with sequential fallthrough.",
            "If the source contains JOIN, branch_ipdom_candidates are diagnostic only; "
            "they are not safe hardware reconvergence metadata until structured SIMT "
            "JOIN regions are analyzed."
        ] if has_join else [
            "CFG and post-dominator data model conventional branch/jump flow.",
            "Validate indirect jumps and function returns before using IPDOM data in hardware."
        ],
        "hardware_metadata_safe": not has_join
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="input .asm file")
    parser.add_argument("-o", "--output", type=Path, help="JSON output (default: source .cfg.json)")
    args = parser.parse_args()
    out = args.output or args.source.with_suffix(".cfg.json")
    try:
        instructions, labels = parse_source(args.source)
        result = build_cfg(instructions, labels, args.source)
        out.write_text(json.dumps(result, indent=2) + "\n")
        print(f"Analyzed {len(instructions)} instructions -> {out}")
        print(f"Basic blocks: {len(result['blocks'])}")
        print("Branch IPDOM candidates:")
        for pc, target in result["branch_ipdom_candidates"].items():
            print(f"  {pc} -> {target or 'EXIT / none'}")
        if not result["hardware_metadata_safe"]:
            print("NOTE: JOIN-aware SIMT metadata is not yet safe for hardware use.")
    except (OSError, ValueError) as exc:
        print(f"cfg analyzer error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
