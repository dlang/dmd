// REQUIRED_ARGS: -preview=rvaluetype

T rvalueOf(T)();
ref T lvalueOf(T)();
alias X(T, U) = typeof(0 ? lvalueOf!T : lvalueOf!U);
alias RL(T, U) = typeof(0 ? rvalueOf!T : lvalueOf!U);

static assert(is(X!(@rvalue(int), int) == int));
static assert(is(X!(@rvalue(int), @rvalue(int)) == @rvalue(int)));
static assert(is(X!(@rvalue(int)*, int*) == int*));
static assert(is(X!(@rvalue(const(int))*, int*) == const(int)*));

struct S { ref @rvalue(int) get(); alias get this; }
static assert(is(X!(@rvalue(S), S) == S));
static assert(is(X!(@rvalue(S), @rvalue(const(S))) == @rvalue(const(S))));
static assert(is(X!(@rvalue(S), int) == int));
static assert(is(X!(@rvalue(S), @rvalue(int)) == @rvalue(int)));
static assert(is(X!(S, @rvalue(int)) == int));

alias F0 = ref @rvalue(int) function(@rvalue ref int);
alias F1 = ref int function(ref int);
alias F2 = ref int function(@rvalue ref int);
static assert(is(X!(F2, F0) == F2));
static assert(is(X!(F0, F2) == F2));
static assert(is(X!(F2, F1) == F2));
static assert(is(X!(F1, F2) == F2));

static assert(is(X!(S, @rvalue(S)) == S));
static assert(is(RL!(S, @rvalue(S)) == @rvalue S));
static assert(is(X!(const(S), @rvalue(S)) == const S));
static assert(is(RL!(const(S), @rvalue(S)) == const @rvalue S));
