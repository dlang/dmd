/*
TEST_OUTPUT:
---
fail_compilation/ice19887.d(11): Error: initializer must be an expression, not `(void)`
void func(AliasSeq!(int) params = AliasSeq!(void)) {}
                                  ^
---
*/
module ice19887;

void func(AliasSeq!(int) params = AliasSeq!(void)) {}

template AliasSeq(TList...)
{
    alias AliasSeq = TList;
}
