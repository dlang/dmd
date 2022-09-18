// https://issues.dlang.org/show_bug.cgi?id=22699

int foo(int x, int y)
{
    for (; x = y;)
        return (x = y) ? x : y;
}
