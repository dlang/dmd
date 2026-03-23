// https://issues.dlang.org/show_bug.cgi?id=23968

// REQUIRED_ARGS: -de

/*
TEST_OUTPUT:
---
fail_compilation/test23968.d(23): Deprecation: alias `test23968.a` is deprecated
fail_compilation/test23968.d(18):        `a` is declared here
---
*/

int fun()(int)
{
    return 0;
}

deprecated alias a = fun;

void main()
{
    int v;
    int y = v.a!();  // No deprecation?
}
