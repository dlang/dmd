// https://issues.dlang.org/show_bug.cgi?id=22415

int test(int a)
{
    switch (a)
    {
        case 0:
            a = 1;
        case 1:
            return a;
        case 2:
        default:
            return -1;
    }
}
