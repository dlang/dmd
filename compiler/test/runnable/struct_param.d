// PERMUTE_ARGS: -inline -O

enum SpecialFunc
{
    NonTrivialCtor = 1,
    CopyCtor       = 2,
    MoveCtor       = 4,
    PostBlit       = 8,
    Dtor           = 16
}

enum SpecialInit
{
    none,
    char_,
    expression,
    staticArray
}

mixin template Field(size_t size, SpecialInit init_)
{
    static if (size == 1)
    {
        static if (init_ == SpecialInit.none)              ubyte var;
        else static if (init_ == SpecialInit.char_)        char var;
        else static if (init_ == SpecialInit.expression)   ubyte var = 0x1a;
        else static if (init_ == SpecialInit.staticArray)  ubyte[1] var = [0xcc];
        else static assert(0);
    }
    else static if (size == 2)
    {
        static if (init_ == SpecialInit.none)              ushort var;
        else static if (init_ == SpecialInit.char_)        char[2] var;
        else static if (init_ == SpecialInit.expression)   ushort var = 0x1a1b;
        else static if (init_ == SpecialInit.staticArray)  ubyte[2] var = [0xcc, 0xcd];
        else static assert(0);
    }
    else static if (size == 4)
    {
        static if (init_ == SpecialInit.none)              uint var;
        else static if (init_ == SpecialInit.char_)        char[4] var;
        else static if (init_ == SpecialInit.expression)   uint var = 0x1a1b1c1d;
        else static if (init_ == SpecialInit.staticArray)  ubyte[4] var = [0xcc, 0xcd, 0xce, 0xcf];
        else static assert(0);
    }
    else static if (size == 8)
    {
        static if (init_ == SpecialInit.none)              ulong var;
        else static if (init_ == SpecialInit.char_)        char[8] var;
        else static if (init_ == SpecialInit.expression)   ulong var = 0x1a1b1c1d1e1f2021L;
        else static if (init_ == SpecialInit.staticArray)  ubyte[8] var = [0xcc, 0xcd, 0xce, 0xcf, 0xd0, 0xd1, 0xd2, 0xd3];
        else static assert(0);
    }
    else static if (size == 16)
    {
        static if (init_ == SpecialInit.none)              uint[] var;
        else                                               string var = "test";
    }
    else static if (size == 32)
    {
        static if (init_ == SpecialInit.char_)             char[32] var;
        else                                               ubyte[32] var = 0x31;
    }
    else static assert(0);
}

mixin template Fields(size_t size, SpecialInit init_)
{
    static if (size == 0) {}
    else static if (size == 1)
        mixin Field!(size, init_)                          A;
    else static if (size == 2)
        mixin Field!(size, init_)                          A;
    else static if (size == 3)
    {
        mixin Field!(2, init_)                             A;
        mixin Field!(1, init_)                             B;
    }
    else static if (size == 4)
        mixin Field!(size, init_)                          A;
    else static if (size >= 5 && size <= 6)
    {
        mixin Field!(4, init_)                             A;
        mixin Field!(size - 4, init_)                      B;
    }
    else static if (size == 7)
    {
        mixin Field!(4, init_)                             A;
        mixin Field!(2, init_)                             B;
        mixin Field!(1, init_)                             C;
    }
    else static if (size == 8)
        mixin Field!(size, init_)                          A;
    else static if (size >= 9 && size <= 15)
    {
        mixin Field!(8, init_)                             A;
        mixin Fields!(size - 8, init_)                     B;
    }
    else static if (size == 16)
        mixin Field!(size, init_)                          A;
    else static if (size >= 17 && size <= 31)
    {
        mixin Field!(16, init_)                            A;
        mixin Fields!(size - 16, init_)                    B;
    }
    else static if (size == 32)
        mixin Field!(size, init_)                          A;
    else static if (size >= 33 && size <= 64)
    {
        mixin Field!(32, init_)                            A;
        mixin Fields!(size - 32, init_)                    B;
    }
    else static if (size >= 65 && size <= 128)
    {
        mixin Fields!(64, init_)                           A;
        mixin Fields!(size - 64, init_)                    B;
    }
    else static assert(0);
}

struct StructWithSpecialFunc(SpecialFunc func)
{
    ubyte var;

    static if ((func & SpecialFunc.NonTrivialCtor) != 0)
    {
        this(int) inout
        {
            var = 0x3a;
        }
    }

    static if ((func & SpecialFunc.CopyCtor) != 0)
    {
        this(ref inout(typeof(this)) rhs)
        {
            var = rhs.var;
        }
    }

    static if ((func & SpecialFunc.MoveCtor) != 0)
    {
        this(typeof(this) rhs)
        {
            var = rhs.var;
            rhs.var = 0;
        }
    }

    static if ((func & SpecialFunc.PostBlit) != 0)
    {
        this(this) {}
    }

    static if ((func & SpecialFunc.Dtor) != 0)
    {
        ~this()
        {
            assert(var == 0 || var == 0x3a);
            var = 0xdd;
        }
    }
}

struct Struct(size_t size, SpecialFunc func, SpecialInit init_)
{
    enum hasCtor = (func & SpecialFunc.NonTrivialCtor) != 0;
    enum remainingSize = func && size != 0 ? size - 1 : size;

    static if (func)
        StructWithSpecialFunc!func special;

    mixin Fields!(remainingSize, init_);

    static if (hasCtor)
    {
        this(int)
        {
            this.special = StructWithSpecialFunc!func(0);
        }
    }
}

R testArgument(R, T)(T rv, inout(T*) orig = null)
{
    assert(!orig || rv == *orig);
    rv = T.init;
    return rv;
}

pragma(inline, false)
void testType(S)()
{
    static if (S.hasCtor)
    {
        S s = S(0);
    }
    else
    {
        S s;
    }

    S s2 = s;

    assert(testArgument!(S, S)(S.init) == S.init);

    static if (S.hasCtor)
        assert(testArgument!(S, S)(S(0), &s2) == S.init);

    assert(testArgument!(S, S)(s, &s2) == S.init);
    assert(s == s2);
    assert(testArgument!(const(S), S)(s, &s2) == S.init);
    assert(s == s2);

    static if (S.hasCtor)
        assert(s.special.var == 0x3a);
}

void main()
{
    // Skipped here but [0, 2, 3, 5, 64, 65] are also worth testing
    enum size_t[] size = [1, 4, 8, 9, 16, 17, 32, 33];

    // Skip less commonly used combinations to save some time
    enum SpecialFunc[] func = [
        cast(SpecialFunc)0,
        SpecialFunc.NonTrivialCtor,
        SpecialFunc.NonTrivialCtor | SpecialFunc.CopyCtor,
        //SpecialFunc.NonTrivialCtor | SpecialFunc.CopyCtor | SpecialFunc.MoveCtor,
        SpecialFunc.NonTrivialCtor | SpecialFunc.Dtor,
        //SpecialFunc.NonTrivialCtor | SpecialFunc.CopyCtor | SpecialFunc.Dtor,
        SpecialFunc.NonTrivialCtor | SpecialFunc.CopyCtor | SpecialFunc.MoveCtor | SpecialFunc.Dtor,
        // SpecialFunc.NonTrivialCtor | SpecialFunc.PostBlit,
        // SpecialFunc.NonTrivialCtor | SpecialFunc.PostBlit | SpecialFunc.Dtor,
        SpecialFunc.CopyCtor,
        SpecialFunc.CopyCtor | SpecialFunc.MoveCtor,
        //SpecialFunc.CopyCtor | SpecialFunc.Dtor,
        SpecialFunc.CopyCtor | SpecialFunc.MoveCtor | SpecialFunc.Dtor,
        // SpecialFunc.PostBlit,
        // SpecialFunc.PostBlit | SpecialFunc.Dtor,
        SpecialFunc.Dtor];

    enum SpecialInit[] init_ = [
        SpecialInit.none,
        SpecialInit.char_,
        SpecialInit.expression,
        SpecialInit.staticArray];

    static foreach (i; size)
        static foreach (j; func)
            static foreach (k; init_)
                testType!(Struct!(i, j, k));
}
