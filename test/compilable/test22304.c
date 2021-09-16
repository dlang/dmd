// https://issues.dlang.org/show_bug.cgi?id=22304

int * __attribute__((__always_inline__)) foo(void)
{
    return 0;
}
