/**
 * Libunwind-based implementation of `TraceInfo`
 *
 * This module exposes an handler that uses libunwind to print stack traces.
 * It is used when druntime is packaged with `DRuntime_Use_Libunwind` or when
 * the user uses the following in `main`:
 * ---
 * import core.runtime;
 * import core.internal.backtrace.handler;
 * Runtime.traceHandler = &libunwindDefaultTraceHandler;
 * ---
 *
 * Authors: Mathias 'Geod24' Lang
 * Copyright: D Language Foundation - 2020
 * See_Also: https://www.nongnu.org/libunwind/man/libunwind(3).html
 */
module core.internal.backtrace.handler;

version (DRuntime_Use_Libunwind):

import core.internal.backtrace.dwarf;
import core.internal.backtrace.libunwind;

/// Ditto
class LibunwindHandler : Throwable.TraceInfo
{
    private static struct FrameInfo
    {
        char[1024] buff = void;

        const(char)[] name;
        const(void)* address;
    }

    size_t numframes;
    enum MAXFRAMES = 128;
    FrameInfo[MAXFRAMES] callstack = void;

    /**
     * Create a new instance of this trace handler saving the current context
     *
     * Params:
     *   frames_to_skip = The number of frames leading to this one.
     *                    Defaults to 1. Note that the opApply will not
     *                    show any frames that appear before _d_throwdwarf.
     */
    public this (size_t frames_to_skip = 1) nothrow @nogc
    {
        import core.stdc.string : strlen;

        static assert(typeof(FrameInfo.address).sizeof == unw_word_t.sizeof,
                      "Mismatch in type size for call to unw_get_proc_name");

        unw_context_t context;
        unw_cursor_t cursor;
        unw_getcontext(&context);
        unw_init_local(&cursor, &context);

        while (frames_to_skip > 0 && unw_step(&cursor) > 0)
            --frames_to_skip;

        unw_proc_info_t pip = void;
        foreach (idx, ref frame; this.callstack)
        {
            if (int r = unw_get_proc_name(
                    &cursor, frame.buff.ptr, frame.buff.length,
                    cast(unw_word_t*) &frame.address))
                frame.name = "<ERROR: Unable to retrieve function name>";
            else
                frame.name = frame.buff[0 .. strlen(frame.buff.ptr)];

            if (unw_get_proc_info(&cursor, &pip) == 0)
                frame.address += pip.start_ip;

            this.numframes++;
            if (unw_step(&cursor) <= 0)
                break;
        }
    }

    ///
    override int opApply (scope int delegate(ref const(char[])) dg) const
    {
        return this.opApply((ref size_t, ref const(char[]) buf) => dg(buf));
    }

    ///
    override int opApply (scope int delegate(ref size_t, ref const(char[])) dg) const
    {
        return traceHandlerOpApplyImpl(numframes,
            i => callstack[i].address,
            i => callstack[i].name,
            dg);
    }

    ///
    override string toString () const
    {
        string buf;
        foreach ( i, line; this )
            buf ~= i ? "\n" ~ line : line;
        return buf;
    }
}

/**
 * Convenience function for power users wishing to test this module
 * See `core.runtime.defaultTraceHandler` for full documentation.
 */
Throwable.TraceInfo defaultTraceHandler (void* ptr = null)
{
    // avoid recursive GC calls in finalizer, trace handlers should be made @nogc instead
    import core.memory : gc_inFinalizer;
    if (gc_inFinalizer)
        return null;

    return new LibunwindHandler();
}
