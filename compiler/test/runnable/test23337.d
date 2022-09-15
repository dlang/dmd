// https://issues.dlang.org/show_bug.cgi?id=23337

int copies, destroyed;

void reset() { copies = destroyed = 0; }

struct S
{
    this(inout ref S) inout { ++copies; }
    ~this() { ++destroyed; }
}

S[3] globals;

S[3] makeStaticArray() { return (S[3]).init; }

S[] makeSlice(ref S[3] sa) { return sa[]; }

void main()
{
    {
        S[3] fromLvalStaticArray = globals;
        assert(copies == 3);
    }
    assert(destroyed == 3);
    reset();

    {
        S[3] fromRvalStaticArray = makeStaticArray();
        assert(copies == 0); // moved or emplaced
    }
    assert(destroyed == 3);
    reset();

    {
        S[3] fromArrayLiteral = [S(), S(), S()];
        assert(copies == 0); // moved or emplaced
    }
    assert(destroyed == 3);
    reset();

    {
        S[3] fromSliceExp = globals[];
        assert(copies == 3);
    }
    assert(destroyed == 3);
    reset();

    {
        S[] slice = globals[];
        S[3] fromLvalSlice = slice;
        assert(copies == 3);
    }
    assert(destroyed == 3);
    reset();

    {
        S[3] fromRvalSlice = makeSlice(globals);
        assert(copies == 3);
    }
    assert(destroyed == 3);
    reset();

    {
        S *p = &globals[0];
        S[3] fromSingleLval = *p;
        assert(copies == 3);
    }
    assert(destroyed == 3);
    reset();

    {
        S[3] fromSingleRval = S();
        assert(destroyed == 1); // temporary
        assert(copies == 3);
    }
    assert(destroyed == 4);
    reset();
}
