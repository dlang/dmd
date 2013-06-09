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

/******************************************/
// 7533
struct Foo7533(int n)
{
    pure static this() { }
}

alias Foo7533!5 Bar7533;

/******************************************/
// 10163
struct S10163 { @disable this(); this(int) { } }
class C10163 { @disable this() { } }

void[1] arr10163;
S10163 s10163;
C10163 c10163;

static this()
{
    s10163 = S10163(1);
    arr10163 = [cast(byte)0];
}

struct T10163
{
    static S10163 s;
    static void[1] arr;

    static this()
    {
        s = S10163(10);
        arr = [cast(byte)0];
    }
}

template Temp10163()
{
    void[1] arrm10163;
    S10163 sm10163;
    C10163 cm10163;

    static this()
    {
        sm10163 = S10163(1);
        arrm10163 = [cast(byte)0];
    }
}

mixin Temp10163;

/******************************************/

void main()
{
}
