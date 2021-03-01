
/*****************************************/

alias noreturn = typeof(*null);

extern (C) noreturn exit();

bool testf(int i)
{
    return i && assert(0);
}

bool testt(int i)
{
    return i || assert(0);
}

int test3(int i)
{
    if (i && exit())
        return i + 1;
    return i - 1;
}

int test4(int i)
{
    if (i || exit())
        return i + 1;
    return i - 1;
}

int main()
{
    assert(testf(0) == false);
    assert(testt(1) == true);

    assert(test3(0) == -1);
    assert(test4(3) == 4);

    return 0;
}

