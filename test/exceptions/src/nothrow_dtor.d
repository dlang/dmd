// https://issues.dlang.org/show_bug.cgi?id=20049
class C
{
    this() nothrow {}
    ~this() nothrow {}
}

void main() nothrow
{
    auto c = new C;
    destroy(c);
}
