/*
REQUIRED_ARGS: -sktf
*/
bool isType(alias t)
{
    return is(t);
}

static assert(isType(S1));

static assert(!isType("hello"));

struct S1 { double[2] x; }
struct S2 { int[16] i16; }

size_t sizeOf(alias t)
{
    return t.sizeof;
}
static assert(sizeOf(S1) == S1.sizeof);
static assert(sizeOf(S2) == S2.sizeof);

string stringOf(alias y)
{
    return y.stringof;
}
static assert(stringOf(S1) == S1.stringof);
static assert(stringOf(S2) == S2.stringof);


