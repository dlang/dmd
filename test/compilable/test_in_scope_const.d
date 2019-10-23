// REQUIRED_ARGS: -preview=dip1000

@safe:

void test(in char* ptr)
{
}

void calltest()
{
    char[10] buf;
    test(&buf[0]);
}
