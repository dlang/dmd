/*
TEST_OUTPUT:
---
---
*/
void main()
{
    assert(func(1,0) == 1);
    assert(func(1) == 1); //compile error
    assert(func2() == 0);
}

template AliasSeq(TList...)
{
    alias AliasSeq = TList;
}

T func(T)(T value, AliasSeq!(int) params = AliasSeq!(0))
{
    return value;
}

int func2(AliasSeq!(int) params = AliasSeq!(0))
{
    return 0;
}
