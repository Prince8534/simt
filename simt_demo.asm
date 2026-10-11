# Basic SIMT assembler smoke test.
# Branch offsets are resolved from labels relative to each instruction PC.

start:
    addi x3, x1, 5
    beq  x1, x2, taken
    addi x4, x1, 7
    join

taken:
    addi x5, x1, 9
    join
    nop
