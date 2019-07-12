/**
 This module contains support for controlling dynamic arrays' concatenation
  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC rt/_array/_concatenation.d)
*/
module rt.array.concatenation;

/// See $(REF _d_arraycatnTX, rt,lifetime)
private extern (C) void[] _d_arraycatnTX(const TypeInfo ti, byte[][] arrs) pure nothrow;

// This wrapper is needed because a externDFunc cannot be cast()ed directly.
private void accumulate(string file, uint line, string funcname, string type, ulong sz) @nogc
{
    import core.internal.traits : externDFunc;

    alias func = externDFunc!("rt.profilegc.accumulate", void function(string file, uint line, string funcname, string type, ulong sz) @nogc);
    return func(file, line, funcname, type, sz);
}

/// Implementation of `_d_arraycatnTX` and `_d_arraycatnTXTrace`
template _d_arraycatnTXImpl(Tarr : ResultArrT[], ResultArrT : T[], T)
{
    /**
    * Concatenating the arrays inside of `arrs`.
    * `_d_arraycatnTX([a, b, c])` means `a ~ b ~ c`.
    * Params:
    *  arrs = Array containing arrays that will be concatenated.
    * Returns:
    *  A newly allocated array that contains all the elements from all the arrays in `arrs`.
    * Bugs:
    *  This function template was ported from a much older runtime hook that bypassed safety,
    *  purity, and throwabilty checks. To prevent breaking existing code, this function template
    *  is temporarily declared `@trusted pure nothrow` until the implementation can be brought up to modern D expectations.
    */
    ResultArrT _d_arraycatnTX(scope const Tarr arrs) @trusted pure nothrow
    {
        pragma(inline, false);
        version (D_TypeInfo)
        {
            auto ti = typeid(ResultArrT);

            byte[][] arrs2 = (cast(byte[]*)arrs.ptr)[0 .. arrs.length];
            void[] result = ._d_arraycatnTX(ti, arrs2);
            return (cast(T*)result.ptr)[0 .. result.length];
        }
        else
            assert(0, "Cannot concatenate arrays if compiling without support for runtime type information!");
    }

    /**
    * TraceGC wrapper around $(REF _d_arraycatnTX, rt,array,concat).
    * Bugs:
    *  This function template was ported from a much older runtime hook that bypassed safety,
    *  purity, and throwabilty checks. To prevent breaking existing code, this function template
    *  is temporarily declared `@trusted pure nothrow` until the implementation can be brought up to modern D expectations.
    */
    ResultArrT _d_arraycatnTXTrace(string file, int line, string funcname, scope const Tarr arrs) @trusted pure nothrow
    {
        pragma(inline, false);
        version (D_TypeInfo)
        {
            import core.memory : GC;
            auto accumulate = cast(void function(string file, uint line, string funcname, string type, ulong sz) @nogc nothrow pure)&accumulate;
            auto gcStats = cast(GC.Stats function() nothrow pure)&GC.stats;

            string name = ResultArrT.stringof;

            // FIXME: use rt.tracegc.accumulator when it is accessable in the future.
            version (tracegc)
            {
                import core.stdc.stdio;

                printf("%s file = '%.*s' line = %d function = '%.*s' type = %.*s\n",
                    __FUNCTION__.ptr,
                    file.length, file.ptr,
                    line,
                    funcname.length, funcname.ptr,
                    name.length, name.ptr
                );
            }

            ulong currentlyAllocated = gcStats().allocatedInCurrentThread;

            scope(exit)
            {
                ulong size = gcStats().allocatedInCurrentThread - currentlyAllocated;
                if (size > 0)
                    accumulate(file, line, funcname, name, size);
            }
            return _d_arraycatnTX(arrs);
        }
        else
            assert(0, "Cannot concatenate arrays if compiling without support for runtime type information!");
    }
}

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

    S[][] arr = [[S(0), S(1), S(2), S(3)], [S(4), S(5), S(6), S(7)]];
    S[] result = _d_arraycatnTXImpl!(typeof(arr))._d_arraycatnTX(arr);

    assert(counter == 8);
    assert(result == [S(0), S(1), S(2), S(3), S(4), S(5), S(6), S(7)]);
}
