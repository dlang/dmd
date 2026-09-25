struct State
{
    size_t count;
    real[64] unused;

    pragma(inline, true)
    real value()
    {
        return count ? count : 0;
    }
}

void repro1()
{
    State state;
    assert(state.value == 0);
}

void repro2()
{
    size_t count = 0;
    assert((count ? cast(real)count : 0.0L) == 0.0L);
}

void repro3()
{
    bool a;
    bool b = (a ? 0.0L : 0.0L) != 0.0L;
    assert(!b);
}

void main()
{
    repro1();
    repro2();
    repro3();
}
