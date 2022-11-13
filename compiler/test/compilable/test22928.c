// https://issues.dlang.org/show_bug.cgi?id=22928

void fn()
{
    char cs[1];
    if (cs)
        ;
}
