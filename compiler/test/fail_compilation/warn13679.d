// REQUIRED_ARGS: -w

/*
TEST_OUTPUT:
---
fail_compilation/warn13679.d(15): Error: cannot use `foreach_reverse` with an associative array
    foreach_reverse(k, v; aa) {}
    ^
---
*/

void main()
{
    int[int] aa;
    foreach_reverse(k, v; aa) {}
}
