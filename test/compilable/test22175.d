// https://issues.dlang.org/show_bug.cgi?id=22175
struct Struct
{
    short a, b, c, d;
    bool e;
}

Struct foo()
{
    return Struct.init;
}

void main()
{
    int i = 0;
    Struct var = i ? Struct.init : foo;

    Struct test() { return var; }
}
