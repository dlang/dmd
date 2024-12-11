// https://issues.dlang.org/show_bug.cgi?id=23822

// REQUIRED_ARGS: -de

/*
TEST_OUTPUT:
---
fail_compilation/fail23822.d(23): Deprecation: alias `fail23822.S.value` is deprecated
    auto a = S.value;
             ^
---
*/

alias Alias(alias A) = A;

struct S
{
    deprecated alias value = Alias!5;
}

void main()
{
    auto a = S.value;
}
