/**
 This module contains support for controlling dynamic arrays' concatenation
  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/internal/_array/_concatenation.d)
*/
module core.internal.array.concatenation;

/**
 * Concatenate the arrays inside of `froms`.
 * `_d_arraycatnTX(a, b, c)` means `a ~ b ~ c`.
 *
 * Params:
 *      froms = Arrays to be concatenated.
 * Returns:
 *      A newly allocated array that contains all the elements from `froms`.
 */
Tret _d_arraycatnTX(Tret, Tarr...)(auto ref Tarr froms) @trusted
{
    import core.exception : onOutOfMemoryError;
    import core.internal.array.utils : __arrayAlloc;
    import core.internal.traits : hasElaborateCopyConstructor, Unqual;
    import core.lifetime : copyEmplace;
    import core.stdc.string : memcpy;

    Tret res;
    size_t totalLen;

    alias T = typeof(res[0]); // Element type of the result array
    alias UnqT = Unqual!T;    // Unqualified version of T (strips const/immutable)
    enum elemSize = T.sizeof; // Size of each element
    enum hasPostblit = __traits(hasPostblit, T); // Whether T has a postblit constructor

    // Compute total length of the resulting array
    static foreach (from; froms)
        static if (is(typeof(from) : T))
            totalLen++; // Single element contributes one to length
        else
            totalLen += from.length; // Arrays contribute their full length

    if (totalLen == 0)
        return res; // Return an empty array if no elements are present

    // Allocate memory for mutable arrays using __arrayAlloc
    res = cast(Tret) __arrayAlloc!(UnqT)(elemSize * totalLen);

    if (res.ptr is null)
        onOutOfMemoryError(); // Abort if allocation fails

    static if (hasElaborateCopyConstructor!T && !hasPostblit)
    {
        size_t i = 0;
        foreach (ref from; froms)
            static if (is(typeof(from) : T))
                copyEmplace(cast(T) from, res[i++]);
            else
            {
                if (from.length)
                    foreach (ref elem; from)
                        copyEmplace(cast(T) elem, res[i++]);
            }
    }
    else
    {
        auto resptr = cast(UnqT *) res;
        foreach (ref from; froms)
            static if (is (typeof(from) : T))
                memcpy(resptr++, cast(UnqT *) &from, elemSize);
            else
            {
                const len = from.length;
                if (len)
                {
                    memcpy(resptr, cast(UnqT *) from, len * elemSize);
                    resptr += len;
                }
            }

        static if (hasPostblit)
            foreach (ref elem; res)
                (cast() elem).__xpostblit();
    }

    return res;
}

// postblit
@safe unittest
{
    int counter;
    struct S
    {
        int val;
        this(this)
        {
            counter++;
        }
    }

    S[] arr1 = [S(0), S(1), S(2)];
    S[] arr2 = [];
    S[] arr3 = [S(6), S(7), S(8)];
    S elem = S(9);
    S[] result = _d_arraycatnTX!(S[])(arr1, arr2, arr3, elem);

    assert(counter == 7);
    assert(result == [S(0), S(1), S(2), S(6), S(7), S(8), S(9)]);
}

// copy constructor
@safe unittest
{
    int counter;
    struct S
    {
        int val;
        this(ref return scope S rhs)
        {
            val = rhs.val;
            counter++;
        }
    }

    S[] arr1 = [S(0), S(1), S(2)];
    S[] arr2 = [S(3), S(4), S(5)];
    S[] arr3 = [S(6), S(7), S(8)];
    S elem = S(9);
    S[] result = _d_arraycatnTX!(S[])(arr1, elem, arr2, arr3);

    assert(counter == 10);
    assert(result == [S(0), S(1), S(2), S(9), S(3), S(4), S(5), S(6), S(7), S(8)]);
}

// throwing
@safe unittest
{
    int counter;
    bool didThrow;
    struct S
    {
        int val;
        this(this)
        {
            counter++;
            if (counter == 4)
                throw new Exception("");
        }
    }

    try
    {
        S[] arr1 = [S(0), S(1), S(2)];
        S[] arr2 = [S(3), S(4), S(5)];
        _d_arraycatnTX!(S[])(arr1, arr2);
    }
    catch (Exception)
    {
        didThrow = true;
    }

    assert(counter == 4);
    assert(didThrow);
}

version (D_ProfileGC)
{
    /**
    * TraceGC wrapper around $(REF _d_arraycatnTX, core,internal,array,concatenation).
    */
    Tret _d_arraycatnTXTrace(Tret, Tarr...)(scope auto ref Tarr froms, string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
    {
        version (D_TypeInfo)
        {
            import core.internal.array.utils: TraceHook, gcStatsPure, accumulatePure;
            mixin(TraceHook!(Tarr.stringof, "_d_arraycatnTX"));

            import core.lifetime: forward;
            return _d_arraycatnTX!Tret(forward!froms);
        }
        else
            assert(0, "Cannot concatenate arrays if compiling without support for runtime type information!");
    }
}
