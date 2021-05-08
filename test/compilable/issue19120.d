module issue19120;

alias AliasSeq(Args...) = Args;

struct A(T...) {
    alias S = T;
    alias S this;
}

alias X = A!(int, double);
alias Y = AliasSeq!((X)[0])[0]; // Fine
static assert(is(Y==int));
alias Z = AliasSeq!((X)[0..$]);
static assert(is(Z==X.S));
