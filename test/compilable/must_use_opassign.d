import core.attribute;

@mustUse struct S
{
    ref S opAssign(S rhs) return
    {
        return this;
    }
}

void test()
{
    S a, b;
    a = b;
}
