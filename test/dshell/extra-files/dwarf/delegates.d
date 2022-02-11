/*
EXTRA_ARGS: -defaultlib=
*/

void main()
{
    auto dg = delegate() @safe pure nothrow @nogc {};
    auto dg_gc_sys = delegate() @system pure nothrow { new int[10]; };
    auto dg_lazy = delegate(lazy void f) {};
}

