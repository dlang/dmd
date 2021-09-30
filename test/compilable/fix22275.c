// https://issues.dlang.org/show_bug.cgi?id=22275

void test(char *dest)
{
    char buf[1];
    if (dest != buf)
        return;
    if (test != &test)
        return;
}
