// https://issues.dlang.org/show_bug.cgi?id=17954
/*
TEST_OUTPUT:
---
compilable/test17954.d(32): Deprecation: declaring a member named `init` is deprecated
compilable/test17954.d(14): Deprecation: declaring a member named `init` is deprecated
compilable/test17954.d(19): Deprecation: declaring a member named `init` is deprecated
compilable/test17954.d(26): Deprecation: declaring a member named `init` is deprecated
---
*/

struct S0
{
    int init;
}

struct S1
{
    void init() { }
}

struct S2
{
    enum
    {
        init
    }
}

enum E
{
    init
}

enum
{
    init // OK
}
