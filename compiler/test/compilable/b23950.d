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
