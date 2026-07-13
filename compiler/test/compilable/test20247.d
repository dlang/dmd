// https://github.com/dlang/dmd/issues/20247

// is() pattern matching should strip shared from static array
static if (is(shared(int[1]) == shared(T), T))
    static assert(is(T == int[1]));

// cast() should remove shared from static array
shared(int[1]) a;
static assert(is(typeof(cast() a) == int[1]));

// Unshared template alias
template Unshared(T : shared(U), U) { alias Unshared = U; }
static assert(is(Unshared!(shared(int[1])) == int[1]));

// Combinations
static assert(is(shared(int[2][1]) == shared(V), V) && is(V == int[2][1]));
static assert(is(shared(const(int[1])) == shared(const(W)), W) && is(W == int[1]));
