module traits_hasAliasing;

@safe pure nothrow @nogc:

/** Verify behaviour of `__traits(hasAliasing, void*)` being same as `std.traits.hasAliasing`.
 *
 * Copied from Phobos `std.traits`.
 */
void test_hasAliasing()
{
    static assert(__traits(hasAliasing, void*));
    static assert(!__traits(hasAliasing, void function()));

    struct S1 { int a; Object b; }
    struct S2 { string a; }
    struct S3 { int a; immutable Object b; }
    struct S4 { float[3] vals; }
    struct S41 { int*[3] vals; }
    struct S42 { immutable(int)*[3] vals; }

    static assert( __traits(hasAliasing, S1));
    static assert(!__traits(hasAliasing, S2));
    static assert(!__traits(hasAliasing, S3));
    static assert(!__traits(hasAliasing, S4));
    static assert( __traits(hasAliasing, S41));
    static assert(!__traits(hasAliasing, S42));

    static assert( __traits(hasAliasing, uint[uint]));
    static assert(!__traits(hasAliasing, immutable(uint[uint])));
    static assert( __traits(hasAliasing, void delegate()));
    static assert( __traits(hasAliasing, void delegate() const));
    static assert(!__traits(hasAliasing, void delegate() immutable));
    static assert( __traits(hasAliasing, void delegate() shared));
    static assert( __traits(hasAliasing, void delegate() shared const));
    static assert( __traits(hasAliasing, const(void delegate())));
    static assert( __traits(hasAliasing, const(void delegate() const)));
    static assert(!__traits(hasAliasing, const(void delegate() immutable)));
    static assert( __traits(hasAliasing, const(void delegate() shared)));
    static assert( __traits(hasAliasing, const(void delegate() shared const)));
    static assert(!__traits(hasAliasing, immutable(void delegate())));
    static assert(!__traits(hasAliasing, immutable(void delegate() const)));
    static assert(!__traits(hasAliasing, immutable(void delegate() immutable)));
    static assert(!__traits(hasAliasing, immutable(void delegate() shared)));
    static assert(!__traits(hasAliasing, immutable(void delegate() shared const)));
    static assert( __traits(hasAliasing, shared(const(void delegate()))));
    static assert( __traits(hasAliasing, shared(const(void delegate() const))));
    static assert(!__traits(hasAliasing, shared(const(void delegate() immutable))));
    static assert( __traits(hasAliasing, shared(const(void delegate() shared))));
    static assert( __traits(hasAliasing, shared(const(void delegate() shared const))));

    interface I;
    static assert( __traits(hasAliasing, I));

    import std.typecons : Rebindable;
    static assert( __traits(hasAliasing, Rebindable!(const Object)));
    static assert(!__traits(hasAliasing, Rebindable!(immutable Object)));
    static assert( __traits(hasAliasing, Rebindable!(shared Object)));
    static assert( __traits(hasAliasing, Rebindable!Object));

    struct S5
    {
        void delegate() immutable b;
        shared(void delegate() immutable) f;
        immutable(void delegate() immutable) j;
        shared(const(void delegate() immutable)) n;
    }
    struct S6 { typeof(S5.tupleof) a; void delegate() p; }
    static assert(!__traits(hasAliasing, S5));
    static assert( __traits(hasAliasing, S6));

    struct S7 { void delegate() a; int b; Object c; }
    class S8 { int a; int b; }
    class S9 { typeof(S8.tupleof) a; }
    class S10 { typeof(S8.tupleof) a; int* b; }
    static assert( __traits(hasAliasing, S7));
    static assert( __traits(hasAliasing, S8));
    static assert( __traits(hasAliasing, S9));
    static assert( __traits(hasAliasing, S10));
    struct S11 {}
    class S12 {}
    interface S13 {}
    union S14 {}
    static assert(!__traits(hasAliasing, S11));
    static assert( __traits(hasAliasing, S12));
    static assert( __traits(hasAliasing, S13));
    static assert(!__traits(hasAliasing, S14));

    class S15 { S15[1] a; }
    static assert( __traits(hasAliasing, S15));
    static assert(!__traits(hasAliasing, immutable(S15)));
}

void test_hasAliasing_enums()
{
    enum Ei : string { a = "a", b = "b" }
    enum Ec : const(char)[] { a = "a", b = "b" }
    enum Em : char[] { a = null, b = null }

    static assert(!__traits(hasAliasing, Ei));
    static assert( __traits(hasAliasing, Ec));
    static assert( __traits(hasAliasing, Em));
}
