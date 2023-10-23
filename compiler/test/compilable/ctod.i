/*
PERMUTE_ARGS:
REQUIRED_ARGS: -Hf=${RESULTS_DIR}/compilable/ctod.di
OUTPUT_FILES: ${RESULTS_DIR}/compilable/ctod.di

TEST_OUTPUT:
---
=== ${RESULTS_DIR}/compilable/ctod.di
// D import file generated from 'compilable/ctod.i'
extern (C) uint equ(double x, double y);
---
 */


unsigned equ(double x, double y)
{
    return *(long long *)&x == *(long long *)&y;
}
