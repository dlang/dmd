/*
REQUIRED_ARGS: -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/fail20040.d(14): Error: no property `joiner` for type `string[]`, perhaps `import std.algorithm;` is needed?
fail_compilation/fail20040.d(15): Error: no property `split` for type `string[]`, perhaps `import std.array;` is needed?
fail_compilation/fail20040.d(16): Error: no property `startsWith` for type `string[]`, perhaps `import std.algorithm;` is needed?
---
*/
void main()
{
    auto x = ["a","b","c"];
    x.joiner();
    x.split();
    x.startsWith;
}
