// https://issues.dlang.org/show_bug.cgi?id=22031

immutable int example;

shared static this()
{
    example = 1;
}

pragma(crt_constructor)
extern (C)
void initialize()
{
    example = 1;
}
