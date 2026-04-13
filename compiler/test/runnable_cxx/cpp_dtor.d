// https://github.com/dlang/dmd/issues/22709
// Virtual dtor dispatch through an intermediate class with no explicit dtor.
// Before the fix, C's vtbl had a stale entry for A's dtor at slot 0, causing
// virtual dtor dispatch through A* to call A's dtor instead of C's.
// EXTRA_CPP_SOURCES: cpp_dtor.cpp

extern(C) __gshared int aDestroyed;
extern(C) __gshared int cDestroyed;

extern(C++) void runCPPTests();

extern(C++):

class A
{
    ~this() { aDestroyed = 1; }
}

class B : A
{
}

class C : B
{
    ~this() { cDestroyed = 1; }
}

// D-side factory: C++ calls this to get a C object typed as A*
A makeC() { return new C; }

extern(D) void main()
{
    runCPPTests();
}
