/*
https://issues.dlang.org/show_bug.cgi?id=22310

REQUIRED_ARGS: -vtemplates
TEST_OUTPUT:
---
compilable/test22310.d(24): vtemplate: 50000 (19 distinct) instantiation(s) of template `BooleanTypeOf(T)` found
compilable/test22310.d(22): vtemplate: 19 (19 distinct) instantiation(s) of template `AliasThisTypeOf(T)` found
compilable/test22310.d(14): vtemplate: 19 (10 distinct) instantiation(s) of template `OriginalType(T)` found
compilable/test22310.d(37): vtemplate: 1 (0 distinct) instantiation(s) of template `AliasSeq(T...)` found
---
*/

template OriginalType(T)
{
    static if (is(T == enum))
        static assert(0); // for simplification
    else
        alias OriginalType = T;
}

alias AliasThisTypeOf(T) = typeof(__traits(getMember, T.init, __traits(getAliasThis, T)[0]));

template BooleanTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = BooleanTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (is(immutable X == immutable bool))
        alias BooleanTypeOf = X;
    else
        static assert(0, T.stringof~" is not boolean type");
}

alias AliasSeq(T...) = T;
// 10 types
alias SampleTypes = AliasSeq!(bool, char, wchar, dchar, byte, ubyte, short, ushort, int, uint);

void main()
{
    enum count = 5_000;
    static foreach (i; 0 .. count)
        foreach (T; SampleTypes)
            enum _ = is(BooleanTypeOf!T);
}
