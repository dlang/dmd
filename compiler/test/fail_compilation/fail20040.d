/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
---
fail_compilation/fail20040.d(19): Error: no property `joiner` for type `string[]`, perhaps `import std.algorithm;` is needed?
    x.joiner();
     ^
fail_compilation/fail20040.d(20): Error: no property `split` for type `string[]`, perhaps `import std.array;` is needed?
    x.split();
     ^
fail_compilation/fail20040.d(21): Error: no property `startsWith` for type `string[]`, perhaps `import std.algorithm;` is needed?
    x.startsWith;
     ^
---
*/
void main()
{
    auto x = ["a","b","c"];
    x.joiner();
    x.split();
    x.startsWith;
}
