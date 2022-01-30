import core.attribute;

@mustUse struct S
{
    ref S opUnary(string op)() return
    {
        return this;
    }
}

void test()
{
    S s;
    ++s;
    --s;
    s++;
    s--;
}
