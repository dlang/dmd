/**
 * Contains implementations of functions called when the
 *   -profile=gc
 * switch is thrown.
 *
 * Tests for this functionality can be found in test/profile/src/profilegc.d
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright
 * Source: $(DRUNTIMESRC rt/_tracegc.d)
 */

module rt.tracegc;

extern (C) void _d_callfinalizer(void* p);
extern (C) void _d_callinterfacefinalizer(void* p);
extern (C) void _d_delclass(Object* p);
extern (C) void _d_delinterface(void** p);
extern (C) void _d_delmemory(void** p);
extern (C) void[] _d_arrayappendcd(ref byte[] x, dchar c);
extern (C) void[] _d_arrayappendwd(ref byte[] x, dchar c);
extern (C) void* _d_allocmemory(size_t sz);

// From GC.BlkInfo_. We cannot import it from core.memory.GC because .stringof
// replaces the alias with the private symbol that's not visible from this
// module, causing a compile error.
private struct BlkInfo
{
    void* base;
    size_t size;
    uint attr;
}

extern (C) void* gc_malloc(size_t sz, uint ba = 0, const scope TypeInfo ti = null);
extern (C) BlkInfo gc_qalloc(size_t sz, uint ba = 0, const scope TypeInfo ti = null);
extern (C) void* gc_calloc(size_t sz, uint ba = 0, const TypeInfo ti = null);
extern (C) void* gc_realloc(return scope void* p, size_t sz, uint ba = 0, const TypeInfo ti = null);
extern (C) size_t gc_extend(void* p, size_t mx, size_t sz, const TypeInfo ti = null);

private void accumulate2(string file, int line, string funcname, string name, ulong currentlyAllocated)
{
    auto size = GC.allocatedInCurrentThread - currentlyAllocated;
    if (size > 0 && strstr(funcname.ptr, "core.internal") is null)
        accumulate(file, line, funcname, name, size);
}

import rt.profilegc : accumulate;
import core.memory : GC;
import core.stdc.string : strstr;

extern (C) void _d_callfinalizerTrace(string file, int line, string funcname, void* p)
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, null, currentlyAllocated);

    return _d_callfinalizer(p);
}

extern (C) void _d_callinterfacefinalizerTrace(string file, int line, string funcname, void* p)
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, null, currentlyAllocated);

    return _d_callinterfacefinalizer(p);
}

extern (C) void _d_delclassTrace(string file, int line, string funcname, Object* p)
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, null, currentlyAllocated);

    return _d_delclass(p);
}

extern (C) void _d_delinterfaceTrace(string file, int line, string funcname, void** p)
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, null, currentlyAllocated);

    return _d_delinterface(p);
}

extern (C) void _d_delmemoryTrace(string file, int line, string funcname, void** p)
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, null, currentlyAllocated);

    return _d_delmemory(p);
}

extern (C) void[] _d_arrayappendcdTrace(string file, int line, string funcname, ref byte[] x, dchar c)
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, "char[]", currentlyAllocated);

    return _d_arrayappendcd(x, c);
}

extern (C) void[] _d_arrayappendwdTrace(string file, int line, string funcname, ref byte[] x, dchar c)
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, "wchar[]", currentlyAllocated);

    return _d_arrayappendwd(x, c);
}

extern (C) void* _d_allocmemoryTrace(string file, int line, string funcname, size_t sz)
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, "closure", currentlyAllocated);

    return _d_allocmemory(sz);
}

extern (C) void* gc_mallocTrace(size_t sz, uint ba = 0, scope const(TypeInfo) ti = null,
    string file = "", int line = 0, string funcname = "")
{
    auto name = ti ? ti.toString() : "void[]";

    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, name, currentlyAllocated);

    return gc_malloc(sz, ba, ti);
}

private string nameFromTypeInfo(const(TypeInfo) ti)
{
    return ti ? ti.toString() : "void[]";
}

extern (C) BlkInfo gc_qallocTrace(size_t sz, uint ba = 0, scope const(TypeInfo) ti = null,
    string file = "", int line = 0, string funcname = "")
{

    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, nameFromTypeInfo(ti), currentlyAllocated);

    return gc_qalloc(sz, ba, ti);
}

extern (C) void* gc_callocTrace(size_t sz, uint ba = 0, const(TypeInfo) ti = null,
    string file = "", int line = 0, string funcname = "")
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, nameFromTypeInfo(ti), currentlyAllocated);

    return gc_calloc(sz, ba, ti);
}

extern (C) void* gc_reallocTrace(return scope void* p, size_t sz, uint ba = 0,
    const(TypeInfo) ti = null, string file = "", int line = 0, string funcname = "")
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, nameFromTypeInfo(ti), currentlyAllocated);

    return gc_realloc(p, sz, ba, ti);
}

extern (C) size_t gc_extendTrace(void* p, size_t mx, size_t sz,
    const(TypeInfo) ti = null, string file = "", int line = 0, string funcname = "")
{
    const currentlyAllocated = GC.allocatedInCurrentThread;
    scope (exit)
        accumulate2(file, line, funcname, nameFromTypeInfo(ti), currentlyAllocated);

    return gc_extend(p, mx, sz, ti);
}
