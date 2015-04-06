// PERMUTE_ARGS:
// REQUIRED_ARGS:

struct A(Args...)
{
    enum i = 1;

    // base use case.
    Args[0].T mBase;
    static assert(is(typeof(mBase) == B.T));
    // chained types
    Args[0].T.TT mChain;
    static assert(is(typeof(mChain) == B.T.TT));
    // chained packs
    Args[1+1].FArgs[0] mChainPack;
    static assert(is(typeof(mChainPack) == B));
    // expr
    enum mExpr = Args[1].i;
    static assert(mExpr == B.i);
    // Nested + index eval
    Args[Args[0].i2].T mNested;
    static assert(is(typeof(mNested) == B.T));
    // index with constexpr
    Args[i].T mCEIndex;
    static assert(is(typeof(mCEIndex) == B.T));
    // Nested + index with constexpr
    Args[Args[i].i2].T mNestedCE;
    static assert(is(typeof(mNestedCE) == B.T));

    // alias, base use case
    alias UBase = Args[0].T;
    static assert(is(UBase == B.T));
    // alias, chained types
    alias UChain = Args[0].T.TT;
    static assert(is(UChain == B.T.TT));
    // alias, chained packs
    alias UChainPack = Args[1+1].FArgs[0];
    static assert(is(UChainPack == B));
    // alias, expr
    alias uExpr = Args[1].i;
    static assert(uExpr == B.i);
    // alias, Nested + index eval
    alias UNested = Args[Args[0].i2].T;
    static assert(is(UNested == B.T));
    // alias, index with constexpr
    alias UCEIndex = Args[i].T;
    static assert(is(UCEIndex == B.T));
    // alias, Nested + index with constexpr
    alias UNextedCE = Args[Args[i].i2].T;
    static assert(is(UNextedCE == B.T));
}

struct B
{
    struct T
    {
        struct TT
        {
        }
    }
    enum i = 6;
    enum i2 = 0;
}

struct C(Args...)
{
    alias FArgs = Args;
}

alias Z = A!(B,B,C!(B,B));
