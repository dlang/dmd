// PERMUTE_ARGS:
// POST_SCRIPT: runnable/extra-files/statictor-postscript.sh

private import std.stdio;

class Foo
{
        static this() {printf("Foo static ctor\n");}
        static ~this() {printf("Foo static dtor\n");}
}

static this() {printf("static ctor\n");}
static ~this() {printf("static dtor\n");}

shared static this()
{
    printf("shared static this()\n");
}

shared static ~this()
{
    printf("shared static this()\n");
}

class Bar
{
        static this() {printf("Bar static ctor\n");}
        static ~this() {printf("Bar static dtor\n");}
}

// 7533
struct Foo7533(int n)
{
    pure static this() { }
}

alias Foo7533!5 Bar7533;

void main()
{
}

