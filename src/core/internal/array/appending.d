/**
 This module contains support for controlling dynamic arrays' appending

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/_internal/_array/_appending.d)
*/
module core.internal.array.appending;

/// See $(REF _d_arrayappendcTX, rt,lifetime,_d_arrayappendcTX)
private extern (C) byte[] _d_arrayappendcTX(const TypeInfo ti, ref byte[] px, size_t n) @trusted pure nothrow;

/// Implementation of `_d_arrayappendcTX` and `_d_arrayappendcTXTrace`
template _d_arrayappendcTXImpl(Tarr : T[], T)
{
    import core.internal.array.utils : _d_HookTraceImpl, isPostblitNoThrow;

    private enum errorMessage = "Cannot append to array if compiling without support for runtime type information!";

    /**
     * Extend an array `px` by `n` elements.
     * Caller must initialize those elements.
     * Params:
     *  px = the array that will be extended, taken as a reference
     *  n = how many new elements to extend it with
     * Returns:
     *  The new value of `px`
     * Bugs:
    *   This function template was ported from a much older runtime hook that bypassed safety,
    *   purity, and throwabilty checks. To prevent breaking existing code, this function template
    *   is temporarily declared `@trusted pure` until the implementation can be brought up to modern D expectations.
     */
    static if (isPostblitNoThrow!T) // `nothrow` deduction doesn't work, so this is needed
        ref Tarr _d_arrayappendcTX(return scope ref Tarr px, size_t n) @trusted pure nothrow
        {
            pragma(inline, false);

            mixin(_d_arrayappendcTXBody);
        }
    else
        ref Tarr _d_arrayappendcTX(return scope ref Tarr px, size_t n) @trusted pure nothrow
        {
            pragma(inline, false);

            mixin(_d_arrayappendcTXBody);
        }

    private enum _d_arrayappendcTXBody = q{
        version (D_TypeInfo)
        {
            auto ti = typeid(Tarr);

            // _d_arrayappendcTX takes the `px` as a ref byte[], but its length
            // should still be the original length
            auto pxx = (cast(byte*)px.ptr)[0 .. px.length];
            ._d_arrayappendcTX(ti, pxx, n);
            px = (cast(T*)pxx.ptr)[0 .. pxx.length];

            return px;
        }
        else
            assert(0, "Cannot append arrays if compiling without support for runtime type information!");
    };

    /**
     * TraceGC wrapper around $(REF _d_arrayappendcTX, rt,array,appending,_d_arrayappendcTXImpl).
     * Bugs:
     *  This function template was ported from a much older runtime hook that bypassed safety,
     *  purity, and throwabilty checks. To prevent breaking existing code, this function template
     *  is temporarily declared `@trusted pure` until the implementation can be brought up to modern D expectations.
     */
    alias _d_arrayappendcTXTrace = _d_HookTraceImpl!(Tarr, _d_arrayappendcTX, errorMessage);
}

/// Implementation of `_d_arrayappendT` and `_d_arrayappendTTrace`
template _d_arrayappendTImpl(Tarr : T[], T)
{
    import core.internal.array.utils : _d_HookTraceImpl, isPostblitNoThrow;

    private enum errorMessage = "Cannot append to array if compiling without support for runtime type information!";

    /**
     * Append array `y` to array `x`.
     * Params:
     *  x = what array to append to, taken as a reference
     *  y = what should be appended
     * Returns:
     *  The new value of `x`
     * Bugs:
    *   This function template was ported from a much older runtime hook that bypassed safety,
    *   purity, and throwabilty checks. To prevent breaking existing code, this function template
    *   is temporarily declared `@trusted pure` until the implementation can be brought up to modern D expectations.
     */
    static if (isPostblitNoThrow!T)
        ref Tarr _d_arrayappendT(return scope ref Tarr x, scope Tarr y) @trusted pure nothrow
        {
            pragma(inline, false);

            mixin(_d_arrayappendTBody);
        }
    else
        ref Tarr _d_arrayappendT(return scope ref Tarr x, scope Tarr y) @trusted pure
        {
            pragma(inline, false);

            mixin(_d_arrayappendTBody);
        }

    private enum _d_arrayappendTBody = q{
        import core.stdc.string : memcpy;
        import core.internal.traits : Unqual;

        auto length = x.length;
        auto sizeelem = T.sizeof;

        _d_arrayappendcTXImpl!Tarr._d_arrayappendcTX(x, y.length);

        if (y.length)
            memcpy(cast(Unqual!T *)&x[length], cast(Unqual!T *)&y[0], y.length * sizeelem);

        // do postblit
        __doPostblit(cast(Unqual!Tarr)x[length .. length + y.length]);
        return x;
    };

    /**
     * TraceGC wrapper around $(REF _d_arrayappendT, rt,array,appending,_d_arrayappendTImpl).
     * Bugs:
     *  This function template was ported from a much older runtime hook that bypassed safety,
     *  purity, and throwabilty checks. To prevent breaking existing code, this function template
     *  is temporarily declared `@trusted pure` until the implementation can be brought up to modern D expectations.
     */
    alias _d_arrayappendTTrace = _d_HookTraceImpl!(Tarr, _d_arrayappendT, errorMessage);
}

/**
 * Run postblit on `t` if it is a struct and needs it.
 * Or if `t` is a array, run it on the children if they have a postblit.
 */
private void __doPostblit(T)(auto ref T t) @trusted pure
{
    import core.internal.traits : hasElaborateCopyConstructor;

    static if (is(T == struct))
    {
        // run the postblit function incase the struct has one
        static if (__traits(hasMember, T, "__xpostblit") &&
                // Bugzilla 14746: Check that it's the exact member of S.
                __traits(isSame, T, __traits(parent, t.__xpostblit)))
            t.__xpostblit();
    }
    else static if (is(T U : U[]) && hasElaborateCopyConstructor!U)
    {
        // only do a postblit if the `U` requires it.
        foreach (ref el; t)
            __doPostblit(el);
    }
}

@safe unittest
{
    double[] arr1;
    foreach (i; 0 .. 4)
        _d_arrayappendTImpl!(typeof(arr1))._d_arrayappendT(arr1, [cast(double)i]);
    assert(arr1 == [0.0, 1.0, 2.0, 3.0]);
}

@safe unittest
{
    int blitted;
    struct Item
    {
        this(this)
        {
            blitted++;
        }
    }

    Item[] arr1 = [Item(), Item()];
    Item[] arr2 = [Item(), Item()];
    Item[] arr1_org = [Item(), Item()];
    arr1_org ~= arr2;
    _d_arrayappendTImpl!(typeof(arr1))._d_arrayappendT(arr1, arr2);

    // postblit should have triggered on atleast the items in arr2
    assert(blitted >= arr2.length);
}

@safe unittest
{
    int blitted;
    struct Item
    {
        this(this)
        {
            blitted++;
        }
    }

    Item[][] arr1 = [[Item()]];
    Item[][] arr2 = [[Item()]];

    _d_arrayappendTImpl!(typeof(arr1))._d_arrayappendT(arr1, arr2);

    // no postblit should have happend because arr{1,2} contains dynamic arrays
    assert(blitted == 0);
}

@safe unittest
{
    int blitted;
    struct Item
    {
        this(this)
        {
            blitted++;
        }
    }

    Item[1][] arr1 = [[Item()]];
    Item[1][] arr2 = [[Item()]];

    _d_arrayappendTImpl!(typeof(arr1))._d_arrayappendT(arr1, arr2);
    // postblit should have happend because arr{1,2} contains static arrays
    assert(blitted >= arr2.length);
}

@safe unittest
{
    string str;
    _d_arrayappendTImpl!(typeof(str))._d_arrayappendT(str, "a");
    _d_arrayappendTImpl!(typeof(str))._d_arrayappendT(str, "b");
    _d_arrayappendTImpl!(typeof(str))._d_arrayappendT(str, "c");
    assert(str == "abc");
}
