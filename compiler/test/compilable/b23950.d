void fun1()
{
    auto foo = false && true || assert(0);
}

void fun2()
{
    int foo;
    foo += false && true || assert(0);
}

immutable(noreturn) assertFalse()
{
    return assert(0);
}

void fun3()
{
    auto foo = assertFalse() ? 1 : 2;
}

// https://github.com/dlang/dmd/issues/18186
void fun4()
{
    noreturn[1] x = noreturn[1].init;
    noreturn[1] x2 = noreturn.init;
}
