/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
---
fail_compilation/fail9562.d(26): Error: `int[]` is not an expression
    auto len  = A.length;
                ^
fail_compilation/fail9562.d(27): Error: no property `reverse` for type `int[]`
    auto rev  = A.reverse;
                ^
fail_compilation/fail9562.d(28): Error: no property `sort` for type `int[]`, perhaps `import std.algorithm;` is needed?
    auto sort = A.sort;
                ^
fail_compilation/fail9562.d(29): Error: no property `dup` for type `int[]`
    auto dup  = A.dup;
                ^
fail_compilation/fail9562.d(30): Error: no property `idup` for type `int[]`
    auto idup = A.idup;
                ^
---
*/

void main()
{
    alias A = int[];
    auto len  = A.length;
    auto rev  = A.reverse;
    auto sort = A.sort;
    auto dup  = A.dup;
    auto idup = A.idup;
}
