// https://issues.dlang.org/show_bug.cgi?id=22570

/*
TEST_OUTPUT:
---
fail_compilation/fail22570.d(23): Error: too many initializers for `S` with 1 field
    s = [S(null, null)];
                 ^
fail_compilation/fail22570.d(24): Error: too many initializers for `S` with 1 field
    s ~= S(null, null);
                 ^
---
*/

struct S
{
    Object o1;
}

void main() @safe
{
    S[] s;
    s = [S(null, null)];
    s ~= S(null, null);
}
