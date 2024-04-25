/*
TEST_OUTPUT:
---
fail_compilation/fail24389.c(10): Error: Gnu Asm not supported - compile this file with gcc or clang
---
*/
typedef unsigned long size_t;
void __qsort_r_compat(void *, size_t, size_t, void *,
     int (*)(void *, const void *, const void *));
__asm__(".symver " "__qsort_r_compat" ", " "qsort_r" "@" "FBSD_1.0");
