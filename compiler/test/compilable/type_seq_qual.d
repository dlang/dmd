alias AliasSeq(Args...) = Args;

immutable(AliasSeq!(int, float)) c;
immutable AliasSeq!(int, float) d;
static assert(is(typeof(c) == typeof(d)));

alias TS = AliasSeq!(int, float);
static assert(is(typeof(c) == immutable TS));
static assert(is(immutable(TS)[0] == immutable int));

alias CT = const(TS);
static assert(is(const(TS) == const TS));

pragma(msg, CT[0]); // const(int)
static assert(is(CT[0] == const int)); // immutable(int) == const(int)!!!
pragma(msg, (const(TS)[0]).stringof); // const(int)
static assert(is(const(TS)[0] == const int)); // immutable(int) == const(int)!!!
