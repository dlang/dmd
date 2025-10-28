// REQUIRED_ARGS: -preview=dip1000

struct exit
{
    int x;

    ref int foo() return @safe => x;
}

void main() @nogc @safe
{
    exit obj;

    // scope variable:
    scope (ref int delegate(int x) @safe) dg = ref(int x) => obj.foo = x;
    // Note: `scope` is needed so `main` is `@nogc`

    // scope guard:
    scope(exit) dg = null;
}
