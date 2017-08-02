private struct StaticStruct
{
    static int value;
    static alias value this;
}

void main()
{
    StaticStruct = 42;
    immutable int a = StaticStruct;
    assert(a == 42);
}
