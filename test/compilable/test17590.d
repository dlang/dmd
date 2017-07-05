// REQUIRED_ARGS: -o-

// Test that returning a local _static_ struct does not lead to allocation of a closure.
auto foo(int a, bool b) @nogc {
    static struct SInside {}

    SInside res;

    lazyfun(a);

    return res;
}

void lazyfun(scope lazy int a) @nogc;


// Test that returning a local _non-static_ struct does lead to allocation of a closure.
static assert(!__traits(compiles, () @nogc => goo(1)));
static assert(__traits(compiles, () => goo(1)));
auto goo(T)(T a) {
    struct SInside {}

    SInside res;

    lazyfun(a);

    return res;
}
