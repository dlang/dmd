/**
 * Written in the D programming language.
 * This module provides functions to uniform calculating hash values for different types
 *
 * Copyright: Copyright Igor Stepanov 2013-2013.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Igor Stepanov
 * Source: $(DRUNTIMESRC core/internal/_hash.d)
 */
module core.internal.hash;

import core.internal.convert;
import core.internal.traits : allSatisfy;

// If true ensure that positive zero and negative zero have the same hash.
// typeid(float).getHash does this but historically hashOf(float) did not.
private enum floatCoalesceZeroes = true;
// If true ensure that all NaNs of the same floating point type have the same hash.
// typeid(float).getHash does not do this but historically hashOf(float) did.
private enum floatCoalesceNaNs = true;

// If either of the above are true then no struct or array that contains the
// representation of a floating point number may be hashed with `bytesHash`.

@nogc nothrow pure @safe unittest
{
    static if (floatCoalesceZeroes)
        assert(hashOf(+0.0) == hashOf(-0.0)); // Same hash for +0.0 and -0.0.
    static if (floatCoalesceNaNs)
        assert(hashOf(double.nan) == hashOf(-double.nan)); // Same hash for different NaN.
}

private enum hasCallableToHash(T) = __traits(compiles,
    {
        size_t hash = ((T* x) => (*x).toHash())(null);
    });

@nogc nothrow pure @safe unittest
{
    static struct S { size_t toHash() { return 4; } }
    assert(hasCallableToHash!S);
    assert(!hasCallableToHash!(shared const S));
}

private enum isFinalClassWithAddressBasedHash(T) = __traits(isFinalClass, T)
    // Use __traits(compiles, ...) in case there are multiple overloads of `toHash`.
    && __traits(compiles, {static assert(&Object.toHash is &T.toHash);});

@nogc nothrow pure @safe unittest
{
    static class C1 {}
    final static class C2 : C1 {}
    final static class C3 : C1 { override size_t toHash() const nothrow { return 1; }}
    static assert(!isFinalClassWithAddressBasedHash!Object);
    static assert(!isFinalClassWithAddressBasedHash!C1);
    static assert(isFinalClassWithAddressBasedHash!C2);
    static assert(!isFinalClassWithAddressBasedHash!C3);
}

/+
Is it valid to calculate a hash code for T based on the bits of its
representation? Always false for interfaces, dynamic arrays, and
associative arrays. False for all classes except final classes that do
not override `toHash`.

Note: according to the spec as of
https://github.com/dlang/dlang.org/commit/d66eff16491b0664c0fc00ba80a7aa291703f1f2
the contents of unnamed paddings between fields is undefined. Currently
this hashing implementation assumes that the padding contents (if any)
for all instances of `T` are the same. The correctness of this
assumption is yet to be verified.
+/
private template canBitwiseHash(T)
{
    static if (is(T EType == enum))
        enum canBitwiseHash = .canBitwiseHash!EType;
    else static if (__traits(isFloating, T))
        enum canBitwiseHash = !(floatCoalesceZeroes || floatCoalesceNaNs);
    else static if (__traits(isScalar, T))
        enum canBitwiseHash = true;
    else static if (is(T == class))
    {
        enum canBitwiseHash = isFinalClassWithAddressBasedHash!T;
    }
    else static if (is(T == interface))
    {
        enum canBitwiseHash = false;
    }
    else static if (is(T == struct))
    {
        static if (hasCallableToHash!T || __traits(isNested, T))
            enum canBitwiseHash = false;
        else
            enum canBitwiseHash = allSatisfy!(.canBitwiseHash, typeof(T.tupleof));
    }
    else static if (is(T == union))
    {
        // Right now we always bytewise hash unions that lack callable `toHash`.
        enum canBitwiseHash = !hasCallableToHash!T;
    }
    else static if (is(T E : E[]))
    {
        static if (__traits(isStaticArray, T))
            enum canBitwiseHash = (T.length == 0) || .canBitwiseHash!E;
        else
            enum canBitwiseHash = false;
    }
    else static if (__traits(isAssociativeArray, T))
    {
        enum canBitwiseHash = false;
    }
    else
    {
        static assert(is(T == delegate) || is(T : void) || is(T : typeof(null)),
            "Internal error: unanticipated type "~T.stringof);
        enum canBitwiseHash = true;
    }
}

private template UnqualUnsigned(T) if (__traits(isIntegral, T))
{
    static if (T.sizeof == ubyte.sizeof) alias UnqualUnsigned = ubyte;
    else static if (T.sizeof == ushort.sizeof) alias UnqualUnsigned = ushort;
    else static if (T.sizeof == uint.sizeof) alias UnqualUnsigned = uint;
    else static if (T.sizeof == ulong.sizeof) alias UnqualUnsigned = ulong;
    else static if (T.sizeof == ulong.sizeof * 2)
    {
        static assert(T.sizeof == ucent.sizeof);
        alias UnqualUnsigned = ucent;
    }
    else
    {
        static assert(0, "No known unsigned equivalent of " ~ T.stringof);
    }

    static assert(UnqualUnsigned.sizeof == T.sizeof && __traits(isUnsigned, UnqualUnsigned));
}

// Overly restrictive for simplicity: has false negatives but no false positives.
private template useScopeConstPassByValue(T)
{
    static if (__traits(isScalar, T))
        enum useScopeConstPassByValue = true;
    else static if (is(T == class) || is(T == interface))
        // Overly restrictive for simplicity.
        enum useScopeConstPassByValue = isFinalClassWithAddressBasedHash!T;
    else static if (is(T == struct) || is(T == union))
    {
        // Overly restrictive for simplicity.
        enum useScopeConstPassByValue = false;
    }
    else static if (is(T : E[], E))
    {
        static if (!__traits(isStaticArray, T))
            // Overly restrictive for simplicity.
            enum useScopeConstPassByValue = .useScopeConstPassByValue!E;
        else static if (T.length == 0)
            enum useScopeConstPassByValue = true;
        else
            enum useScopeConstPassByValue = T.sizeof <= size_t.sizeof
                && .useScopeConstPassByValue!(typeof(T[0]));
    }
    else static if (is(T : V[K], K, V))
    {
        // Overly restrictive for simplicity.
        enum useScopeConstPassByValue = .useScopeConstPassByValue!K
            && .useScopeConstPassByValue!V;
    }
    else
    {
        static assert(is(T == delegate) || is(T : void) || is(T : typeof(null)),
            "Internal error: unanticipated type "~T.stringof);
        enum useScopeConstPassByValue = true;
    }
}

@safe unittest
{
    static assert(useScopeConstPassByValue!int);
    static assert(useScopeConstPassByValue!string);

    static int ctr;
    static struct S1 { ~this() { ctr++; } }
    static struct S2 { this(this) { ctr++; } }
    static assert(!useScopeConstPassByValue!S1,
        "Don't default pass by value a struct with a non-vacuous destructor.");
    static assert(!useScopeConstPassByValue!S2,
        "Don't default pass by value a struct with a non-vacuous postblit.");
}

//enum hash. CTFE depends on base type
size_t hashOf(T)(scope const T val, size_t seed = 0)
if (is(T EType == enum) && useScopeConstPassByValue!EType)
{
    static if (is(T EType == enum)) //for EType
    {
        return hashOf(cast(const EType) val, seed);
    }
    else
    {
        static assert(0);
    }
}

//enum hash. CTFE depends on base type
size_t hashOf(T)(auto ref T val, size_t seed = 0)
if (is(T EType == enum) && !useScopeConstPassByValue!EType)
{
    static if (is(T EType == enum)) //for EType
    {
        EType e_val = cast(EType)val;
        return hashOf(e_val, seed);
    }
    else
    {
        static assert(0);
    }
}

//CTFE ready (depends on base type).
size_t hashOf(T)(scope const auto ref T val, size_t seed = 0)
if (!is(T == enum) && __traits(isStaticArray, T) && canBitwiseHash!T)
{
    // FIXME:
    // We would like to to do this:
    //
    //static if (T.length == 0)
    //    return seed;
    //else static if (T.length == 1)
    //    return hashOf(val[0], seed);
    //else
    //    /+ hash like a dynamic array +/
    //
    // ... but that's inefficient when using a runtime TypeInfo (introduces a branch)
    // and PR #2243 wants typeid(T).getHash(&val) to produce the same result as
    // hashOf(val).
    static if (T.length == 0)
    {
        return bytesHashAlignedBy!size_t((ubyte[]).init, seed);
    }
    static if (is(typeof(toUbyte(val)) == const(ubyte)[]))
    {
        return bytesHashAlignedBy!T(toUbyte(val), seed);
    }
    else //Other types. CTFE unsupported
    {
        assert(!__ctfe, "unable to compute hash of "~T.stringof~" at compile time");
        return bytesHashAlignedBy!T((cast(const(ubyte)*) &val)[0 .. T.sizeof], seed);
    }
}

//CTFE ready (depends on base type).
size_t hashOf(T)(auto ref T val, size_t seed = 0)
if (!is(T == enum) && __traits(isStaticArray, T) && !canBitwiseHash!T)
{
    // FIXME:
    // We would like to to do this:
    //
    //static if (T.length == 0)
    //    return seed;
    //else static if (T.length == 1)
    //    return hashOf(val[0], seed);
    //else
    //    /+ hash like a dynamic array +/
    //
    // ... but that's inefficient when using a runtime TypeInfo (introduces a branch)
    // and PR #2243 wants typeid(T).getHash(&val) to produce the same result as
    // hashOf(val).
    return hashOf(val[], seed);
}

//dynamic array hash
size_t hashOf(T)(scope const T val, size_t seed = 0)
if (!is(T == enum) && !is(T : typeof(null)) && is(T S: S[]) && !__traits(isStaticArray, T)
    && !is(T == struct) && !is(T == class) && !is(T == union)
    && canBitwiseHash!S)
{
    alias ElementType = typeof(val[0]);
    static if (is(typeof(toUbyte(val)) == const(ubyte)[]))
    //ubyteble array (arithmetic types and structs without toHash) CTFE ready for arithmetic types and structs without reference fields
    {
        return bytesHashAlignedBy!ElementType(toUbyte(val), seed);
    }
    else //Other types. CTFE unsupported
    {
        assert(!__ctfe, "unable to compute hash of "~T.stringof~" at compile time");
        return bytesHashAlignedBy!ElementType((cast(const(ubyte)*) val.ptr)[0 .. ElementType.sizeof*val.length], seed);
    }
}

//dynamic array hash
size_t hashOf(T)(T val, size_t seed = 0)
if (!is(T == enum) && !is(T : typeof(null)) && is(T S: S[]) && !__traits(isStaticArray, T)
    && !is(T == struct) && !is(T == class) && !is(T == union)
    && !canBitwiseHash!S)
{
    size_t hash = seed;
    foreach (ref o; val)
    {
        hash = hashOf(hashOf(o), hash); // double hashing because TypeInfo.getHash doesn't allow to pass seed value
    }
    return hash;
}

@nogc nothrow pure @safe unittest // issue 18918
{
    // Check hashOf dynamic array of scalars is usable in @safe code.
    const _ = hashOf("abc");
}

@nogc nothrow pure @system unittest
{
    void*[] val;
    const _ = hashOf(val); // Check a PR doesn't break this.
}

//arithmetic type hash
@trusted @nogc nothrow pure
size_t hashOf(T)(scope const T val, size_t seed = 0) if (!is(T == enum) && __traits(isArithmetic, T))
{
    static if(__traits(isFloating, val))
    {
        static if (floatCoalesceZeroes || floatCoalesceNaNs)
        {
            import core.internal.traits : Unqual;
            Unqual!T data = val;
            // +0.0 and -0.0 become the same.
            static if (floatCoalesceZeroes && is(typeof(data = 0)))
                if (data == 0) data = 0;
            static if (floatCoalesceZeroes && is(typeof(data = 0.0i)))
                if (data == 0.0i) data = 0.0i;
            static if (floatCoalesceZeroes && is(typeof(data = 0.0 + 0.0i)))
            {
                if (data.re == 0.0) data = 0.0 + (data.im * 1.0i);
                if (data.im == 0.0i) data = data.re + 0.0i;
            }
            static if (floatCoalesceNaNs)
                if (data != data) data = T.nan; // All NaN patterns become the same.
        }
        else
        {
            alias data = val;
        }

        static if (T.mant_dig == float.mant_dig && T.sizeof == uint.sizeof)
            return hashOf(*cast(const uint*) &data, seed);
        else static if (T.mant_dig == double.mant_dig && T.sizeof == ulong.sizeof)
            return hashOf(*cast(const ulong*) &data, seed);
        else
            return bytesHashAlignedBy!T(toUbyte(data), seed);
    }
    else
    {
        static if (T.sizeof <= size_t.sizeof && __traits(isIntegral, T))
        {
            static if (size_t.sizeof < ulong.sizeof)
            {
                //MurmurHash3 32-bit single round
                enum uint c1 = 0xcc9e2d51;
                enum uint c2 = 0x1b873593;
                enum uint c3 = 0xe6546b64;
                enum uint r1 = 15;
                enum uint r2 = 13;
            }
            else
            {
                //Half of MurmurHash3 64-bit single round
                //(omits second interleaved update)
                enum ulong c1 = 0x87c37b91114253d5;
                enum ulong c2 = 0x4cf5ad432745937f;
                enum ulong c3 = 0x52dce729;
                enum uint r1 = 31;
                enum uint r2 = 27;
            }
            auto h = c1 * cast(UnqualUnsigned!T) val;
            h = (h << r1) | (h >>> (typeof(h).sizeof * 8 - r1));
            h = (h * c2) ^ seed;
            h = (h << r2) | (h >>> (typeof(h).sizeof * 8 - r2));
            return h * 5 + c3;
        }
        else static if (T.sizeof > size_t.sizeof && __traits(isIntegral, T))
        {
            static foreach (i; 0 .. T.sizeof / size_t.sizeof)
                seed = hashOf(cast(size_t) (val >>> (size_t.sizeof * 8 * i)), seed);
            return seed;
        }
        else
        {
            return bytesHashAlignedBy!T(toUbyte(val), seed);
        }
    }
}

//typeof(null) hash. CTFE supported
@trusted @nogc nothrow pure
size_t hashOf(T)(scope const T val, size_t seed = 0) if (!is(T == enum) && is(T : typeof(null)))
{
    return hashOf(cast(void*)null, seed);
}

//Pointers hash. CTFE unsupported if not null
@trusted @nogc nothrow pure
size_t hashOf(T)(scope const T val, size_t seed = 0)
if (!is(T == enum) && is(T V : V*) && !is(T : typeof(null))
    && !is(T == struct) && !is(T == class) && !is(T == union))
{
    if(__ctfe)
    {
        if(val is null)
        {
            return hashOf(cast(size_t)0, seed);
        }
        else
        {
            assert(0, "Unable to calculate hash of non-null pointer at compile time");
        }

    }
    return hashOf(cast(size_t)val, seed);
}

private enum _hashOfStruct =
q{
    static if (hasCallableToHash!T) //CTFE depends on toHash()
    {
        return hashOf(cast(size_t) val.toHash(), seed);
    }
    else static if (T.tupleof.length == 1)
    {
        return hashOf(val.tupleof[0], seed);
    }
    else
    {
        static if(__traits(hasMember, T, "toHash") && is(typeof(T.toHash) == function))
        {
            pragma(msg, "Warning: struct "~__traits(identifier, T)~" has method toHash, however it cannot be called with "~T.stringof~" this.");
        }

        static if (is(T == struct) && !canBitwiseHash!T)
        {
            static foreach (i, F; typeof(val.tupleof))
            {
                seed = hashOf(val.tupleof[i], seed);
            }
            return seed;
        }
        else static if (is(typeof(toUbyte(val)) == const(ubyte)[]))//CTFE ready for structs without reference fields
        {
            return bytesHashAlignedBy!T(toUbyte(val), seed);
        }
        else // CTFE unsupported
        {
            assert(!__ctfe, "unable to compute hash of "~T.stringof);
            const(ubyte)[] bytes = (() @trusted => (cast(const(ubyte)*)&val)[0 .. T.sizeof])();
            return bytesHashAlignedBy!T(bytes, seed);
        }
    }
};

//struct or union hash
size_t hashOf(T)(scope const auto ref T val, size_t seed = 0)
if (!is(T == enum) && (is(T == struct) || is(T == union))
    && canBitwiseHash!T)
{
    mixin(_hashOfStruct);
}

//struct or union hash
size_t hashOf(T)(auto ref T val, size_t seed = 0)
if (!is(T == enum) && (is(T == struct) || is(T == union))
    && !canBitwiseHash!T)
{
    mixin(_hashOfStruct);
}

nothrow pure @safe unittest // issue 18925
{
    // Check hashOf struct of scalar fields is usable in @safe code.
    static struct S { int a; int b; }
    auto h = hashOf(S.init);
}

nothrow pure @safe unittest // issue 19005
{
    enum Month : ubyte
    {
        jan = 1
    }
    static struct Date
    {
        short _year;
        Month _month;
        ubyte _day;
    }
    Date date;
    auto hash = date.hashOf;
}

//delegate hash. CTFE unsupported
@trusted @nogc nothrow pure
size_t hashOf(T)(scope const T val, size_t seed = 0) if (!is(T == enum) && is(T == delegate))
{
    assert(!__ctfe, "unable to compute hash of "~T.stringof);
    const(ubyte)[] bytes = (cast(const(ubyte)*)&val)[0 .. T.sizeof];
    return bytesHashAlignedBy!T(bytes, seed);
}

//class or interface hash. CTFE depends on toHash
size_t hashOf(T)(scope const T val, size_t seed = 0)
if (!is(T == enum) && (is(T == interface) || is(T == class))
    && isFinalClassWithAddressBasedHash!T)
{
    return hashOf(cast(const void*) val, seed);
}

//class or interface hash. CTFE depends on toHash
size_t hashOf(T)(T val, size_t seed = 0)
if (!is(T == enum) && (is(T == interface) || is(T == class))
    && !isFinalClassWithAddressBasedHash!T)
{
    static if (__traits(compiles, {size_t h = val.toHash();}))
        return hashOf(val ? cast(size_t) val.toHash() : size_t(0), seed);
    else
        return hashOf(val ? (cast(Object)val).toHash() : 0, seed);
}

//associative array hash. CTFE depends on base types
size_t hashOf(T)(T aa, size_t seed = 0) if (!is(T == enum) && __traits(isAssociativeArray, T))
{
    if (!aa.length) return hashOf(0, seed);
    size_t h = 0;

    // The computed hash is independent of the foreach traversal order.
    foreach (key, ref val; aa)
    {
        size_t[2] hpair;
        hpair[0] = key.hashOf();
        hpair[1] = val.hashOf();
        h += hpair.hashOf();
    }
    return h.hashOf(seed);
}

unittest
{
    static struct Foo
    {
        int a = 99;
        float b = 4.0;
        size_t toHash() const pure @safe nothrow
        {
            return a;
        }
    }

    static struct Bar
    {
        char c = 'x';
        int a = 99;
        float b = 4.0;
        void* d = null;
    }

    static struct Boom
    {
        char c = 'M';
        int* a = null;
    }

    static struct Plain
    {
        int a = 1;
        int b = 2;
    }

    interface IBoo
    {
        void boo();
    }

    static class Boo: IBoo
    {
        override void boo()
        {
        }

        override size_t toHash()
        {
            return 1;
        }
    }

    static struct Goo
    {
        size_t toHash() pure @safe nothrow
        {
            return 1;
        }
    }

    enum Gun: long
    {
        A = 99,
        B = 17
    }

    enum double dexpr = 3.14;
    enum float fexpr = 2.71;
    enum wstring wsexpr = "abcdef"w;
    enum string csexpr = "abcdef";
    enum int iexpr = 7;
    enum long lexpr = 42;
    enum int[2][3] saexpr = [[1, 2], [3, 4], [5, 6]];
    enum int[] daexpr = [7,8,9];
    enum Foo thsexpr = Foo();
    enum Bar vsexpr = Bar();
    enum int[int] aaexpr = [99:2, 12:6, 45:4];
    enum Gun eexpr = Gun.A;
    enum cdouble cexpr = 7+4i;
    enum Foo[] staexpr = [Foo(), Foo(), Foo()];
    enum Bar[] vsaexpr = [Bar(), Bar(), Bar()];
    enum realexpr = 7.88;
    enum raexpr = [8.99L+86i, 3.12L+99i, 5.66L+12i];
    enum nullexpr = null;
    enum plstr = Plain();
    enum plarrstr = [Plain(), Plain(), Plain()];
    //No CTFE:
    Boom rstructexpr = Boom();
    Boom[] rstrarrexpr = [Boom(), Boom(), Boom()];
    int delegate() dgexpr  = (){return 78;};
    void* ptrexpr = &dgexpr;


    //CTFE hashes
    enum h1 = dexpr.hashOf();
    enum h2 = fexpr.hashOf();
    enum h3 = wsexpr.hashOf();
    enum h4 = csexpr.hashOf();
    enum h5 = iexpr.hashOf();
    enum h6 = lexpr.hashOf();
    enum h7 = saexpr.hashOf();
    enum h8 = daexpr.hashOf();
    enum h9 = thsexpr.hashOf();
    enum h10 = vsexpr.hashOf();
    enum h11 = aaexpr.hashOf();
    enum h12 = eexpr.hashOf();
    enum h13 = cexpr.hashOf();
    enum h14 = hashOf(new Boo);
    enum h15 = staexpr.hashOf();
    enum h16 = hashOf([new Boo, new Boo, new Boo]);
    enum h17 = hashOf([cast(IBoo)new Boo, cast(IBoo)new Boo, cast(IBoo)new Boo]);
    enum h18 = hashOf(cast(IBoo)new Boo);
    enum h19 = vsaexpr.hashOf();
    enum h20 = hashOf(cast(Foo[3])staexpr);

    //BUG: cannot cast [Boo(), Boo(), Boo()][0] to object.Object at compile time
    auto h21 = hashOf(cast(Boo[3])[new Boo, new Boo, new Boo]);
    auto h22 = hashOf(cast(IBoo[3])[cast(IBoo)new Boo, cast(IBoo)new Boo, cast(IBoo)new Boo]);
    enum h23 = hashOf(cast(Bar[3])vsaexpr);

    //NO CTFE (Compute, but don't check correctness):
    auto h24 = rstructexpr.hashOf();
    auto h25 = rstrarrexpr.hashOf();
    auto h26 = dgexpr.hashOf();
    auto h27 = ptrexpr.hashOf();

    enum h28 = realexpr.hashOf();
    enum h29 = raexpr.hashOf();
    enum h30 = nullexpr.hashOf();
    enum h31 = plstr.hashOf();
    enum h32 = plarrstr.hashOf();
    enum h33 = hashOf(cast(Plain[3])plarrstr);

    auto v1 = dexpr;
    auto v2 = fexpr;
    auto v3 = wsexpr;
    auto v4 = csexpr;
    auto v5 = iexpr;
    auto v6 = lexpr;
    auto v7 = saexpr;
    auto v8 = daexpr;
    auto v9 = thsexpr;
    auto v10 = vsexpr;
    auto v11 = aaexpr;
    auto v12 = eexpr;
    auto v13 = cexpr;
    auto v14 = new Boo;
    auto v15 = staexpr;
    auto v16 = [new Boo, new Boo, new Boo];
    auto v17 = [cast(IBoo)new Boo, cast(IBoo)new Boo, cast(IBoo)new Boo];
    auto v18 = cast(IBoo)new Boo;
    auto v19 = vsaexpr;
    auto v20 = cast(Foo[3])staexpr;
    auto v21 = cast(Boo[3])[new Boo, new Boo, new Boo];
    auto v22 = cast(IBoo[3])[cast(IBoo)new Boo, cast(IBoo)new Boo, cast(IBoo)new Boo];
    auto v23 = cast(Bar[3])vsaexpr;
    auto v30 = null;
    auto v31 = plstr;
    auto v32 = plarrstr;
    auto v33 = cast(Plain[3])plarrstr;

    //NO CTFE:
    auto v24 = rstructexpr;
    auto v25 = rstrarrexpr;
    auto v26 = dgexpr;
    auto v27 = ptrexpr;
    auto v28 = realexpr;
    auto v29 = raexpr;

    //runtime hashes
    auto rth1 = hashOf(v1);
    auto rth2 = hashOf(v2);
    auto rth3 = hashOf(v3);
    auto rth4 = hashOf(v4);
    auto rth5 = hashOf(v5);
    auto rth6 = hashOf(v6);
    auto rth7 = hashOf(v7);
    auto rth8 = hashOf(v8);
    auto rth9 = hashOf(v9);
    auto rth10 = hashOf(v10);
    auto rth11 = hashOf(v11);
    auto rth12 = hashOf(v12);
    auto rth13 = hashOf(v13);
    auto rth14 = hashOf(v14);
    auto rth15 = hashOf(v15);
    auto rth16 = hashOf(v16);
    auto rth17 = hashOf(v17);
    auto rth18 = hashOf(v18);
    auto rth19 = hashOf(v19);
    auto rth20 = hashOf(v20);
    auto rth21 = hashOf(v21);
    auto rth22 = hashOf(v22);
    auto rth23 = hashOf(v23);
    auto rth30 = hashOf(v30);
    //NO CTFE:
    auto rth24 = hashOf(v24);
    auto rth25 = hashOf(v25);
    auto rth26 = hashOf(v26);
    auto rth27 = hashOf(v27);
    auto rth28 = hashOf(v28);
    auto rth29 = hashOf(v29);

    auto rth31 = hashOf(v31);
    auto rth32 = hashOf(v32);
    auto rth33 = hashOf(v33);

    assert(h1 == rth1);
    assert(h2 == rth2);
    assert(h3 == rth3);
    assert(h4 == rth4);
    assert(h5 == rth5);
    assert(h6 == rth6);
    assert(h7 == rth7);
    assert(h8 == rth8);
    assert(h9 == rth9);
    assert(h10 == rth10);
    assert(h11 == rth11);
    assert(h12 == rth12);
    assert(h13 == rth13);
    assert(h14 == rth14);
    assert(h15 == rth15);
    assert(h16 == rth16);
    assert(h17 == rth17);
    assert(h18 == rth18);
    assert(h19 == rth19);
    assert(h20 == rth20);
    assert(h21 == rth21);
    assert(h22 == rth22);
    assert(h23 == rth23);
    /*assert(h24 == rth24);
    assert(h25 == rth25);
    assert(h26 == rth26);
    assert(h27 == rth27);
    assert(h28 == rth28);
    assert(h29 == rth29);*/
    assert(h30 == rth30);
    assert(h31 == rth31);
    assert(h32 == rth32);
    assert(h33 == rth33);

    assert(hashOf(null, 0) != hashOf(null, 123456789)); // issue 18932

    static size_t tiHashOf(T)(T var)
    {
        return typeid(T).getHash(&var);
    }

    auto tih1 = tiHashOf(v1);
    auto tih2 = tiHashOf(v2);
    auto tih3 = tiHashOf(v3);
    auto tih4 = tiHashOf(v4);
    auto tih5 = tiHashOf(v5);
    auto tih6 = tiHashOf(v6);
    auto tih7 = tiHashOf(v7);
    auto tih8 = tiHashOf(v8);
    auto tih9 = tiHashOf(v9);
    auto tih10 = tiHashOf(v10);
    auto tih11 = tiHashOf(v11);
    auto tih12 = tiHashOf(v12);
    auto tih13 = tiHashOf(v13);
    auto tih14 = tiHashOf(v14);
    auto tih15 = tiHashOf(v15);
    auto tih16 = tiHashOf(v16);
    auto tih17 = tiHashOf(v17);
    auto tih18 = tiHashOf(v18);
    auto tih19 = tiHashOf(v19);
    auto tih20 = tiHashOf(v20);
    auto tih21 = tiHashOf(v21);
    auto tih22 = tiHashOf(v22);
    auto tih23 = tiHashOf(v23);
    auto tih24 = tiHashOf(v24);
    auto tih25 = tiHashOf(v25);
    auto tih26 = tiHashOf(v26);
    auto tih27 = tiHashOf(v27);
    auto tih28 = tiHashOf(v28);
    auto tih29 = tiHashOf(v29);
    auto tih30 = tiHashOf(v30);
    auto tih31 = tiHashOf(v31);
    auto tih32 = tiHashOf(v32);
    auto tih33 = tiHashOf(v33);

    assert(tih1 == rth1);
    assert(tih2 == rth2);
    assert(tih3 == rth3);
    assert(tih4 == rth4);
    assert(tih5 == rth5);
    assert(tih6 == rth6);
    assert(tih7 == rth7);
    assert(tih8 == rth8);
    assert(tih9 == rth9);
    //assert(tih10 == rth10); // need compiler-generated __xtoHash changes
    assert(tih11 == rth11);
    assert(tih12 == rth12);
    assert(tih13 == rth13);
    assert(tih14 == rth14);
    assert(tih15 == rth15);
    assert(tih16 == rth16);
    assert(tih17 == rth17);
    assert(tih18 == rth18);
    //assert(tih19 == rth19); // need compiler-generated __xtoHash changes
    assert(tih20 == rth20);
    assert(tih21 == rth21);
    assert(tih22 == rth22);
    //assert(tih23 == rth23); // need compiler-generated __xtoHash changes
    //assert(tih24 == rth24);
    //assert(tih25 == rth25);
    assert(tih26 == rth26);
    assert(tih27 == rth27);
    assert(tih28 == rth28);
    assert(tih29 == rth29);
    assert(tih30 == rth30);
    assert(tih31 == rth31);
    assert(tih32 == rth32);
    assert(tih33 == rth33);
}


unittest // issue 15111
{
    void testAlias(T)()
    {
        static struct Foo
        {
            T t;
            alias t this;
        }
        Foo foo;
        static assert(is(typeof(hashOf(foo))));
    }
    // was fixed
    testAlias!(int[]);
    testAlias!(int*);
    // was not affected
    testAlias!int;
    testAlias!(void delegate());
    testAlias!(string[string]);
    testAlias!(int[8]);
}

nothrow pure @system unittest // issue 18918
{
    static struct S { string array; }
    auto s1 = S("abc");
    auto s2 = S(s1.array.idup);
    assert(hashOf(s1) == hashOf(s2));
    enum e = hashOf(S("abc"));
    assert(hashOf(s1) == e);
}

// MurmurHash3 was written by Austin Appleby, and is placed in the public
// domain. The author hereby disclaims copyright to this source code.

// This overload is for backwards compatibility.
@system pure nothrow @nogc
size_t bytesHash()(scope const(void)* buf, size_t len, size_t seed)
{
    return bytesHashAlignedBy!ubyte((cast(const(ubyte)*) buf)[0 .. len], seed);
}

private template bytesHashAlignedBy(AlignType)
{
    alias bytesHashAlignedBy = bytesHash!(AlignType.alignof >= uint.alignof);
}

//-----------------------------------------------------------------------------
// Block read - if your platform needs to do endian-swapping or can only
// handle aligned reads, do the conversion here
private uint get32bits()(scope const(ubyte)* x) @nogc nothrow pure @system
{
    version(BigEndian)
    {
        return ((cast(uint) x[0]) << 24) | ((cast(uint) x[1]) << 16) | ((cast(uint) x[2]) << 8) | (cast(uint) x[3]);
    }
    else
    {
        return ((cast(uint) x[3]) << 24) | ((cast(uint) x[2]) << 16) | ((cast(uint) x[1]) << 8) | (cast(uint) x[0]);
    }
}

/+
Params:
    dataKnownToBeAligned = whether the data is known at compile time to be uint-aligned.
+/
@nogc nothrow pure @trusted
private size_t bytesHash(bool dataKnownToBeAligned)(scope const(ubyte)[] bytes, size_t seed)
{
    auto len = bytes.length;
    auto data = bytes.ptr;
    auto nblocks = len / 4;

    uint h1 = cast(uint)seed;

    enum uint c1 = 0xcc9e2d51;
    enum uint c2 = 0x1b873593;
    enum uint c3 = 0xe6546b64;

    //----------
    // body
    auto end_data = data+nblocks*uint.sizeof;
    for(; data!=end_data; data += uint.sizeof)
    {
        static if (dataKnownToBeAligned)
            uint k1 = __ctfe ? get32bits(data) : *(cast(const uint*) data);
        else
            uint k1 = get32bits(data);
        k1 *= c1;
        k1 = (k1 << 15) | (k1 >> (32 - 15));
        k1 *= c2;

        h1 ^= k1;
        h1 = (h1 << 13) | (h1 >> (32 - 13));
        h1 = h1*5+c3;
    }

    //----------
    // tail
    uint k1 = 0;

    switch(len & 3)
    {
        case 3: k1 ^= data[2] << 16; goto case;
        case 2: k1 ^= data[1] << 8;  goto case;
        case 1: k1 ^= data[0];
                k1 *= c1; k1 = (k1 << 15) | (k1 >> (32 - 15)); k1 *= c2; h1 ^= k1;
                goto default;
        default:
    }

    //----------
    // finalization
    h1 ^= len;
    // Force all bits of the hash block to avalanche.
    h1 = (h1 ^ (h1 >> 16)) * 0x85ebca6b;
    h1 = (h1 ^ (h1 >> 13)) * 0xc2b2ae35;
    h1 ^= h1 >> 16;
    return h1;
}

//  Check that bytesHash works with CTFE
pure nothrow @system @nogc unittest
{
    size_t ctfeHash(string x)
    {
        return bytesHash(x.ptr, x.length, 0);
    }

    enum test_str = "Sample string";
    enum size_t hashVal = ctfeHash(test_str);
    assert(hashVal == bytesHash(&test_str[0], test_str.length, 0));

    // Detect unintended changes to bytesHash on unaligned and aligned inputs.
    version(BigEndian)
    {
        const ubyte[7] a = [99, 4, 3, 2, 1, 5, 88];
        const uint[2] b = [0x01_02_03_04, 0x05_ff_ff_ff];
    }
    else
    {
        const ubyte[7] a = [99, 1, 2, 3, 4, 5, 88];
        const uint[2] b = [0x04_03_02_01, 0xff_ff_ff_05];
    }
    // It is okay to change the below values if you make a change
    // that you expect to change the result of bytesHash.
    assert(bytesHash(&a[1], a.length - 2, 0) == 2727459272);
    assert(bytesHash(&b, 5, 0) == 2727459272);
    assert(bytesHashAlignedBy!uint((cast(const ubyte*) &b)[0 .. 5], 0) == 2727459272);
}
