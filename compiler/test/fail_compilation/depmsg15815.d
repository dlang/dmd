// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/depmsg15815.d(24): Deprecation: template `depmsg15815.Alias(T)` is deprecated - message
fail_compilation/depmsg15815.d(18):        `Alias(T)` is declared here
Foo
---
*/

template Unqual(T)
{
    static if (is(T U == const U)) alias Unqual = U;
    else alias Unqual = T;
}

deprecated("message")
template Alias(T)
{
    alias Alias = Unqual!T;
}

struct Foo {}
pragma(msg, Alias!(const(Foo)));
