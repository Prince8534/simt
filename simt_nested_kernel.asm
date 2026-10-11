
# Structured nested-divergence kernel
# Outer branch: 0x00 -> 0x20
# Outer reconvergence: 0x40
#
# Inner branch: 0x20 -> 0x30
# Inner reconvergence: 0x34

outer:
    beq  x1, x2, outer_taken
    nop
    nop
    join
    nop
    nop
    nop
    nop

outer_taken:
    beq  x3, x4, inner_taken
    nop
    join
    nop

inner_taken:
    join
    nop
    nop
    join
    nop
