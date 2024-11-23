// https://issues.dlang.org/show_bug.cgi?id=24065

/*
TEST_OUTPUT:
---
fail_compilation/test24065.d(18): Error: string expected as argument of __traits `getTargetInfo` instead of `int`
auto s1 = __traits(getTargetInfo, int);
          ^
fail_compilation/test24065.d(21): Error: string expected as argument of __traits `getTargetInfo` instead of `foo`
auto s2 = __traits(getTargetInfo, foo);
          ^
fail_compilation/test24065.d(24): Error: string expected as argument of __traits `getTargetInfo` instead of `e`
auto s3 = __traits(getTargetInfo, e);
          ^
---
*/

auto s1 = __traits(getTargetInfo, int);

void foo() {}
auto s2 = __traits(getTargetInfo, foo);

enum e;
auto s3 = __traits(getTargetInfo, e);
