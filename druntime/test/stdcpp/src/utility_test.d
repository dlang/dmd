import core.stdcpp.utility;

alias SimplePair = pair!(int, float);
alias ElaboratePair = pair!(int, Elaborate);

unittest
{
    SimplePair o1;
    assert(o1.first == 0 && o1.second is float.nan);

    auto o2 = SimplePair(10, 20.0);
    assert(o2.first == 10 && o2.second == 20.0);

    {
        ElaboratePair o3;
        assert(o3.first == 0 && o3.second.valid == false);
        auto o4 = ElaboratePair(20, Elaborate(20));
        assert(o4.first == 20 && o4.second.valid == true && o4.second.buffer[0] == 20 && o4.second.buffer[$ - 1] == 20);
        assert(opt_pairRefCount == 1);

        assert(callC_val(o2, o2, o4, o4) == 70);
    }
    assert(opt_pairRefCount == 0);
}

extern(C++):

__gshared int opt_pairRefCount = 0;

struct Elaborate
{
    bool valid = false;
    int[16] buffer;
    this(int val)
    {
        valid = true;
        buffer[] = val;
        ++opt_pairRefCount;
    }
    this(scope ref inout(Elaborate) rhs) inout
    {
        valid = rhs.valid;
        if (rhs.valid)
        {
            buffer[] = rhs.buffer[];
            ++opt_pairRefCount;
        }
    }
    ~this()
    {
        if (valid)
            --opt_pairRefCount;
    }
}

int callC_val(SimplePair, ref SimplePair, ElaboratePair, ref ElaboratePair);

int fromC_val(SimplePair a1, ref SimplePair a2, ElaboratePair a3, ref ElaboratePair a4)
{
    return cast(int)(a1.first + a2.second + a3.first + a4.second.buffer[0]);
}
