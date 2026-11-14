module incomplete_nogc;
int direct()(int n) { return n ? direct(n - 1) : 0; }
int a()(int n) { return n ? b(n - 1) : 0; }
int b()(int n) { return n ? a(n - 1) : 0; }
int effectA()(int n) { return n ? effectB(n - 1) : 0; }
int effectB()(int n) { auto p = new int; return n ? effectA(n - 1) : *p; }
void externalFunction();
static assert(__traits(compiles, () @nogc { direct(3); }));
static assert(!__traits(compiles, () @nogc { a(3); }));
static assert(!__traits(compiles, () @nogc { effectA(3); }));
static assert(!__traits(compiles, () @nogc { externalFunction(); }));
static assert(!__traits(compiles, () @nogc { auto p = new int; }));
void test() @nogc { direct(3); }

// Resolve a template function through an alias and inspect its inferred type
// before calling it. Deferred body analysis must still infer @nogc.
int lazyLeaf()(int n) { return n; }
alias lazyFunction = lazyLeaf!();
static assert(is(typeof(&lazyFunction) == int function(int) @nogc pure nothrow @safe));
void testLazy() @nogc { lazyFunction(3); }
