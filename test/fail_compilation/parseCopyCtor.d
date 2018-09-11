/*
TEST_OUTPUT:
---
fail_compilation/parseCopyCtor.d(14): Error: constructors and copy constructors cannot be static
fail_compilation/parseCopyCtor.d(15): Error: the copy constructor cannot be templated
fail_compilation/parseCopyCtor.d(16): Error: the copy constructor receives exactly one argument
fail_compilation/parseCopyCtor.d(17): Error: the copy constructor receives exactly one argument
fail_compilation/parseCopyCtor.d(18): Error: the parameter to the copy constructor must by passed by reference. Add `ref` to the parameter type
---
*/

struct A
{
    static @implicit this(ref A another) {}
    @implicit this()(ref A another) {}
    @implicit this(ref A another, int b) {}
    @implicit this(int b, ref A another) {}
    @implicit this(A another) {}
    @implicit this(ref A another) {}
    this(ref A another) @implicit {}
}
