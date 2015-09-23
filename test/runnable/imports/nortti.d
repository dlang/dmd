/**
 * This module contains code which is supposed to work without
 * runtime type information (RTTI). The code must work for these 3
 * cases:
 *
 * * standard druntime with RTTI
 * * standard druntime with -betterC (implies noRTTI)
 * * druntime without TypeInfo classes and -betterC
 */
module nortti;

struct S
{
    int field1;
    string field2;

    void foo() {}
    ~this() {}
    this(this) {}
}

interface I
{
    void foo();
}

class C : I
{
    int field1;
    string field2;

    void foo() {}
    this() {}
    ~this() {}
}

class C2 : C
{
    override void foo() {}
    void foo2() {}
}

void foo(A...)(A args)
{
    uint[A.length] bar;
}

void baz()
{
    foo(1, null, "quux");
}

int testNORTTI()
{
    S str;
    C2 c;
    return 0;
}
