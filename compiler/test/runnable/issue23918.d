struct State
{
    size_t count;
    real[64] unused;

    real value()
    {
        return count ? count : 0;
    }
}

void case1() {
    State state;
    assert(state.value == 0);
}

void case2()
{
    bool b;
    assert((b ? 0.0L : 0.0L) == 0.0L);
}

void case3()
{
    bool a;
    bool b = (a ? 0.0L : 0.0L) != 0.0L;
    assert(!b);
}

void case4()
{
    bool b;
    float f = 0.0f;
    assert((b ? 0.0f : 0.0f) == 0.0f);
}

void main()
{
    case1();
    case2();
    case3();
    case4();
}
