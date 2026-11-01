# Eight-lane vector addition demonstration.
# Lane i creates A[i] = i + 1 and B[i] = i + 11,
# then computes C[i] = A[i] + B[i].

laneid x5
addi x6, x5, 1
addi x7, x5, 11
add  x8, x6, x7
ebreak
