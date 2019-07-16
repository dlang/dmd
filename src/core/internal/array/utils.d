/**
 This module contains utility functions to help the implementation of the runtime hook

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/internal/_array/_utils.d)
*/
module core.internal.array.utils;

import core.internal.traits : Parameters;

private auto gcStatsPure() nothrow pure
{
    import core.memory : GC;

    auto impureBypass = cast(GC.Stats function() pure nothrow)&GC.stats;
    return impureBypass();
}

private ulong accumulatePure(string file, int line, string funcname, string name, ulong size) nothrow pure
{
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

/**
 * TraceGC wrapper around runtime hook `Hook`.
 * Params:
 *  T = Type of hook to report to accumulate
 *  Hook = The hook to wrap
 *  errorMessage = The error message incase `version != D_TypeInfo`
 *  file = File that called `HookTraceImpl`
 *  line = Line inside of `file` that called `HookTraceImpl`
 *  funcname = Function that called `HookTraceImpl`
 *  parameters = Parameters that will be used to call `Hook`
 * Bugs:
 *  This function template was ported from a much older runtime hook that bypassed safety,
 *  purity, and throwabilty checks. To prevent breaking existing code, this function template
 *  is temporarily declared `@trusted pure nothrow` until the implementation can be brought up to modern D expectations.
*/
auto HookTraceImpl(T, alias Hook, string errorMessage)(string file, int line, string funcname, Parameters!Hook parameters) @trusted pure nothrow
{
    version (D_TypeInfo)
    {
        pragma(inline, false);
        string name = T.stringof;

        // FIXME: use rt.tracegc.accumulator when it is accessable in the future.
        version (tracegc)
        {
            import core.stdc.stdio;

            printf("%sTrace file = '%.*s' line = %d function = '%.*s' type = %.*s\n",
                Hook.stringof.ptr,
                file.length, file.ptr,
                line,
                funcname.length, funcname.ptr,
                name.length, name.ptr
            );
        }

        ulong currentlyAllocated = gcStatsPure().allocatedInCurrentThread;

        scope(exit)
        {
            ulong size = gcStatsPure().allocatedInCurrentThread - currentlyAllocated;
            if (size > 0)
                if (!accumulatePure(file, line, funcname, name, size)) {
                    // This 'if' and 'assert' is needed to force the compiler to not remove the call to
                    // `accumulatePure`. It really want to do that while optimizing as the function is
                    // `pure` and it does not influence the result of this hook.

                    // `accumulatePure` returns the value of `size`, which can never be zero due to the
                    // previous 'if'. So this assert will never be triggered.
                    assert(0);
                }
        }
        return Hook(parameters);
    }
    else
        assert(0, errorMessage);
}

