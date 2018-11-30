module core.lifetime;

/+
emplaceRef is a package function for druntime internal use. It works like
emplace, but takes its argument by ref (as opposed to "by pointer").
This makes it easier to use, easier to be safe, and faster in a non-inline
build.
Furthermore, emplaceRef optionally takes a type parameter, which specifies
the type we want to build. This helps to build qualified objects on mutable
buffer, without breaking the type system with unsafe casts.
+/
private void emplaceRef(T, UT, Args...)(ref UT chunk, auto ref Args args)
{
    static if (args.length == 0)
    {
        static assert(is(typeof({static T i;})),
            "Cannot emplace a " ~ T.stringof ~ " because " ~ T.stringof ~
            ".this() is annotated with @disable.");
        static if (is(T == class)) static assert(!__traits(isAbstractClass, T),
            T.stringof ~ " is abstract and it can't be emplaced");
        emplaceInitializer(chunk);
    }
    else static if (
        !is(T == struct) && Args.length == 1 /* primitives, enums, arrays */
        ||
        Args.length == 1 && is(typeof({T t = args[0];})) /* conversions */
        ||
        is(typeof(T(args))) /* general constructors */)
    {
        static struct S
        {
            T payload;
            this(ref Args x)
            {
                static if (Args.length == 1)
                    static if (is(typeof(payload = x[0])))
                        payload = x[0];
                    else
                        payload = T(x[0]);
                else
                    payload = T(x);
            }
        }
        if (__ctfe)
        {
            static if (is(typeof(chunk = T(args))))
                chunk = T(args);
            else static if (args.length == 1 && is(typeof(chunk = args[0])))
                chunk = args[0];
            else assert(0, "CTFE emplace doesn't support "
                ~ T.stringof ~ " from " ~ Args.stringof);
        }
        else
        {
            S* p = () @trusted { return cast(S*) &chunk; }();
            static if (UT.sizeof > 0)
                emplaceInitializer(*p);
            p.__ctor(args);
        }
    }
    else static if (is(typeof(chunk.__ctor(args))))
    {
        // This catches the rare case of local types that keep a frame pointer
        emplaceInitializer(chunk);
        chunk.__ctor(args);
    }
    else
    {
        //We can't emplace. Try to diagnose a disabled postblit.
        static assert(!(Args.length == 1 && is(Args[0] : T)),
            "Cannot emplace a " ~ T.stringof ~ " because " ~ T.stringof ~
            ".this(this) is annotated with @disable.");

        //We can't emplace.
        static assert(false,
            T.stringof ~ " cannot be emplaced from " ~ Args[].stringof ~ ".");
    }
}
// ditto
static import core.internal.traits;
private void emplaceRef(UT, Args...)(ref UT chunk, auto ref Args args)
    if (is(UT == core.internal.traits.Unqual!UT))
{
    emplaceRef!(UT, UT)(chunk, args);
}

//emplace helper functions
private void emplaceInitializer(T)(scope ref T chunk) @trusted pure nothrow
{
    import core.internal.traits : hasElaborateAssign, isAssignable;
    static if (!hasElaborateAssign!T && isAssignable!T)
        chunk = T.init;
    else
    {
        static if (__traits(isZeroInit, T))
        {
            import core.stdc.string : memset;
            memset(&chunk, 0, T.sizeof);
        }
        else
        {
            import core.stdc.string : memcpy;
            static immutable T init = T.init;
            memcpy(&chunk, &init, T.sizeof);
        }
    }
}

// emplace
/**
Given a pointer `chunk` to uninitialized memory (but already typed
as `T`), constructs an object of non-`class` type `T` at that
address. If `T` is a class, initializes the class reference to null.
Returns: A pointer to the newly constructed object (which is the same
as `chunk`).
 */
T* emplace(T)(T* chunk) @safe pure nothrow
{
    emplaceRef!T(*chunk);
    return chunk;
}

///
@system unittest
{
    static struct S
    {
        int i = 42;
    }
    S[2] s2 = void;
    emplace(&s2);
    assert(s2[0].i == 42 && s2[1].i == 42);
}

///
@system unittest
{
    interface I {}
    class K : I {}

    K k = void;
    emplace(&k);
    assert(k is null);

    I i = void;
    emplace(&i);
    assert(i is null);
}

/**
Given a pointer `chunk` to uninitialized memory (but already typed
as a non-class type `T`), constructs an object of type `T` at
that address from arguments `args`. If `T` is a class, initializes
the class reference to `args[0]`.
This function can be `@trusted` if the corresponding constructor of
`T` is `@safe`.
Returns: A pointer to the newly constructed object (which is the same
as `chunk`).
 */
T* emplace(T, Args...)(T* chunk, auto ref Args args)
    if (is(T == struct) || Args.length == 1)
{
    emplaceRef!T(*chunk, args);
    return chunk;
}

///
@system unittest
{
    int a;
    int b = 42;
    assert(*emplace!int(&a, b) == 42);
}

@system unittest
{
    shared int i;
    emplace(&i, 42);
    assert(i == 42);
}

private @nogc pure nothrow @safe
void testEmplaceChunk(void[] chunk, size_t typeSize, size_t typeAlignment)
{
    assert(chunk.length >= typeSize, "emplace: Chunk size too small.");
    assert((cast(size_t) chunk.ptr) % typeAlignment == 0, "emplace: Chunk is not aligned.");
}

/**
Given a raw memory area `chunk` (but already typed as a class type `T`),
constructs an object of `class` type `T` at that address. The constructor
is passed the arguments `Args`.
If `T` is an inner class whose `outer` field can be used to access an instance
of the enclosing class, then `Args` must not be empty, and the first member of it
must be a valid initializer for that `outer` field. Correct initialization of
this field is essential to access members of the outer class inside `T` methods.
Note:
This function is `@safe` if the corresponding constructor of `T` is `@safe`.
Returns: The newly constructed object.
 */
T emplace(T, Args...)(T chunk, auto ref Args args)
    if (is(T == class))
{
    import core.internal.traits : isInnerClass;

    static assert(!__traits(isAbstractClass, T), T.stringof ~
        " is abstract and it can't be emplaced");

    // Initialize the object in its pre-ctor state
    enum classSize = __traits(classInstanceSize, T);
    (() @trusted => (cast(void*) chunk)[0 .. classSize] = typeid(T).initializer[])();

    static if (isInnerClass!T)
    {
        static assert(Args.length > 0,
            "Initializing an inner class requires a pointer to the outer class");
        static assert(is(Args[0] : typeof(T.outer)),
            "The first argument must be a pointer to the outer class");

        chunk.outer = args[0];
        alias args1 = args[1..$];
    }
    else alias args1 = args;

    // Call the ctor if any
    static if (is(typeof(chunk.__ctor(args1))))
    {
        // T defines a genuine constructor accepting args
        // Go the classic route: write .init first, then call ctor
        chunk.__ctor(args1);
    }
    else
    {
        static assert(args1.length == 0 && !is(typeof(&T.__ctor)),
            "Don't know how to initialize an object of type "
            ~ T.stringof ~ " with arguments " ~ typeof(args1).stringof);
    }
    return chunk;
}

///
@safe unittest
{
    () @safe {
        class SafeClass
        {
            int x;
            @safe this(int x) { this.x = x; }
        }

        auto buf = new void[__traits(classInstanceSize, SafeClass)];
        auto support = (() @trusted => cast(SafeClass)(buf.ptr))();
        auto safeClass = emplace!SafeClass(support, 5);
        assert(safeClass.x == 5);

        class UnsafeClass
        {
            int x;
            @system this(int x) { this.x = x; }
        }

        auto buf2 = new void[__traits(classInstanceSize, UnsafeClass)];
        auto support2 = (() @trusted => cast(UnsafeClass)(buf2.ptr))();
        static assert(!__traits(compiles, emplace!UnsafeClass(support2, 5)));
        static assert(!__traits(compiles, emplace!UnsafeClass(buf2, 5)));
    }();
}

@safe unittest
{
    class Outer
    {
        int i = 3;
        class Inner
        {
            @safe auto getI() { return i; }
        }
    }
    auto outerBuf = new void[__traits(classInstanceSize, Outer)];
    auto outerSupport = (() @trusted => cast(Outer)(outerBuf.ptr))();

    auto innerBuf = new void[__traits(classInstanceSize, Outer.Inner)];
    auto innerSupport = (() @trusted => cast(Outer.Inner)(innerBuf.ptr))();

    auto inner = innerSupport.emplace!(Outer.Inner)(outerSupport.emplace!Outer);
    assert(inner.getI == 3);
}

/**
Given a raw memory area `chunk`, constructs an object of `class` type `T` at
that address. The constructor is passed the arguments `Args`.
If `T` is an inner class whose `outer` field can be used to access an instance
of the enclosing class, then `Args` must not be empty, and the first member of it
must be a valid initializer for that `outer` field. Correct initialization of
this field is essential to access members of the outer class inside `T` methods.
Preconditions:
`chunk` must be at least as large as `T` needs and should have an alignment
multiple of `T`'s alignment. (The size of a `class` instance is obtained by using
$(D __traits(classInstanceSize, T))).
Note:
This function can be `@trusted` if the corresponding constructor of `T` is `@safe`.
Returns: The newly constructed object.
 */
T emplace(T, Args...)(void[] chunk, auto ref Args args)
    if (is(T == class))
{
    import core.internal.traits : maxAlignment;
    enum classSize = __traits(classInstanceSize, T);
    testEmplaceChunk(chunk, classSize, maxAlignment!(void*, typeof(T.tupleof)));
    return emplace!T(cast(T)(chunk.ptr), args);
}

///
@system unittest
{
    static class C
    {
        int i;
        this(int i){this.i = i;}
    }
    auto buf = new void[__traits(classInstanceSize, C)];
    auto c = emplace!C(buf, 5);
    assert(c.i == 5);
}

@system unittest
{
    class Outer
    {
        int i = 3;
        class Inner
        {
            auto getI() { return i; }
        }
    }
    auto outerBuf = new void[__traits(classInstanceSize, Outer)];
    auto innerBuf = new void[__traits(classInstanceSize, Outer.Inner)];
    auto inner = innerBuf.emplace!(Outer.Inner)(outerBuf.emplace!Outer);
    assert(inner.getI == 3);
}

@nogc pure nothrow @safe unittest
{
    int var = 6;
    align(__conv_EmplaceTestClass.alignof) ubyte[__traits(classInstanceSize, __conv_EmplaceTestClass)] buf;
    auto support = (() @trusted => cast(__conv_EmplaceTestClass)(buf.ptr))();
    auto k = emplace!__conv_EmplaceTestClass(support, 5, var);
    assert(k.i == 5);
    assert(var == 7);
}

/**
Given a raw memory area `chunk`, constructs an object of non-$(D
class) type `T` at that address. The constructor is passed the
arguments `args`, if any.
Preconditions:
`chunk` must be at least as large
as `T` needs and should have an alignment multiple of `T`'s
alignment.
Note:
This function can be `@trusted` if the corresponding constructor of
`T` is `@safe`.
Returns: A pointer to the newly constructed object.
 */
T* emplace(T, Args...)(void[] chunk, auto ref Args args)
    if (!is(T == class))
{
    import core.internal.traits : Unqual;
    testEmplaceChunk(chunk, T.sizeof, T.alignof);
    emplaceRef!(T, Unqual!T)(*cast(Unqual!T*) chunk.ptr, args);
    return cast(T*) chunk.ptr;
}

///
@system unittest
{
    struct S
    {
        int a, b;
    }
    auto buf = new void[S.sizeof];
    S s;
    s.a = 42;
    s.b = 43;
    auto s1 = emplace!S(buf, s);
    assert(s1.a == 42 && s1.b == 43);
}

// Bulk of emplace unittests starts here

@system unittest /* unions */
{
    static union U
    {
        string a;
        int b;
        struct
        {
            long c;
            int[] d;
        }
    }
    U u1 = void;
    U u2 = { "hello" };
    emplace(&u1, u2);
    assert(u1.a == "hello");
}

version (unittest) private struct __conv_EmplaceTest
{
    int i = 3;
    this(int i)
    {
        assert(this.i == 3 && i == 5);
        this.i = i;
    }
    this(int i, ref int j)
    {
        assert(i == 5 && j == 6);
        this.i = i;
        ++j;
    }

@disable:
    this();
    this(this);
    void opAssign();
}

version (unittest) private class __conv_EmplaceTestClass
{
    int i = 3;
    this(int i) @nogc @safe pure nothrow
    {
        assert(this.i == 3 && i == 5);
        this.i = i;
    }
    this(int i, ref int j) @nogc @safe pure nothrow
    {
        assert(i == 5 && j == 6);
        this.i = i;
        ++j;
    }
}

@system unittest // bugzilla 15772
{
    abstract class Foo {}
    class Bar: Foo {}
    void[] memory;
    // test in emplaceInitializer
    static assert(!is(typeof(emplace!Foo(cast(Foo*) memory.ptr))));
    static assert( is(typeof(emplace!Bar(cast(Bar*) memory.ptr))));
    // test in the emplace overload that takes void[]
    static assert(!is(typeof(emplace!Foo(memory))));
    static assert( is(typeof(emplace!Bar(memory))));
}

@system unittest
{
    struct S { @disable this(); }
    S s = void;
    static assert(!__traits(compiles, emplace(&s)));
    emplace(&s, S.init);
}

@system unittest
{
    struct S1
    {}

    struct S2
    {
        void opAssign(S2);
    }

    S1 s1 = void;
    S2 s2 = void;
    S1[2] as1 = void;
    S2[2] as2 = void;
    emplace(&s1);
    emplace(&s2);
    emplace(&as1);
    emplace(&as2);
}

@system unittest
{
    static struct S1
    {
        this(this) @disable;
    }
    static struct S2
    {
        this() @disable;
    }
    S1[2] ss1 = void;
    S2[2] ss2 = void;
    emplace(&ss1);
    static assert(!__traits(compiles, emplace(&ss2)));
    S1 s1 = S1.init;
    S2 s2 = S2.init;
    static assert(!__traits(compiles, emplace(&ss1, s1)));
    emplace(&ss2, s2);
}

@system unittest
{
    struct S
    {
        immutable int i;
    }
    S s = void;
    S[2] ss1 = void;
    S[2] ss2 = void;
    emplace(&s, 5);
    assert(s.i == 5);
    emplace(&ss1, s);
    assert(ss1[0].i == 5 && ss1[1].i == 5);
    emplace(&ss2, ss1);
    assert(ss2 == ss1);
}

//Start testing emplace-args here

@system unittest
{
    interface I {}
    class K : I {}

    K k = null, k2 = new K;
    assert(k !is k2);
    emplace!K(&k, k2);
    assert(k is k2);

    I i = null;
    assert(i !is k);
    emplace!I(&i, k);
    assert(i is k);
}

@system unittest
{
    static struct S
    {
        int i = 5;
        void opAssign(S){assert(0);}
    }
    S[2] sa = void;
    S[2] sb;
    emplace(&sa, sb);
    assert(sa[0].i == 5 && sa[1].i == 5);
}

//Start testing emplace-struct here

// Test constructor branch
@system unittest
{
    struct S
    {
        double x = 5, y = 6;
        this(int a, int b)
        {
            assert(x == 5 && y == 6);
            x = a;
            y = b;
        }
    }

    auto s1 = new void[S.sizeof];
    auto s2 = S(42, 43);
    assert(*emplace!S(cast(S*) s1.ptr, s2) == s2);
    assert(*emplace!S(cast(S*) s1, 44, 45) == S(44, 45));
}

@system unittest
{
    __conv_EmplaceTest k = void;
    emplace(&k, 5);
    assert(k.i == 5);
}

@system unittest
{
    int var = 6;
    __conv_EmplaceTest k = void;
    emplace(&k, 5, var);
    assert(k.i == 5);
    assert(var == 7);
}

// Test matching fields branch
@system unittest
{
    struct S { uint n; }
    S s;
    emplace!S(&s, 2U);
    assert(s.n == 2);
}

@safe unittest
{
    struct S { int a, b; this(int){} }
    S s;
    static assert(!__traits(compiles, emplace!S(&s, 2, 3)));
}

@system unittest
{
    struct S { int a, b = 7; }
    S s1 = void, s2 = void;

    emplace!S(&s1, 2);
    assert(s1.a == 2 && s1.b == 7);

    emplace!S(&s2, 2, 3);
    assert(s2.a == 2 && s2.b == 3);
}

//opAssign
@system unittest
{
    static struct S
    {
        int i = 5;
        void opAssign(int){assert(0);}
        void opAssign(S){assert(0);}
    }
    S sa1 = void;
    S sa2 = void;
    S sb1 = S(1);
    emplace(&sa1, sb1);
    emplace(&sa2, 2);
    assert(sa1.i == 1);
    assert(sa2.i == 2);
}

//postblit precedence
@system unittest
{
    //Works, but breaks in "-w -O" because of @@@9332@@@.
    //Uncomment test when 9332 is fixed.
    static struct S
    {
        int i;

        this(S other){assert(false);}
        this(int i){this.i = i;}
        this(this){}
    }
    S a = void;
    assert(is(typeof({S b = a;})));    //Postblit
    assert(is(typeof({S b = S(a);}))); //Constructor
    auto b = S(5);
    emplace(&a, b);
    assert(a.i == 5);

    static struct S2
    {
        int* p;
        this(const S2){}
    }
    static assert(!is(immutable S2 : S2));
    S2 s2 = void;
    immutable is2 = (immutable S2).init;
    emplace(&s2, is2);
}

//nested structs and postblit
@system unittest
{
    static struct S
    {
        int* p;
        this(int i){p = [i].ptr;}
        this(this)
        {
            if (p)
                p = [*p].ptr;
        }
    }
    static struct SS
    {
        S s;
        void opAssign(const SS)
        {
            assert(0);
        }
    }
    SS ssa = void;
    SS ssb = SS(S(5));
    emplace(&ssa, ssb);
    assert(*ssa.s.p == 5);
    assert(ssa.s.p != ssb.s.p);
}

//disabled postblit
@system unittest
{
    static struct S1
    {
        int i;
        @disable this(this);
    }
    S1 s1 = void;
    emplace(&s1, 1);
    assert(s1.i == 1);
    static assert(!__traits(compiles, emplace(&s1, S1.init)));

    static struct S2
    {
        int i;
        @disable this(this);
        this(ref S2){}
    }
    S2 s2 = void;
    static assert(!__traits(compiles, emplace(&s2, 1)));
    emplace(&s2, S2.init);

    static struct SS1
    {
        S1 s;
    }
    SS1 ss1 = void;
    emplace(&ss1);
    static assert(!__traits(compiles, emplace(&ss1, SS1.init)));

    static struct SS2
    {
        S2 s;
    }
    SS2 ss2 = void;
    emplace(&ss2);
    static assert(!__traits(compiles, emplace(&ss2, SS2.init)));


    // SS1 sss1 = s1;      //This doesn't compile
    // SS1 sss1 = SS1(s1); //This doesn't compile
    // So emplace shouldn't compile either
    static assert(!__traits(compiles, emplace(&sss1, s1)));
    static assert(!__traits(compiles, emplace(&sss2, s2)));
}

//Imutability
@system unittest
{
    //Castable immutability
    {
        static struct S1
        {
            int i;
        }
        static assert(is( immutable(S1) : S1));
        S1 sa = void;
        auto sb = immutable(S1)(5);
        emplace(&sa, sb);
        assert(sa.i == 5);
    }
    //Un-castable immutability
    {
        static struct S2
        {
            int* p;
        }
        static assert(!is(immutable(S2) : S2));
        S2 sa = void;
        auto sb = immutable(S2)(null);
        assert(!__traits(compiles, emplace(&sa, sb)));
    }
}

@system unittest
{
    static struct S
    {
        immutable int i;
        immutable(int)* j;
    }
    S s = void;
    emplace(&s, 1, null);
    emplace(&s, 2, &s.i);
    assert(s is S(2, &s.i));
}

//Context pointer
@system unittest
{
    int i = 0;
    {
        struct S1
        {
            void foo(){++i;}
        }
        S1 sa = void;
        S1 sb;
        emplace(&sa, sb);
        sa.foo();
        assert(i == 1);
    }
    {
        struct S2
        {
            void foo(){++i;}
            this(this){}
        }
        S2 sa = void;
        S2 sb;
        emplace(&sa, sb);
        sa.foo();
        assert(i == 2);
    }
}

//Alias this
@system unittest
{
    static struct S
    {
        int i;
    }
    //By Ref
    {
        static struct SS1
        {
            int j;
            S s;
            alias s this;
        }
        S s = void;
        SS1 ss = SS1(1, S(2));
        emplace(&s, ss);
        assert(s.i == 2);
    }
    //By Value
    {
        static struct SS2
        {
            int j;
            S s;
            S foo() @property{return s;}
            alias foo this;
        }
        S s = void;
        SS2 ss = SS2(1, S(2));
        emplace(&s, ss);
        assert(s.i == 2);
    }
}

version (unittest)
{
    //Ambiguity
    private struct __std_conv_S
    {
        int i;
        this(__std_conv_SS ss)         {assert(0);}
        static opCall(__std_conv_SS ss)
        {
            __std_conv_S s; s.i = ss.j;
            return s;
        }
    }
    private struct __std_conv_SS
    {
        int j;
        __std_conv_S s;
        ref __std_conv_S foo() return @property {s.i = j; return s;}
        alias foo this;
    }
}

@system unittest
{
    static assert(is(__std_conv_SS : __std_conv_S));
    __std_conv_S s = void;
    __std_conv_SS ss = __std_conv_SS(1);

    __std_conv_S sTest1 = ss; //this calls "SS alias this" (and not "S.this(SS)")
    emplace(&s, ss); //"alias this" should take precedence in emplace over "opCall"
    assert(s.i == 1);
}

//Nested classes
@system unittest
{
    class A{}
    static struct S
    {
        A a;
    }
    S s1 = void;
    S s2 = S(new A);
    emplace(&s1, s2);
    assert(s1.a is s2.a);
}

//safety & nothrow & CTFE
@system unittest
{
    //emplace should be safe for anything with no elaborate opassign
    static struct S1
    {
        int i;
    }
    static struct S2
    {
        int i;
        this(int j)@safe nothrow{i = j;}
    }

    int i;
    S1 s1 = void;
    S2 s2 = void;

    auto pi = &i;
    auto ps1 = &s1;
    auto ps2 = &s2;

    void foo() @safe nothrow
    {
        emplace(pi);
        emplace(pi, 5);
        emplace(ps1);
        emplace(ps1, 5);
        emplace(ps1, S1.init);
        emplace(ps2);
        emplace(ps2, 5);
        emplace(ps2, S2.init);
    }
    foo();

    T bar(T)() @property
    {
        T t/+ = void+/; //CTFE void illegal
        emplace(&t, 5);
        return t;
    }
    // CTFE
    enum a = bar!int;
    static assert(a == 5);
    enum b = bar!S1;
    static assert(b.i == 5);
    enum c = bar!S2;
    static assert(c.i == 5);
    // runtime
    auto aa = bar!int;
    assert(aa == 5);
    auto bb = bar!S1;
    assert(bb.i == 5);
    auto cc = bar!S2;
    assert(cc.i == 5);
}


@system unittest
{
    struct S
    {
        int[2] get(){return [1, 2];}
        alias get this;
    }
    struct SS
    {
        int[2] ii;
    }
    struct ISS
    {
        int[2] ii;
    }
    S s;
    SS ss = void;
    ISS iss = void;
    emplace(&ss, s);
    emplace(&iss, s);
    assert(ss.ii == [1, 2]);
    assert(iss.ii == [1, 2]);
}

//disable opAssign
@system unittest
{
    static struct S
    {
        @disable void opAssign(S);
    }
    S s;
    emplace(&s, S.init);
}

//opCall
@system unittest
{
    int i;
    //Without constructor
    {
        static struct S1
        {
            int i;
            static S1 opCall(int*){assert(0);}
        }
        S1 s = void;
        static assert(!__traits(compiles, emplace(&s,  1)));
    }
    //With constructor
    {
        static struct S2
        {
            int i = 0;
            static S2 opCall(int*){assert(0);}
            static S2 opCall(int){assert(0);}
            this(int i){this.i = i;}
        }
        S2 s = void;
        emplace(&s,  1);
        assert(s.i == 1);
    }
    //With postblit ambiguity
    {
        static struct S3
        {
            int i = 0;
            static S3 opCall(ref S3){assert(0);}
        }
        S3 s = void;
        emplace(&s, S3.init);
    }
}

/+ these tests can't be performed in druntime, but a mirror still exists in phobos...
@safe unittest //@@@9559@@@
{
    import std.algorithm.iteration : map;
    import std.array : array;
    import std.typecons : Nullable;
    alias I = Nullable!int;
    auto ints = [0, 1, 2].map!(i => i & 1 ? I.init : I(i))();
    auto asArray = array(ints);
}
@system unittest //http://forum.dlang.org/post/nxbdgtdlmwscocbiypjs@forum.dlang.org
{
    import std.array : array;
    import std.datetime : SysTime, UTC;
    import std.math : isNaN;
    static struct A
    {
        double i;
    }
    static struct B
    {
        invariant()
        {
            if (j == 0)
                assert(a.i.isNaN(), "why is 'j' zero?? and i is not NaN?");
            else
                assert(!a.i.isNaN());
        }
        SysTime when; // comment this line avoid the breakage
        int j;
        A a;
    }
    B b1 = B.init;
    assert(&b1); // verify that default eyes invariants are ok;
    auto b2 = B(SysTime(0, UTC()), 1, A(1));
    assert(&b2);
    auto b3 = B(SysTime(0, UTC()), 1, A(1));
    assert(&b3);
    auto arr = [b2, b3];
    assert(arr[0].j == 1);
    assert(arr[1].j == 1);
    auto a2 = arr.array(); // << bang, invariant is raised, also if b2 and b3 are good
}
+/

//static arrays
@system unittest
{
    static struct S
    {
        int[2] ii;
    }
    static struct IS
    {
        immutable int[2] ii;
    }
    int[2] ii;
    S  s   = void;
    IS ims = void;
    ubyte ub = 2;
    emplace(&s, ub);
    emplace(&s, ii);
    emplace(&ims, ub);
    emplace(&ims, ii);
    uint[2] uu;
    static assert(!__traits(compiles, {S ss = S(uu);}));
    static assert(!__traits(compiles, emplace(&s, uu)));
}

@system unittest
{
    int[2]  sii;
    int[2]  sii2;
    uint[2] uii;
    uint[2] uii2;
    emplace(&sii, 1);
    emplace(&sii, 1U);
    emplace(&uii, 1);
    emplace(&uii, 1U);
    emplace(&sii, sii2);
    //emplace(&sii, uii2); //Sorry, this implementation doesn't know how to...
    //emplace(&uii, sii2); //Sorry, this implementation doesn't know how to...
    emplace(&uii, uii2);
    emplace(&sii, sii2[]);
    //emplace(&sii, uii2[]); //Sorry, this implementation doesn't know how to...
    //emplace(&uii, sii2[]); //Sorry, this implementation doesn't know how to...
    emplace(&uii, uii2[]);
}

@system unittest
{
    bool allowDestruction = false;
    struct S
    {
        int i;
        this(this){}
        ~this(){assert(allowDestruction);}
    }
    S s = S(1);
    S[2] ss1 = void;
    S[2] ss2 = void;
    S[2] ss3 = void;
    emplace(&ss1, s);
    emplace(&ss2, ss1);
    emplace(&ss3, ss2[]);
    assert(ss1[1] == s);
    assert(ss2[1] == s);
    assert(ss3[1] == s);
    allowDestruction = true;
}

@system unittest
{
    //Checks postblit, construction, and context pointer
    int count = 0;
    struct S
    {
        this(this)
        {
            ++count;
        }
        ~this()
        {
            --count;
        }
    }

    S s;
    {
        S[4] ss = void;
        emplace(&ss, s);
        assert(count == 4);
    }
    assert(count == 0);
}

@system unittest
{
    struct S
    {
        int i;
    }
    S s;
    S[2][2][2] sss = void;
    emplace(&sss, s);
}

@system unittest //Constness
{
    int a = void;
    emplaceRef!(const int)(a, 5);

    immutable i = 5;
    const(int)* p = void;
    emplaceRef!(const int*)(p, &i);

    struct S
    {
        int* p;
    }
    alias IS = immutable(S);
    S s = void;
    emplaceRef!IS(s, IS());
    S[2] ss = void;
    emplaceRef!(IS[2])(ss, IS());

    IS[2] iss = IS.init;
    emplaceRef!(IS[2])(ss, iss);
    emplaceRef!(IS[2])(ss, iss[]);
}

pure nothrow @safe @nogc unittest
{
    int i;
    emplaceRef(i);
    emplaceRef!int(i);
    emplaceRef(i, 5);
    emplaceRef!int(i, 5);
}

// Test attribute propagation for UDTs
pure nothrow @safe /* @nogc */ unittest
{
    static struct Safe
    {
        this(this) pure nothrow @safe @nogc {}
    }

    Safe safe = void;
    emplaceRef(safe, Safe());

    Safe[1] safeArr = [Safe()];
    Safe[1] uninitializedSafeArr = void;
    emplaceRef(uninitializedSafeArr, safe);
    emplaceRef(uninitializedSafeArr, safeArr);

    static struct Unsafe
    {
        this(this) @system {}
    }

    Unsafe unsafe = void;
    static assert(!__traits(compiles, emplaceRef(unsafe, Unsafe())));

    Unsafe[1] unsafeArr = [Unsafe()];
    Unsafe[1] uninitializedUnsafeArr = void;
    static assert(!__traits(compiles, emplaceRef(uninitializedUnsafeArr, unsafe)));
    static assert(!__traits(compiles, emplaceRef(uninitializedUnsafeArr, unsafeArr)));
}

@system unittest
{
    // Issue 15313
    static struct Node
    {
        int payload;
        Node* next;
        uint refs;
    }

    import core.stdc.stdlib : malloc;
    void[] buf = malloc(Node.sizeof)[0 .. Node.sizeof];

    const Node* n = emplace!(const Node)(buf, 42, null, 10);
    assert(n.payload == 42);
    assert(n.next == null);
    assert(n.refs == 10);
}

@system unittest
{
    int var = 6;
    auto k = emplace!__conv_EmplaceTest(new void[__conv_EmplaceTest.sizeof], 5, var);
    assert(k.i == 5);
    assert(var == 7);
}

@system unittest
{
    class A
    {
        int x = 5;
        int y = 42;
        this(int z)
        {
            assert(x == 5 && y == 42);
            x = y = z;
        }
    }
    void[] buf;

    static align(A.alignof) byte[__traits(classInstanceSize, A)] sbuf;
    buf = sbuf[];
    auto a = emplace!A(buf, 55);
    assert(a.x == 55 && a.y == 55);

    // emplace in bigger buffer
    buf = new byte[](__traits(classInstanceSize, A) + 10);
    a = emplace!A(buf, 55);
    assert(a.x == 55 && a.y == 55);

    // need ctor args
    static assert(!is(typeof(emplace!A(buf))));
}
// Bulk of emplace unittests ends here
