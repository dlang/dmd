/**
    This module contains support for controlling dynamic arrays' appending

     Copyright: Copyright Digital Mars 2000 - 2019.
     License: Distributed under the
             $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
        (See accompanying file LICENSE)
     Source: $(DRUNTIMESRC core/_internal/_array/_appending.d)
*/
module core.internal.array.appending;

import core.stdc.string;
import core.internal.array.construction; // For __arrayAlloc
import core.internal.array.utils;     // For __typeAttrs
import core.exception;           // For onOutOfMemoryError
import core.internal.traits;      // For Unqual
import core.memory; // For GC.malloc, gc_expandArrayUsed, gc_shrinkArrayUsed

/// See $(REF _d_arrayappendcTX, rt,lifetime,_d_arrayappendcTX)
/**
private extern (C) byte[] _d_arrayappendcTX(const TypeInfo ti, ref return scope byte[] px, size_t n) @trusted pure nothrow;
*/
private enum isCopyingNothrow(T) = __traits(compiles, (ref T rhs) nothrow { T lhs = rhs; });

/**
 * Extend an array `px` by `n` elements.
 * Caller must initialize those elements.
 * Params:
 * px = the array that will be extended, taken as a reference
 * n  = how many new elements to extend it with
 * Returns:
 * The new value of `px`
 */
ref Tarr _d_arrayappendcTX(Tarr : T[], T)(return ref scope Tarr px, size_t n)
    @trusted pure nothrow @nogc
{
    // Short circuit if no data is being appended.
    if (n == 0)
        return px;

    alias UnqT = Unqual!T;
    auto elemSize = UnqT.sizeof;
    auto length = px.length;
    auto newlength = length + n;
    auto newsize = newlength * elemSize;
    auto size = length * elemSize;
    auto isShared = (Tarr.flags & (1 << 1)) != 0; // Check for shared array.

    if (!gc_expandArrayUsed(px.ptr[0 .. size], newsize, isShared))
    {
        // Could not set the size, we must reallocate.
        auto newcap = newCapacity(newlength, elemSize);
        auto attrs = __typeAttrs(typeid(UnqT[]), px.ptr) | BlkAttr.APPENDABLE; // Use UnqT[]
        auto ptr = cast(byte*) GC.malloc(newcap, attrs, typeid(UnqT)); // Use UnqT
        if (ptr is null)
        {
            onOutOfMemoryError();
            assert(false);
        }

        if (newsize != newcap)
        {
            // For small blocks that are always fully scanned, if we allocated more
            // capacity than was requested, we are responsible for zeroing that
            // memory.
            if (!(attrs & BlkAttr.NO_SCAN) && newcap < core.memory.PAGESIZE)
                memset(ptr + newsize, 0, newcap - newsize);

            gc_shrinkArrayUsed(ptr[0 .. newsize], newcap, isShared);
        }

        memcpy(ptr, px.ptr, size);

        // do postblit processing.
        __doPostblit(ptr, size, typeid(UnqT)); // Use UnqT

        px = (cast(T*)ptr)[0 .. newlength];
        return px;
    }

    // we were able to expand in place, just update the length
    px = px.ptr[0 .. newlength];
    return px;
}
version (D_ProfileGC)
{
    /**
     * TraceGC wrapper around $(REF _d_arrayappendT, core,internal,array,appending).
     */
    ref Tarr _d_arrayappendcTXTrace(Tarr : T[], T)(return ref scope Tarr px, size_t n, string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
    {
        version (D_TypeInfo)
        {
            import core.internal.array.utils: TraceHook, gcStatsPure, accumulatePure;
            mixin(TraceHook!(Tarr.stringof, "_d_arrayappendcTX"));

            return _d_arrayappendcTX(px, n);
        }
        else
            static assert(0, "Cannot append to array if compiling without support for runtime type information!");
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
