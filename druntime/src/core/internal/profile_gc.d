/**
 * GC profiling wrappers for runtime hooks, used when compiling with -profile=gc.
 *
 * The compiler lowers GC-allocating operations to the hooks in $(REF object).
 * Under `version (D_ProfileGC)`, $(REF object) re-exports these wrappers instead
 * of the originals.  Each wrapper records the bytes allocated by the inner call
 * via `rt.profilegc.accumulate`.
 *
 * The functions are given the same names as the originals so that the compiler
 * does not need to know which variant it is calling.
 *
 * Copyright: Copyright Digital Mars 2000 - 2024.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Source: $(DRUNTIMESRC core/internal/profile_gc.d)
 */
module core.internal.profile_gc;

static import core.internal.array.appending;
static import core.internal.array.concatenation;
static import core.internal.array.construction;
static import core.internal.array.capacity;
static import core.lifetime;

private auto gcStatsPure() nothrow pure
{
    import core.memory : GC;
    auto impureBypass = cast(GC.Stats function() pure nothrow)&GC.stats;
    return impureBypass();
}

private ulong accumulatePure(string file, int line, string funcname, string name, ulong currentlyAllocated) nothrow pure
{
    const size = gcStatsPure().allocatedInCurrentThread - currentlyAllocated;

    if (size == 0)
        return 0;


    static ulong impureBypass(string file, int line, string funcname, string name, ulong size) @nogc nothrow
    {
        import core.internal.traits : externDFunc;

        alias accumulate = externDFunc!("rt.profilegc.accumulate", void function(string file, uint line, string funcname, string type, ulong sz) @nogc nothrow);
        accumulate(file, line, funcname, name, size);
        return size;
    }

    auto func = cast(ulong function(string file, int line, string funcname, string name, ulong size) @nogc nothrow pure)&impureBypass;
    return func(file, line, funcname, name, size);
}

pragma(inline, false):

/**
 * TraceGC wrapper around runtime hook `Hook`.
 *
 * Params:
 *   T = Type of hook to report to accumulate
 *   Hook = The hook to wrap
 *   errorMessage = The error message incase `version != D_TypeInfo`
 *   file = File that called `_d_HookTraceImpl`
 *   line = Line inside of `file` that called `_d_HookTraceImpl`
 *   funcname = Function that called `_d_HookTraceImpl`
 *   parameters = Parameters that will be used to call `Hook`
 *
 * Bugs:
 *   This function template needs be between the compiler and a much older runtime hook that bypassed safety,
 *   purity, and throwabilty checks. To prevent breaking existing code, this function template
 *   is temporarily declared `@trusted pure` until the implementation can be brought up to modern D expectations.
*/
auto _d_HookTraceImpl(T, alias Hook, string errorMessage)(Parameters!Hook parameters, string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted pure
{
    version (D_TypeInfo)
    {
        const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
        scope(exit)
            accumulatePure(file, line, __traits(identifier, Hook), T.stringof, currentlyAllocated);

        return Hook(parameters);
    }
    else
        assert(0, errorMessage);
}

/// Profiling wrapper around $(REF _d_arrayappendcTX, core,internal,array,appending).
ref Tarr _d_arrayappendcTX(Tarr : T[], T)(return ref scope Tarr px, size_t n,
    string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
{
    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, Tarr.stringof, currentlyAllocated);

    return core.internal.array.appending._d_arrayappendcTX(px, n);
}

/// Profiling wrapper around $(REF _d_arrayappendT, core,internal,array,appending).
ref Tarr _d_arrayappendT(Tarr : T[], T)(return ref scope Tarr x, scope Tarr y,
    string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
{
    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, Tarr.stringof, currentlyAllocated);

    return core.internal.array.appending._d_arrayappendT(x, y);
}

/// Profiling wrapper around $(REF _d_arraycatnTX, core,internal,array,concatenation).
Tret _d_arraycatnTX(Tret, Tarr...)(scope auto ref Tarr froms,
    string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
{
    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, Tarr.stringof, currentlyAllocated);

    import core.lifetime : forward;
    return core.internal.array.concatenation._d_arraycatnTX!Tret(forward!froms);
}

/// Profiling wrapper around $(REF _d_newitemT, core,lifetime).
T* _d_newitemT(T)(string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
{
    static if (is(T == struct))
    {
        // Prime the TypeInfo name so it does not affect the allocated byte count.
        // See https://github.com/dlang/dmd/issues/20832
        static string typeName(TypeInfo_Struct ti) nothrow @trusted => ti.name;
        auto tnPure = cast(string function(TypeInfo_Struct ti) nothrow pure @trusted)&typeName;
        cast(void)tnPure(typeid(T));
    }

    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, T.stringof, currentlyAllocated);

    return core.lifetime._d_newitemT!T();
}

/// Profiling wrapper around $(REF _d_newarrayT, core,internal,array,construction).
T[] _d_newarrayT(T)(size_t length, bool isShared,
    string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
{
    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, T.stringof, currentlyAllocated);

    return core.internal.array.construction._d_newarrayT!T(length, isShared);
}

/// Profiling wrapper around $(REF _d_newarrayU, core,internal,array,construction).
T[] _d_newarrayU(T)(size_t length, bool isShared,
    string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
{
    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, T.stringof, currentlyAllocated);

    return core.internal.array.construction._d_newarrayU!T(length, isShared);
}

/// Profiling wrapper around $(REF _d_newarraymTX, core,internal,array,construction).
Tarr _d_newarraymTX(Tarr : U[], T, U)(scope size_t[] dims, bool isShared = false,
    string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
{
    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, T.stringof, currentlyAllocated);

    return core.internal.array.construction._d_newarraymTX!(Tarr, T)(dims, isShared);
}

/// Profiling wrapper around $(REF _d_arraysetlengthT, core,internal,array,capacity).
size_t _d_arraysetlengthT(Tarr : T[], T)(return ref scope Tarr arr, size_t newlength,
    string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
{
    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, Tarr.stringof, currentlyAllocated);

    return core.internal.array.capacity._d_arraysetlengthT!Tarr(arr, newlength);
}

/// Profiling wrapper around $(REF _d_arrayliteralTX, core,internal,array,construction).
void* _d_arrayliteralTX(T)(size_t length,
    string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted pure nothrow
{
    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, (T[]).stringof, currentlyAllocated);

    return core.internal.array.construction._d_arrayliteralTX!T(length);
}

/// Profiling wrapper around $(REF _d_newclassT, core,lifetime).
T _d_newclassT(T)(string file = __FILE__, int line = __LINE__, string funcname = __FUNCTION__) @trusted
{
    const currentlyAllocated = gcStatsPure().allocatedInCurrentThread;
    scope(exit)
        accumulatePure(file, line, funcname, T.stringof, currentlyAllocated);

    return core.lifetime._d_newclassT!T();
}
