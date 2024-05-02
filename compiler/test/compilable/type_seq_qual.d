alias AliasSeq(Args...) = Args;

immutable(AliasSeq!(int, float)) c;
immutable AliasSeq!(int, float) d;
static assert(is(typeof(c) == typeof(d)));

alias TS = AliasSeq!(int, float);
static assert(is(typeof(c) == immutable TS));
static assert(is(immutable(TS)[0] == immutable int));
