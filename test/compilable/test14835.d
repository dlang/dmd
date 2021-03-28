// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=14835


void reachIf(bool x)()
{
    if (!x)
        return;
    return;
}

void test()
{
    reachIf!true();
    reachIf!false();
}
