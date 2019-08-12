/*
REQUIRED_ARGS: -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/fail11552.d(10): Error: function `D main` label `label` is undefined
---
*/

void main()
{
    goto label;
}
