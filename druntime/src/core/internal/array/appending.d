/**
 This module contains support for controlling dynamic arrays' appending

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/_internal/_array/_appending.d)
*/
module core.internal.array.appending;


private enum isCopyingNothrow(T) = __traits(compiles, (ref T rhs) nothrow { T lhs = rhs; });


/**
 * Extend an array `px` by `n` elements.
 * Caller must initialize those elements.
 *
 * This templated implementation avoids legacy runtime type information.
 * It allocates a new array using the local allocation helper (__arrayAlloc),
 * copies the old data using memcpy, and returns the new array.
 *
 * Params:
 *  px = the array that will be extended, taken as a reference
 *  n = how many new elements to extend it with
 * Returns:
 *  The new value of `px`
 */
ref Tarr _d_arrayappendcTX(Tarr : T[], T)(return ref scope Tarr px, size_t n) @trusted
{
    version (DigitalMars) pragma(inline, false);

    import core.stdc.string : memcpy;
    import core.internal.traits: Unqual;
    import core.internal.array.utils: __arrayAlloc;

    size_t oldLen = px.length;
    size_t newLen = oldLen + n;

    // Allocate a new array for the unqualified type, then cast back to T[]
    auto newArray = cast(T[])(__arrayAlloc!(Unqual!T)(newLen));

    // Copy existing data, if any.
    if(oldLen > 0)
    {
        // Cast pointers appropriately so that memcpy works with both mutable and immutable arrays.
        memcpy(cast(void*)newArray.ptr, cast(const void*)px.ptr, oldLen * T.sizeof);
    }

    return px;
}

version (D_ProfileGC)
{
    /**
     * TraceGC wrapper around _d_arrayappendcTX.
     */
    ref Tarr _d_arrayappendcTXTrace(Tarr : T[], T)(return ref scope Tarr px, size_t n,
        string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
    {
        import core.internal.array.utils: TraceHook, gcStatsPure, accumulatePure;
        mixin(TraceHook!(Tarr.stringof, "_d_arrayappendcTX"));

        return _d_arrayappendcTX(px, n);
    }
}
/// Implementation of `_d_arrayappendT`
ref Tarr _d_arrayappendT(Tarr : T[], T)(return ref scope Tarr x, scope Tarr y) @trusted
{
    version (DigitalMars) pragma(inline, false);

    import core.stdc.string : memcpy;
    import core.internal.traits : hasElaborateCopyConstructor, Unqual;

    enum hasPostblit = __traits(hasPostblit, T);
    auto length = x.length;

    _d_arrayappendcTX(x, y.length);

    // Only call `copyEmplace` if `T` has a copy ctor and no postblit.
    static if (hasElaborateCopyConstructor!T && !hasPostblit)
    {
        import core.lifetime : copyEmplace;

        foreach (i, ref elem; y)
            copyEmplace(elem, x[length + i]);
    }
    else
    {
        if (y.length)
        {
            // blit all elements at once
            auto xptr = cast(Unqual!T *)&x[length];
            immutable size = T.sizeof;

            memcpy(xptr, cast(Unqual!T *)&y[0], y.length * size);

            // call postblits if they exist
            static if (hasPostblit)
            {
                auto eptr = xptr + y.length;
                for (auto ptr = xptr; ptr < eptr; ptr++)
                    ptr.__xpostblit();
            }
        }
    }

    return x;
}

version (D_ProfileGC)
{
    /**
     * TraceGC wrapper around $(REF _d_arrayappendT, core,internal,array,appending).
     */
    ref Tarr _d_arrayappendTTrace(Tarr : T[], T)(return ref scope Tarr x, scope Tarr y, string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
    {
        version (D_TypeInfo)
        {
            import core.internal.array.utils: TraceHook, gcStatsPure, accumulatePure;
            mixin(TraceHook!(Tarr.stringof, "_d_arrayappendT"));

            return _d_arrayappendT(x, y);
        }
        else
            static assert(0, "Cannot append to array if compiling without support for runtime type information!");
    }
}

@safe unittest
{
    double[] arr1;
    foreach (i; 0 .. 4)
        _d_arrayappendT(arr1, [cast(double)i]);
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
    _d_arrayappendT(arr1, arr2);

    // postblit should have triggered on at least the items in arr2
    assert(blitted >= arr2.length);
}

@safe nothrow unittest
{
    int blitted;
    struct Item
    {
        this(this) nothrow
        {
            blitted++;
        }
    }

    Item[][] arr1 = [[Item()]];
    Item[][] arr2 = [[Item()]];

    _d_arrayappendT(arr1, arr2);

    // no postblit should have happened because arr{1,2} contain dynamic arrays
    assert(blitted == 0);
}

@safe nothrow unittest
{
    int copied;
    struct Item
    {
        this(const scope ref Item) nothrow
        {
            copied++;
        }
    }

    Item[1][] arr1 = [[Item()]];
    Item[1][] arr2 = [[Item()]];

    _d_arrayappendT(arr1, arr2);
    // copy constructor should have been invoked because arr{1,2} contain static arrays
    assert(copied >= arr2.length);
}

@safe nothrow unittest
{
    string str;
    _d_arrayappendT(str, "a");
    _d_arrayappendT(str, "b");
    _d_arrayappendT(str, "c");
    assert(str == "abc");
}