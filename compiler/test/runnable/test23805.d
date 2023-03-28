// https://issues.dlang.org/show_bug.cgi?id=23805

void main ()
{
    size_t destructionCount;
    struct CantDestruct
    {
        int value;
        ~this () { ++destructionCount; }
    }
    static void test(CantDestruct a) {}

    test(CantDestruct.init);
    CantDestruct b;
    CantDestruct a = b.init;
}
