/*
TEST_OUTPUT:
---
fail_compilation/test19718.d(27): Error: none of the overloads of template `test19718.execute` are callable using argument types `!()(int function(ref Struct rng) @system)`
fail_compilation/test19718.d(15):        Candidates are: `execute(T)(T function(ref Struct) @safe dg)`
fail_compilation/test19718.d(21):                        `execute(T)(T delegate(ref Struct) @safe dg)`
---
*/

struct Struct
{
    int get() { return 1; }
}

public T execute (T)(T function(ref Struct) @safe dg)
{
    Struct rng;
    return dg(rng);
}

public T execute (T)(T delegate(ref Struct) @safe dg)
{
    Struct rng;
    return dg(rng);
}

auto x = execute((ref Struct rng) { return rng.get(); });
