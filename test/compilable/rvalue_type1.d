// REQUIRED_ARGS: -preview=rvaluetype

struct S {}

static assert(is(@rvalue(S)));
static assert(is(@rvalue(S) : S));
static assert(!is(S : @rvalue(S)));
static assert(!is(S == @rvalue(S)));

static assert(is(@rvalue(S) == @rvalue));
static assert(!is(S == @rvalue));

static assert(!is(int* : @rvalue(int)*));
static assert(!is(S* : @rvalue(S)*));
static assert(!is(@rvalue(S)* : S*));

static assert(!is(@rvalue(int)[]));
static assert(!is(@rvalue(char)[byte]));
static assert(!is(char[@rvalue(char)]));

static assert(is(typeof(cast(@rvalue)0) == @rvalue(int)));
static assert(is(typeof(cast(@rvalue const)0) == const(@rvalue(int))));

ref @rvalue(int) func(ref int a) { return cast(@rvalue)a; }
int g;
void fun(ref @rvalue int a = 1, ref @rvalue int b = cast(@rvalue)g);
