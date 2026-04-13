// https://github.com/dlang/dmd/issues/22709
// C++ side: verify virtual dtor dispatch calls C's dtor (not A's) when
// destroying a C object through an A*.
#include <assert.h>

extern "C" int aDestroyed;
extern "C" int cDestroyed;

// Forward declaration matching D's extern(C++) class A
class A {
public:
    virtual ~A();
};

// D-side factory
extern "C++" A* makeC();

void runCPPTests()
{
    A* obj = makeC();

    // Invoke the virtual destructor without freeing memory.
    // obj->~A() dispatches virtually (calls C's dtor) on all ABIs,
    // and does NOT call operator delete, so D-allocated memory is safe.
    aDestroyed = 0;
    cDestroyed = 0;
    obj->~A();

    // C's destructor must be dispatched, not A's
    assert(cDestroyed);
    // A's destructor must be chained from C's aggregate dtor
    assert(aDestroyed);
}
