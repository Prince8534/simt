#!/usr/bin/env python3
"""Assembler for the currently implemented SIMT decoder instruction encodings."""
import argparse
import re
import sys
from pathlib import Path

REGS = {f'x{i}': i for i in range(32)}
REGS.update({'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
             't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8, 's1': 9,
             'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15,
             'a6': 16, 'a7': 17, 's2': 18, 's3': 19, 's4': 20, 's5': 21,
             's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
             't3': 28, 't4': 29, 't5': 30, 't6': 31})
OP = {'R': 0x33, 'I': 0x13, 'LOAD': 0x03, 'STORE': 0x23,
      'BRANCH': 0x63, 'JAL': 0x6f, 'JALR': 0x67,
      'LUI': 0x37, 'AUIPC': 0x17, 'FENCE': 0x0f, 'SYSTEM': 0x73,
      'SIMT': 0x0b}
R_FUNCTS = {
    'add': (0, 0), 'sub': (0, 0x20), 'sll': (1, 0), 'slt': (2, 0),
    'sltu': (3, 0), 'xor': (4, 0), 'srl': (5, 0), 'sra': (5, 0x20),
    'or': (6, 0), 'and': (7, 0)}
I_FUNCTS = {'addi': 0, 'slti': 2, 'sltiu': 3, 'xori': 4, 'ori': 6, 'andi': 7}
BR_FUNCTS = {'beq': 0, 'bne': 1, 'blt': 4, 'bge': 5, 'bltu': 6, 'bgeu': 7}
LOAD_FUNCTS = {'lb': 0, 'lh': 1, 'lw': 2, 'lbu': 4, 'lhu': 5}
STORE_FUNCTS = {'sb': 0, 'sh': 1, 'sw': 2}


def fail(msg, line_no=None):
    where = f'line {line_no}: ' if line_no is not None else ''
    raise ValueError(where + msg)


def reg(token, line_no):
    token = token.strip().lower()
    if token not in REGS:
        fail(f'unknown register {token!r}', line_no)
    return REGS[token]


def imm(token, labels, pc, line_no):
    token = token.strip()
    if token in labels:
        return labels[token] - pc
    try:
        return int(token, 0)
    except ValueError:
        fail(f'invalid immediate/label {token!r}', line_no)


def signed_range(value, bits, what, line_no):
    if not -(1 << (bits - 1)) <= value < (1 << (bits - 1)):
        fail(f'{what} {value} does not fit signed {bits}-bit range', line_no)


def unsigned_or_signed(value, bits, what, line_no):
    if not -(1 << (bits - 1)) <= value < (1 << bits):
        fail(f'{what} {value} does not fit {bits} bits', line_no)


def split_operands(text):
    return [part.strip() for part in text.split(',') if part.strip()]


def parse_source(path):
    statements = []
    labels = {}
    pc = 0
    for line_no, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split('#', 1)[0].split('//', 1)[0].strip()
        if not line:
            continue
        while ':' in line:
            label, rest = line.split(':', 1)
            label = label.strip()
            if not re.fullmatch(r'[A-Za-z_.$][A-Za-z0-9_.$]*', label):
                fail(f'invalid label {label!r}', line_no)
            if label in labels:
                fail(f'duplicate label {label!r}', line_no)
            labels[label] = pc
            line = rest.strip()
            if not line:
                break
        if not line:
            continue
        parts = line.split(None, 1)
        mnemonic = parts[0].lower()
        operands = split_operands(parts[1]) if len(parts) > 1 else []
        statements.append((pc, line_no, mnemonic, operands, raw.strip()))
        pc += 4
    return statements, labels


def encode(stmt, labels):
    pc, line_no, m, a, _ = stmt
    def count(n):
        if len(a) != n:
            fail(f'{m} expects {n} operand(s), got {len(a)}', line_no)
    def r(i): return reg(a[i], line_no)
    def v(i): return imm(a[i], labels, pc, line_no)

    if m in R_FUNCTS:
        count(3); f3, f7 = R_FUNCTS[m]
        return (f7 << 25) | (r(2) << 20) | (r(1) << 15) | (f3 << 12) | (r(0) << 7) | OP['R']

    if m in I_FUNCTS:
        count(3); value = v(2); signed_range(value, 12, 'immediate', line_no)
        return ((value & 0xfff) << 20) | (r(1) << 15) | (I_FUNCTS[m] << 12) | (r(0) << 7) | OP['I']

    if m in ('slli', 'srli', 'srai'):
        count(3); shamt = v(2)
        if not 0 <= shamt <= 31: fail('shift amount must be 0..31', line_no)
        f3 = 1 if m == 'slli' else 5
        f7 = 0x20 if m == 'srai' else 0
        return (f7 << 25) | (shamt << 20) | (r(1) << 15) | (f3 << 12) | (r(0) << 7) | OP['I']

    if m in LOAD_FUNCTS:
        count(2)
        match = re.fullmatch(r'\s*([+-]?(?:0[xX][0-9a-fA-F]+|\d+))\s*\(\s*([^()]+)\s*\)\s*', a[1])
        if not match: fail('memory operand must look like offset(xN)', line_no)
        value = int(match.group(1), 0); base = reg(match.group(2), line_no)
        signed_range(value, 12, 'load offset', line_no)
        return ((value & 0xfff) << 20) | (base << 15) | (LOAD_FUNCTS[m] << 12) | (r(0) << 7) | OP['LOAD']

    if m in STORE_FUNCTS:
        count(2)
        match = re.fullmatch(r'\s*([+-]?(?:0[xX][0-9a-fA-F]+|\d+))\s*\(\s*([^()]+)\s*\)\s*', a[1])
        if not match: fail('memory operand must look like offset(xN)', line_no)
        value = int(match.group(1), 0); base = reg(match.group(2), line_no)
        signed_range(value, 12, 'store offset', line_no)
        value &= 0xfff
        return (((value >> 5) & 0x7f) << 25) | (r(0) << 20) | (base << 15) | (STORE_FUNCTS[m] << 12) | ((value & 0x1f) << 7) | OP['STORE']

    if m in BR_FUNCTS:
        count(3); offset = v(2)
        if offset % 2: fail('branch target offset must be 2-byte aligned', line_no)
        signed_range(offset, 13, 'branch offset', line_no)
        x = offset & 0x1fff
        return (((x >> 12) & 1) << 31) | (((x >> 5) & 0x3f) << 25) | (r(1) << 20) | (r(0) << 15) | (BR_FUNCTS[m] << 12) | (((x >> 1) & 0xf) << 8) | (((x >> 11) & 1) << 7) | OP['BRANCH']

    if m == 'jal':
        if len(a) == 1: rd, target = 1, v(0)
        elif len(a) == 2: rd, target = r(0), v(1)
        else: fail('jal syntax: jal [rd,] target', line_no)
        if target % 2: fail('JAL target offset must be 2-byte aligned', line_no)
        signed_range(target, 21, 'JAL offset', line_no)
        x = target & 0x1fffff
        return (((x >> 20) & 1) << 31) | (((x >> 1) & 0x3ff) << 21) | (((x >> 11) & 1) << 20) | (((x >> 12) & 0xff) << 12) | (rd << 7) | OP['JAL']

    if m == 'jalr':
        if len(a) == 2:
            rd = r(0); match_text = a[1]
        elif len(a) == 1:
            rd = 1; match_text = a[0]
        else: fail('jalr syntax: jalr [rd,] offset(rs1)', line_no)
        match = re.fullmatch(r'\s*([+-]?(?:0[xX][0-9a-fA-F]+|\d+))\s*\(\s*([^()]+)\s*\)\s*', match_text)
        if not match: fail('jalr operand must look like offset(xN)', line_no)
        value = int(match.group(1), 0); base = reg(match.group(2), line_no)
        signed_range(value, 12, 'JALR offset', line_no)
        return ((value & 0xfff) << 20) | (base << 15) | (rd << 7) | OP['JALR']

    if m in ('lui', 'auipc'):
        count(2); value = v(1)
        if not -(1 << 19) <= value < (1 << 20): fail('upper immediate does not fit 20 bits', line_no)
        return ((value & 0xfffff) << 12) | (r(0) << 7) | OP['LUI' if m == 'lui' else 'AUIPC']

    if m == 'fence':
        if len(a) > 2: fail('fence takes at most two operands', line_no)
        return 0x0000000f
    if m == 'ecall':
        count(0); return 0x00000073
    if m == 'ebreak':
        count(0); return 0x00100073

    if m in ('tmc', 'split', 'join'):
        if a: fail(f'{m} takes no operands in the current decoder', line_no)
        f3 = {'tmc': 0, 'split': 1, 'join': 2}[m]
        return (f3 << 12) | OP['SIMT']

    if m == 'nop':
        count(0); return 0x00000013

    fail(f'unsupported mnemonic {m!r}', line_no)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='input assembly source')
    parser.add_argument('-o', '--output', type=Path, help='output hex file (default: source .hex)')
    parser.add_argument('--listing', type=Path, help='optional address/encoding/source listing')
    args = parser.parse_args()
    out = args.output or args.source.with_suffix('.hex')
    try:
        statements, labels = parse_source(args.source)
        encoded = [(stmt, encode(stmt, labels)) for stmt in statements]
        out.write_text(''.join(f'{word:08x}\n' for _, word in encoded))
        if args.listing:
            with args.listing.open('w') as f:
                for (pc, line_no, _, _, source), word in encoded:
                    f.write(f'{pc:08x}: {word:08x}  {source}\n')
        print(f'Assembled {len(encoded)} instructions -> {out}')
        if args.listing:
            print(f'Listing written -> {args.listing}')
        if labels:
            print('Labels:')
            for name, address in labels.items():
                print(f'  {name}: 0x{address:08x}')
    except (OSError, ValueError) as exc:
        print(f'assembler error: {exc}', file=sys.stderr)
        return 1
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
