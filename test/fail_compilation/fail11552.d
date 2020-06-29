/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
---
fail_compilation/fail11552.d(9): Error: function `D main` label `label` is undefined
---
*/

void main()
{
    goto label;
}
