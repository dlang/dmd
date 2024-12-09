/* REQUIRED_ARGS: -wi
TEST_OUTPUT:
---
fail_compilation/cerrors.d(23): Error: C preprocessor directive `#if` is not supported, use `version` or `static if`
#if 1
   ^
fail_compilation/cerrors.d(23): Error: declaration expected, not `#`
#if 1
^
fail_compilation/cerrors.d(27): Error: C preprocessor directive `#endif` is not supported
fail_compilation/cerrors.d(27): Error: declaration expected, not `#`
#endif
^
fail_compilation/cerrors.d(31): Error: token string requires valid D tokens, not `#if`
#if 1
   ^
fail_compilation/cerrors.d(32): Deprecation: token string requires valid D tokens, not `#include`
#include <test>
        ^
---
*/

#if 1

void test(wchar_t u);

#endif

// https://issues.dlang.org/show_bug.cgi?id=23792
enum s1 = q{
#if 1
#include <test>
};
