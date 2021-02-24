
/*****************************************/

alias noreturn = typeof(*null);

bool testf(int i)
{
    return i && assert(0);
}

bool testt(int i)
{
    return i || assert(0);
}

void main()
{
    assert(testf(0) == false);
    assert(testt(1) == true);
}

