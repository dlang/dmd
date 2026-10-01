/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
---
fail_compilation/fail20040.d(16): Error: no property `joiner` for `x` of type `string[]`
fail_compilation/fail20040.d(16):        perhaps `import std.algorithm;` is needed?
fail_compilation/fail20040.d(17): Error: no property `split` for `x` of type `string[]`
fail_compilation/fail20040.d(17):        perhaps `import std.array;` is needed?
fail_compilation/fail20040.d(18): Error: no property `startsWith` for `x` of type `string[]`
fail_compilation/fail20040.d(18):        perhaps `import std.algorithm;` is needed?
---
*/
void main()
{
    auto x = ["a","b","c"];
    x.joiner();
    x.split();
    x.startsWith;
}
