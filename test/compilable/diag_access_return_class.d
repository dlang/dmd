// REQUIRED_ARGS: -wi -unittest -diagnose=access -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_return_class.d(18): Warning: returned expression is always `null`
---
*/

@safe pure:

class C
{
}

C f0()
{
    return C.init;              // warn, null return
}

C f5()
{
    return new C();
}

C f1()
{
    C c = new C();
    return c;
}

const(C) f2()
{
    const(C) c = new C();
    return c;
}

const(C) f3()
{
    C c = new C();              // warn, make const
    return c;
}

immutable(C) f4()
{
    immutable(C) c = new C();
    return c;
}
