// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

struct S
{
    int* p;
    shared int* s;
    private __mutable
    {
        int* m;
        shared int* ms;
    }
}

struct T
{
    private __mutable int* a;
    private
    {
        __mutable int* b;
    }
    __mutable
    {
        private int* c;
    }
}

static assert(!__traits(isUnderUnderMutable, S.p));
static assert(__traits(isUnderUnderMutable, S.m));

void foo(inout(int)*) @safe
{
    S s;
    const(S) cs;
    immutable(S) is_;
    shared(S) ss;
    shared(const(S)) css;
    inout(S) ws;
    const(inout(S)) cws;
    shared(inout(S)) sws;
    shared(const(inout(S))) scws;

    // for non-__mutable fields, qualifiers are propagated (existing behavior): 
    static assert(is(typeof(s.p)==int*));
    static assert(is(typeof(cs.p)==const(int*)));
    static assert(is(typeof(is_.p)==immutable(int*)));
    static assert(is(typeof(ss.p)==shared(int*)));
    static assert(is(typeof(css.p)==shared(const(int*))));
    static assert(is(typeof(ws.p)==inout(int*)));
    static assert(is(typeof(cws.p)==const(inout(int*))));
    static assert(is(typeof(sws.p)==shared(inout(int*))));
    static assert(is(typeof(scws.p)==shared(const(inout(int*)))));

    static assert(is(typeof(s.s)==shared(int*)));
    static assert(is(typeof(cs.s)==shared(const(int*))));
    static assert(is(typeof(is_.s)==immutable(int*)));
    static assert(is(typeof(ss.s)==shared(int*)));
    static assert(is(typeof(css.s)==shared(const(int*))));
    static assert(is(typeof(ws.s)==shared(inout(int*))));
    static assert(is(typeof(cws.s)==shared(const(inout(int*)))));
    static assert(is(typeof(sws.s)==shared(inout(int*))));
    static assert(is(typeof(scws.s)==shared(const(inout(int*)))));  
    
    // for __mutable fields, qualifier propagation is modified:
    static assert(is(typeof(s.m)==int*));
    static assert(is(typeof(cs.m)==int*));
    // Requires explicit cast to mutable or shared:
    static assert(is(typeof(*cast(int**)&cs.m))); // explicit reinterpret-casts are allowed
    static assert(is(typeof(*cast(shared(int)**)&cs.m))); // explicit reinterpret-casts are allowed
    static assert(is(typeof(is_.m)==shared(int*))); // immutable is implicitly shared
    static assert(is(typeof(ss.m)==shared(int*)));
    static assert(is(typeof(css.m)==shared(int*)));
    static assert(is(typeof(cs.m)==int*));
    static assert(is(typeof(ws.m)==int*));
    static assert(is(typeof(*cast(int**)&ws.m))); // explicit reinterpret-cast
    static assert(is(typeof(*cast(shared(int)**)&ws.m))); // explicit reinterpret-cast
    static assert(is(typeof(cws.m)==int*));
    static assert(is(typeof(*cast(int**)&cws.m))); // explicit reinterpret-cast
    static assert(is(typeof(*cast(shared(int)**)&cws.m))); // explicit reinterpret-cast
    static assert(is(typeof(sws.m)==shared(int*)));
    static assert(is(typeof(scws.m)==shared(int*)));

    static assert(is(typeof(s.ms)==shared(int*)));
    static assert(is(typeof(cs.ms)==shared(int*)));
    static assert(is(typeof(is_.ms)==shared(int*)));
    static assert(is(typeof(ss.ms)==shared(int*)));
    static assert(is(typeof(css.ms)==shared(int*)));
    static assert(is(typeof(ws.ms)==shared(int*)));
    static assert(is(typeof(cws.ms)==shared(int*)));
    static assert(is(typeof(sws.ms)==shared(int*)));
    static assert(is(typeof(scws.ms)==shared(int*)));
}
