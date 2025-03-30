// REQUIRED_ARGS: -w -de

void foo() pure nothrow @nogc @safe
{
    asm pure nothrow @nogc @trusted
    {
        ret;
    }
}

void bar()()
{
    asm pure nothrow @nogc @trusted
    {
        ret;
    }
}

static assert(__traits(compiles, () pure nothrow @nogc @safe => bar()));

void baz()()
{
    asm
    {
        ret;
    }
}

// wait for deprecation of asm pure inference
// static assert(!__traits(compiles, () pure => baz()));
static assert(!__traits(compiles, () nothrow => baz()));
// wait for deprecation of asm @nogc inference
// static assert(!__traits(compiles, () @nogc => baz()));
static assert(!__traits(compiles, () @safe => baz()));
