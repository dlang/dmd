// REQUIRED_ARGS: -w

/*
TEST_OUTPUT:
---
fail_compilation/warn13679.d(13): Warning: cannot use `foreach_reverse` with an associative array
---
*/

void main()
{
    int[int] aa;
    foreach_reverse(k, v; aa) {}
}
