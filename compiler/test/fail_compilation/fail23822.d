// https://issues.dlang.org/show_bug.cgi?id=23822

// REQUIRED_ARGS: -de

/*
TEST_OUTPUT:
---
fail_compilation/fail23822.d(22): Deprecation: alias `fail23822.S.value` is deprecated
fail_compilation/fail23822.d(17):        `value` is declared here
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
