// https://issues.dlang.org/show_bug.cgi?id=18672

void main() @safe
{
    struct ThrowingElement
    {
        ~this() {}
    }

    ThrowingElement aa;
    aa = aa;
}
