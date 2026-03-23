// https://issues.dlang.org/show_bug.cgi?id=23826

// REQUIRED_ARGS: -de

/*
TEST_OUTPUT:
---
fail_compilation/fail23826.d(24): Deprecation: alias `fail23826.S.value` is deprecated
fail_compilation/fail23826.d(17):        `value` is declared here
---
*/

alias Alias(alias A) = A;

class S
{
    deprecated alias value = Alias!5;
}

enum identity(alias A) = A;

void main()
{
    auto a = identity!(S.value);
}
