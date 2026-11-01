# Eight-lane divergent SIMT workload.
# Taken lanes: 0, 1, 4, 5.
# Deferred lanes: 2, 3, 6, 7.
#
# Branch at 0x04 -> taken path 0x10.
# JOIN instructions at 0x0C and 0x14.
# Reconvergence at 0x18.

start:
    addi x3, x1, 5
    beq  x1, x2, taken
    addi x4, x1, 7
    join

taken:
    addi x5, x1, 9
    join
    nop
