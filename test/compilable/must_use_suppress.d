import core.attribute;

@mustUse struct S {}

S fun() { return S(); }

void test()
{
    cast(void) fun();
}
