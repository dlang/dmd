/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     Stefan Koch
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/trace.d, _trace.d)
 * Documentation:  https://dlang.org/phobos/dmd_trace.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/trace.d
 */

module dmd.trace;
import dmd.dsymbol;

enum SYMBOL_TRACE = true;

struct SymbolProfileEntry
{
    Dsymbol sym;
    ulong begin_ticks;
    ulong end_ticks;

    ulong begin_mem;
    ulong end_mem;

    string kind;
    string fn;
}

extern (C) __gshared uint dsymbol_profile_array_count;
extern (C) __gshared SymbolProfileEntry* dsymbol_profile_array;
enum dsymbol_profile_array_size = ushort.max * 512; // 32 million entries should do, no ?
static this()
{
    static if (SYMBOL_TRACE)
    {
        enum alloc_size = dsymbol_profile_array_size * SymbolProfileEntry.sizeof;
        import core.stdc.stdlib : malloc;
        if(!dsymbol_profile_array)
        {
            dsymbol_profile_array = cast(SymbolProfileEntry*)
                malloc(alloc_size);
        }
        assert(dsymbol_profile_array, "cannot allocate space form dsymbol_profile_array");
    }
}
string traceString(string vname, string fn = null) {
static if (SYMBOL_TRACE)
return q{
    import queryperf : QueryPerformanceCounter;
    import dmd.root.rmem : allocated;
    ulong begin_sema_ticks;
    ulong end_sema_ticks;
    ulong begin_sema_mem = allocated;
    auto insert_pos = dsymbol_profile_array_count++;
    assert(dsymbol_profile_array_count < dsymbol_profile_array_size,
        "Trying to push more then" ~ dsymbol_profile_array_size.stringof ~ " symbols");
    QueryPerformanceCounter(&begin_sema_ticks);
} ~
`
    scope(exit)
    {
        QueryPerformanceCounter(&end_sema_ticks);
        dsymbol_profile_array[insert_pos] =
            SymbolProfileEntry(`~ vname ~ `,
        begin_sema_ticks, end_sema_ticks,
        begin_sema_mem, allocated,
        typeof(` ~ vname ~ `).stringof, ` ~ (fn ? `"`~fn~`"` : "__FUNCTION__") ~ `);
    }
`;
else
return "";
}
