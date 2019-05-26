int g;

void fun(R)(auto ref int a, auto ref R r = g)
{
    ++r;
}

void main()
{
    fun(10, 2);
    fun(10);
    assert(g == 1);
}
