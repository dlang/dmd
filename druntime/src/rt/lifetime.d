/**
 * This module contains all functions related to an object's lifetime:
 * allocation, resizing, deallocation, and finalization.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Steven Schveighoffer
 * Source: $(DRUNTIMESRC rt/_lifetime.d)
 */

module rt.lifetime;

import core.attribute : weak;
import core.checkedint : mulu;
import core.exception : onFinalizeError, onOutOfMemoryError, onUnicodeError;
import core.internal.gc.blockmeta : PAGESIZE;
import core.memory;
import core.stdc.stdlib : malloc;
import core.stdc.string : memcpy, memset;
static import rt.tlsgc;

debug (PRINTF) import core.stdc.stdio : printf;
debug (VALGRIND) import etc.valgrind.valgrind;

alias BlkAttr = GC.BlkAttr;

// for now, all GC array functions are not exposed via core.memory.
extern(C) {
    void[] gc_getArrayUsed(void *ptr, bool atomic) nothrow;
    bool gc_expandArrayUsed(void[] slice, size_t newUsed, bool atomic) nothrow;
    size_t gc_reserveArrayCapacity(void[] slice, size_t request, bool atomic) nothrow;
    bool gc_shrinkArrayUsed(void[] slice, size_t existingUsed, bool atomic) nothrow;
}

private
{
    alias bool function(Object) CollectHandler;
    __gshared CollectHandler collectHandler = null;

    extern (C) void _d_monitordelete(Object h, bool det);

}

// Now-removed symbol, kept around for ABI
// Some programs are dynamically linked, so best to err on the side of keeping symbols around for a while (especially extern(C) ones)
// https://github.com/dlang/druntime/pull/3361
deprecated extern (C) void lifetime_init()
{
}

/**
Allocate memory using the garbage collector

DMD uses this to allocate closures:
---
void f(byte[24] x)
{
    return () => x; // `x` is on stack, must be moved to heap to keep it alive
}
---

Params:
    sz = number of bytes to allocate

Returns: pointer to `sz` bytes of free, uninitialized memory, managed by the GC.
*/
extern (C) void* _d_allocmemory(size_t sz) @weak
{
    return GC.malloc(sz);
}

/**
Create a new class instance.

Allocates memory and sets fields to their initial value, but does not call a constructor.

---
new Object() // _d_newclass(typeid(Object))
---
Params:
    ci = `TypeInfo_Class` object, to provide instance size and initial bytes to copy

Returns: newly created object
*/
extern (C) Object _d_newclass(const ClassInfo ci) @weak
{
    void* p;
    auto init = ci.initializer;

    debug(PRINTF) printf("_d_newclass(ci = %p, %s)\n", ci, cast(char *)ci.name);
    if (ci.m_flags & TypeInfo_Class.ClassFlags.isCOMclass)
    {   /* COM objects are not garbage collected, they are reference counted
         * using AddRef() and Release().  They get free'd by C's free()
         * function called by Release() when Release()'s reference count goes
         * to zero.
     */
        p = malloc(init.length);
        if (!p)
            onOutOfMemoryError();
    }
    else
    {
        // TODO: should this be + 1 to avoid having pointers to the next block?
        BlkAttr attr = BlkAttr.NONE;
        // extern(C++) classes don't have a classinfo pointer in their vtable so the GC can't finalize them
        if (ci.m_flags & TypeInfo_Class.ClassFlags.hasDtor
            && !(ci.m_flags & TypeInfo_Class.ClassFlags.isCPPclass))
            attr |= BlkAttr.FINALIZE;
        if (ci.m_flags & TypeInfo_Class.ClassFlags.noPointers)
            attr |= BlkAttr.NO_SCAN;
        p = GC.malloc(init.length, attr, ci);
        debug(PRINTF) printf(" p = %p\n", p);
    }

    debug(PRINTF)
    {
        printf("p = %p\n", p);
        printf("ci = %p, ci.init.ptr = %p, len = %llu\n", ci, init.ptr, cast(ulong)init.length);
        printf("vptr = %p\n", *cast(void**) init);
        printf("vtbl[0] = %p\n", (*cast(void***) init)[0]);
        printf("vtbl[1] = %p\n", (*cast(void***) init)[1]);
        printf("init[0] = %x\n", (cast(uint*) init)[0]);
        printf("init[1] = %x\n", (cast(uint*) init)[1]);
        printf("init[2] = %x\n", (cast(uint*) init)[2]);
        printf("init[3] = %x\n", (cast(uint*) init)[3]);
        printf("init[4] = %x\n", (cast(uint*) init)[4]);
    }

    // initialize it
    p[0 .. init.length] = cast(void[]) init[];

    debug(PRINTF) printf("initialization done\n");
    return cast(Object) p;
}


/**
 *
 */
extern (C) void _d_delinterface(void** p)
{
    if (*p)
    {
        Interface* pi = **cast(Interface ***)*p;
        Object     o  = cast(Object)(*p - pi.offset);

        _d_delclass(&o);
        *p = null;
    }
}


// used for deletion
private extern (D) alias void function (Object) fp_t;


/**
 *
 */
extern (C) void _d_delclass(Object* p) @weak
{
    if (*p)
    {
        debug(PRINTF) printf("_d_delclass(%p)\n", *p);

        ClassInfo **pc = cast(ClassInfo **)*p;
        if (*pc)
        {
            ClassInfo c = **pc;

            rt_finalize(cast(void*) *p);

            if (c.deallocator)
            {
                fp_t fp = cast(fp_t)c.deallocator;
                (*fp)(*p); // call deallocator
                *p = null;
                return;
            }
        }
        else
        {
            rt_finalize(cast(void*) *p);
        }
        GC.free(cast(void*) *p);
        *p = null;
    }
}

// strip const/immutable/shared/inout from type info
inout(TypeInfo) unqualify(return scope inout(TypeInfo) cti) pure nothrow @nogc
{
    TypeInfo ti = cast() cti;
    while (ti)
    {
        // avoid dynamic type casts
        auto tti = typeid(ti);
        if (tti is typeid(TypeInfo_Const))
            ti = (cast(TypeInfo_Const)cast(void*)ti).base;
        else if (tti is typeid(TypeInfo_Invariant))
            ti = (cast(TypeInfo_Invariant)cast(void*)ti).base;
        else if (tti is typeid(TypeInfo_Shared))
            ti = (cast(TypeInfo_Shared)cast(void*)ti).base;
        else if (tti is typeid(TypeInfo_Inout))
            ti = (cast(TypeInfo_Inout)cast(void*)ti).base;
        else
            break;
    }
    return ti;
}

private uint __typeAttrs(const scope TypeInfo ti, void *copyAttrsFrom = null) pure nothrow
{
    if (copyAttrsFrom)
    {
        // try to copy attrs from the given block
        auto info = GC.query(copyAttrsFrom);
        if (info.base)
            return info.attr;
    }
    uint attrs = !(ti.flags & 1) ? BlkAttr.NO_SCAN : 0;
    if (typeid(ti) is typeid(TypeInfo_Struct)) {
        auto sti = cast(TypeInfo_Struct)cast(void*)ti;
        if (sti.xdtor)
            attrs |= BlkAttr.FINALIZE;
    }
    return attrs;
}

package bool hasPostblit(in TypeInfo ti) nothrow pure
{
    return (&ti.postblit).funcptr !is &TypeInfo.postblit;
}

void __doPostblit(void *ptr, size_t len, const TypeInfo ti)
{
    if (!hasPostblit(ti))
        return;

    if (auto tis = cast(TypeInfo_Struct)ti)
    {
        // this is a struct, check the xpostblit member
        auto pblit = tis.xpostblit;
        if (!pblit)
            // postblit not specified, no point in looping.
            return;

        // optimized for struct, call xpostblit directly for each element
        immutable size = ti.tsize;
        const eptr = ptr + len;
        for (;ptr < eptr;ptr += size)
            pblit(ptr);
    }
    else
    {
        // generic case, call the typeinfo's postblit function
        immutable size = ti.tsize;
        const eptr = ptr + len;
        for (;ptr < eptr;ptr += size)
            ti.postblit(ptr);
    }
}

/**
Allocate an array with the garbage collector.

Has three variants:
- `_d_newarrayU` leave elements uninitialized
- `_d_newarrayT` initializes to 0 (e.g `new int[]`)
- `_d_newarrayiT` initializes based on initializer retrieved from TypeInfo (e.g `new float[]`)

Params:
    ti = the type of the resulting array, (may also be the corresponding `array.ptr` type)
    length = `.length` of resulting array
Returns: newly allocated array
*/
extern (C) void[] _d_newarrayU(const scope TypeInfo ti, size_t length) pure nothrow @weak
{
    auto tinext = unqualify(ti.next);
    auto size = tinext.tsize;

    debug(PRINTF) printf("_d_newarrayU(length = x%zx, size = %zd)\n", length, size);
    if (length == 0 || size == 0)
        return null;

    bool overflow = false;
    size = mulu(size, length, overflow);
    if (!overflow)
    {
        if (auto ptr = GC.malloc(size, __typeAttrs(tinext) | BlkAttr.APPENDABLE, tinext))
        {
            debug(PRINTF) printf(" p = %p\n", ptr);
            return ptr[0 .. length];
        }
    }

    onOutOfMemoryError();
    assert(0);
}

/// ditto
extern (C) void[] _d_newarrayT(const TypeInfo ti, size_t length) pure nothrow @weak
{
    void[] result = _d_newarrayU(ti, length);
    auto tinext = unqualify(ti.next);
    auto size = tinext.tsize;

    memset(result.ptr, 0, size * length);
    return result;
}

/// ditto
extern (C) void[] _d_newarrayiT(const TypeInfo ti, size_t length) pure nothrow @weak
{
    import core.internal.traits : AliasSeq;

    void[] result = _d_newarrayU(ti, length);
    auto tinext = unqualify(ti.next);
    auto size = tinext.tsize;

    auto init = tinext.initializer();

    switch (init.length)
    {
    foreach (T; AliasSeq!(ubyte, ushort, uint, ulong))
    {
    case T.sizeof:
        if (tinext.talign % T.alignof == 0)
        {
            (cast(T*)result.ptr)[0 .. size * length / T.sizeof] = *cast(T*)init.ptr;
            return result;
        }
        goto default;
    }

    default:
    {
        immutable sz = init.length;
        for (size_t u = 0; u < size * length; u += sz)
            memcpy(result.ptr + u, init.ptr, sz);
        return result;
    }
    }
}

/**
Non-template version of $(REF _d_newitemT, core,lifetime) that does not perform
initialization. Needed for $(REF allocEntry, rt,aaA).

Params:
    _ti = `TypeInfo` of item to allocate
Returns:
    newly allocated item
*/
extern (C) void* _d_newitemU(scope const TypeInfo _ti) pure nothrow @weak
{
    auto ti = unqualify(_ti);
    auto flags = __typeAttrs(ti);

    return GC.malloc(ti.tsize, flags, ti);
}

/**
 *
 */
extern (C) void _d_delmemory(void* *p) @weak
{
    if (*p)
    {
        GC.free(*p);
        *p = null;
    }
}


/**
 *
 */
extern (C) void _d_callinterfacefinalizer(void *p) @weak
{
    if (p)
    {
        Interface *pi = **cast(Interface ***)p;
        Object o = cast(Object)(p - pi.offset);
        rt_finalize(cast(void*)o);
    }
}


/**
 *
 */
extern (C) void _d_callfinalizer(void* p) @weak
{
    rt_finalize( p );
}


/**
 *
 */
extern (C) void rt_setCollectHandler(CollectHandler h)
{
    collectHandler = h;
}


/**
 *
 */
extern (C) CollectHandler rt_getCollectHandler()
{
    return collectHandler;
}


/**
 *
 */
extern (C) int rt_hasFinalizerInSegment(void* p, size_t size, TypeInfo typeInfo, scope const(void)[] segment) nothrow
{
    if (!p)
        return false;

    if (typeInfo !is null)
    {
        assert(typeid(typeInfo) is typeid(TypeInfo_Struct));

        auto ti = cast(TypeInfo_Struct)cast(void*)typeInfo;
        return cast(size_t)(cast(void*)ti.xdtor - segment.ptr) < segment.length;
    }

    // otherwise class
    auto ppv = cast(void**) p;
    if (!*ppv)
        return false;

    auto c = *cast(ClassInfo*)*ppv;
    do
    {
        auto pf = c.destructor;
        if (cast(size_t)(pf - segment.ptr) < segment.length) return true;
    }
    while ((c = c.base) !is null);

    return false;
}

void finalize_array(void* p, size_t size, const TypeInfo_Struct si)
{
    // Due to the fact that the delete operator calls destructors
    // for arrays from the last element to the first, we maintain
    // compatibility here by doing the same.
    auto tsize = si.tsize;
    for (auto curP = p + size - tsize; curP >= p; curP -= tsize)
    {
        // call destructor
        si.destroy(curP);
    }
}

// called by the GC
void finalize_struct(void* p, TypeInfo_Struct ti) nothrow
{
    debug(PRINTF) printf("finalize_struct(p = %p)\n", p);

    try
    {
        ti.destroy(p); // call destructor
    }
    catch (Exception e)
    {
        onFinalizeError(ti, e);
    }
}

/**
 *
 */
extern (C) void rt_finalize2(void* p, bool det = true, bool resetMemory = true) nothrow
{
    debug(PRINTF) printf("rt_finalize2(p = %p)\n", p);

    auto ppv = cast(void**) p;
    if (!p || !*ppv)
        return;

    auto pc = cast(ClassInfo*) *ppv;
    try
    {
        if (det || collectHandler is null || collectHandler(cast(Object) p))
        {
            auto c = *pc;
            do
            {
                if (c.destructor)
                    (cast(fp_t) c.destructor)(cast(Object) p); // call destructor
            }
            while ((c = c.base) !is null);
        }

        if (ppv[1]) // if monitor is not null
            _d_monitordelete(cast(Object) p, det);

        if (resetMemory)
        {
            auto w = (*pc).initializer;
            p[0 .. w.length] = cast(void[]) w[];
        }
    }
    catch (Exception e)
    {
        onFinalizeError(*pc, e);
    }
    finally
    {
        *ppv = null; // zero vptr even if `resetMemory` is false
    }
}

/// Backwards compatibility
extern (C) void rt_finalize(void* p, bool det = true) nothrow
{
    rt_finalize2(p, det, true);
}

extern (C) void rt_finalizeFromGC(void* p, size_t size, uint attr, TypeInfo typeInfo) nothrow
{
    // to verify: reset memory necessary?
    if (typeInfo is null) {
        rt_finalize2(p, false, false); // class
        return;
    }

    assert(typeid(typeInfo) is typeid(TypeInfo_Struct));

    auto si = cast(TypeInfo_Struct)cast(void*)typeInfo;

    try
    {
        if (attr & BlkAttr.APPENDABLE)
        {
            finalize_array(p, size, si);
        }
        else
            finalize_struct(p, si); // struct
    }
    catch (Exception e)
    {
        onFinalizeError(si, e);
    }
}


/**
Append `dchar` to `char[]`, converting UTF-32 to UTF-8

---
void main()
{
    char[] s;
    s ~= 'α';
}
---

Params:
    x = array to append to cast to `byte[]`. Will be modified.
    c = `dchar` to append
Returns: updated `x` cast to `void[]`
*/
extern (C) void[] _d_arrayappendcd(ref byte[] x, dchar c) @weak
{
    // c could encode into from 1 to 4 characters
    char[4] buf = void;
    char[] appendthis; // passed to appendT
    if (c <= 0x7F)
    {
        buf.ptr[0] = cast(char)c;
        appendthis = buf[0..1];
    }
    else if (c <= 0x7FF)
    {
        buf.ptr[0] = cast(char)(0xC0 | (c >> 6));
        buf.ptr[1] = cast(char)(0x80 | (c & 0x3F));
        appendthis = buf[0..2];
    }
    else if (c <= 0xFFFF)
    {
        buf.ptr[0] = cast(char)(0xE0 | (c >> 12));
        buf.ptr[1] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        buf.ptr[2] = cast(char)(0x80 | (c & 0x3F));
        appendthis = buf[0..3];
    }
    else if (c <= 0x10FFFF)
    {
        buf.ptr[0] = cast(char)(0xF0 | (c >> 18));
        buf.ptr[1] = cast(char)(0x80 | ((c >> 12) & 0x3F));
        buf.ptr[2] = cast(char)(0x80 | ((c >> 6) & 0x3F));
        buf.ptr[3] = cast(char)(0x80 | (c & 0x3F));
        appendthis = buf[0..4];
    }
    else
    {
        onUnicodeError("Invalid UTF-8 sequence", 0);      // invalid utf character
    }

    //
    // TODO: This always assumes the array type is shared, because we do not
    // get a typeinfo from the compiler.  Assuming shared is the safest option.
    // Once the compiler is fixed, the proper typeinfo should be forwarded.
    //

    // Hack because _d_arrayappendT takes `x` as a reference
    auto xx = cast(shared(char)[])x;
    object._d_arrayappendT(xx, cast(shared(char)[])appendthis);
    x = cast(byte[])xx;
    return x;
}

unittest
{
    import core.exception : UnicodeException;

    /* Using inline try {} catch {} blocks fails to catch the UnicodeException
     * thrown.
     * https://issues.dlang.org/show_bug.cgi?id=16799
     */
    static void assertThrown(T : Throwable = Exception, E)(lazy E expr, string msg)
    {
        try
            expr;
        catch (T e) {
            assert(e.msg == msg);
            return;
        }
    }

    static void f()
    {
        string ret;
        int i = -1;
        ret ~= i;
    }

    assertThrown!UnicodeException(f(), "Invalid UTF-8 sequence");
}


/**
Append `dchar` to `wchar[]`, converting UTF-32 to UTF-16

---
void main()
{
    dchar x;
    wchar[] s;
    s ~= 'α';
}
---

Params:
    x = array to append to cast to `byte[]`. Will be modified.
    c = `dchar` to append

Returns: updated `x` cast to `void[]`
*/
extern (C) void[] _d_arrayappendwd(ref byte[] x, dchar c) @weak
{
    // c could encode into from 1 to 2 w characters
    wchar[2] buf = void;
    wchar[] appendthis; // passed to appendT
    if (c <= 0xFFFF)
    {
        buf.ptr[0] = cast(wchar) c;
        appendthis = buf[0..1];
    }
    else
    {
        buf.ptr[0] = cast(wchar) ((((c - 0x10000) >> 10) & 0x3FF) + 0xD800);
        buf.ptr[1] = cast(wchar) (((c - 0x10000) & 0x3FF) + 0xDC00);
        appendthis = buf[0..2];
    }

    //
    // TODO: This always assumes the array type is shared, because we do not
    // get a typeinfo from the compiler.  Assuming shared is the safest option.
    // Once the compiler is fixed, the proper typeinfo should be forwarded.
    //

    auto xx = (cast(shared(wchar)*)x.ptr)[0 .. x.length];
    object._d_arrayappendT(xx, cast(shared(wchar)[])appendthis);
    x = (cast(byte*)xx.ptr)[0 .. xx.length];
    return x;
}

/**
Allocate an array literal

Rely on the caller to do the initialization of the array.

---
int[] getArr()
{
    return [10, 20];
    // auto res = cast(int*) _d_arrayliteralTX(typeid(int[]), 2);
    // res[0] = 10;
    // res[1] = 20;
    // return res[0..2];
}
---

Params:
    ti = `TypeInfo` of resulting array type
    length = `.length` of array literal

Returns: pointer to allocated array
*/
extern (C)
void* _d_arrayliteralTX(const TypeInfo ti, size_t length) @weak
{
    auto tinext = unqualify(ti.next);
    auto sizeelem = tinext.tsize;              // array element size
    void* result;

    debug(PRINTF) printf("_d_arrayliteralTX(sizeelem = %zd, length = %zd)\n", sizeelem, length);
    if (length == 0 || sizeelem == 0)
        return null;
    else
    {
        auto allocsize = length * sizeelem;
        return GC.malloc(allocsize, __typeAttrs(tinext) | BlkAttr.APPENDABLE, tinext);
    }
}


unittest
{
    int[] a;
    int[] b;
    int i;

    a = new int[3];
    a[0] = 1; a[1] = 2; a[2] = 3;
    b = a.dup;
    assert(b.length == 3);
    for (i = 0; i < 3; i++)
        assert(b[i] == i + 1);

    // test slice appending
    b = a[0..1];
    b ~= 4;
    for (i = 0; i < 3; i++)
        assert(a[i] == i + 1);

    // test reserving
    char[] arr = new char[4093];
    for (i = 0; i < arr.length; i++)
        arr[i] = cast(char)(i % 256);

    // note that these two commands used to cause corruption, which may not be
    // detected.
    arr.reserve(4094);
    auto arr2 = arr ~ "123";
    assert(arr2[0..arr.length] == arr);
    assert(arr2[arr.length..$] == "123");

    // test postblit on array concat, append, length, etc.
    static struct S
    {
        int x;
        int pad;
        this(this)
        {
            ++x;
        }
    }
    void testPostBlit(T)()
    {
        auto sarr = new T[1];
        debug(SENTINEL) {} else
            assert(sarr.capacity == 1);

        // length extend
        auto sarr2 = sarr;
        assert(sarr[0].x == 0);
        sarr2.length += 1;
        assert(sarr2[0].x == 1);
        assert(sarr[0].x == 0);

        // append
        T s;
        sarr2 = sarr;
        sarr2 ~= s;
        assert(sarr2[0].x == 1);
        assert(sarr2[1].x == 1);
        assert(sarr[0].x == 0);
        assert(s.x == 0);

        // concat
        sarr2 = sarr ~ sarr;
        assert(sarr2[0].x == 1);
        assert(sarr2[1].x == 1);
        assert(sarr[0].x == 0);

        // concat multiple (calls different method)
        sarr2 = sarr ~ sarr ~ sarr;
        assert(sarr2[0].x == 1);
        assert(sarr2[1].x == 1);
        assert(sarr2[2].x == 1);
        assert(sarr[0].x == 0);

        // reserve capacity
        sarr2 = sarr;
        sarr2.reserve(2);
        assert(sarr2[0].x == 1);
        assert(sarr[0].x == 0);
    }
    testPostBlit!(S)();
    testPostBlit!(const(S))();
}

unittest
{
    // Bugzilla 3454 - Inconsistent flag setting in GC.realloc()
    static void test(size_t multiplier)
    {
        auto p = GC.malloc(8 * multiplier, 0);
        assert(GC.getAttr(p) == 0);

        // no move, set attr
        p = GC.realloc(p, 8 * multiplier + 5, BlkAttr.NO_SCAN);
        assert(GC.getAttr(p) == BlkAttr.NO_SCAN);

        // shrink, copy attr
        p = GC.realloc(p, 2 * multiplier, 0);
        assert(GC.getAttr(p) == BlkAttr.NO_SCAN);

        // extend, copy attr
        p = GC.realloc(p, 8 * multiplier, 0);
        assert(GC.getAttr(p) == BlkAttr.NO_SCAN);
    }
    test(16);
    version (OnlyLowMemUnittests) {} else
    test(1024 * 1024);
}

unittest
{
    import core.exception;
    try
    {
        size_t x = size_t.max;
        byte[] big_buf = new byte[x];
    }
    catch (OutOfMemoryError)
    {
    }
}

unittest
{
    // https://issues.dlang.org/show_bug.cgi?id=13854
    auto arr = new ubyte[PAGESIZE]; // ensure page size
    auto info1 = GC.query(arr.ptr);
    assert(info1.base !is arr.ptr); // offset is required for page size or larger

    auto arr2 = arr[0..1];
    assert(arr2.capacity == 0); // cannot append
    arr2 ~= 0; // add a byte
    assert(arr2.ptr !is arr.ptr); // reallocated
    auto info2 = GC.query(arr2.ptr);
    assert(info2.base is arr2.ptr); // no offset, the capacity is small.

    // do the same via setting length
    arr2 = arr[0..1];
    assert(arr2.capacity == 0);
    arr2.length += 1;
    assert(arr2.ptr !is arr.ptr); // reallocated
    info2 = GC.query(arr2.ptr);
    assert(info2.base is arr2.ptr); // no offset, the capacity is small.

    // do the same for char[] since we need a type with an initializer to test certain runtime functions
    auto carr = new char[PAGESIZE];
    info1 = GC.query(carr.ptr);
    assert(info1.base !is carr.ptr); // offset is required for page size or larger

    auto carr2 = carr[0..1];
    assert(carr2.capacity == 0); // cannot append
    carr2 ~= 0; // add a byte
    assert(carr2.ptr !is carr.ptr); // reallocated
    info2 = GC.query(carr2.ptr);
    assert(info2.base is carr2.ptr); // no offset, the capacity is small.

    // do the same via setting length
    carr2 = carr[0..1];
    assert(carr2.capacity == 0);
    carr2.length += 1;
    assert(carr2.ptr !is carr.ptr); // reallocated
    info2 = GC.query(carr2.ptr);
    assert(info2.base is carr2.ptr); // no offset, the capacity is small.
}

unittest
{
    // https://issues.dlang.org/show_bug.cgi?id=13878
    auto arr = new ubyte[1];
    auto info = GC.query(arr.ptr);
    assert(info.attr & BlkAttr.NO_SCAN); // should be NO_SCAN
    arr ~= 0; // ensure array is inserted into cache
    debug(SENTINEL) {} else
        assert(arr.ptr is info.base);
    GC.clrAttr(arr.ptr, BlkAttr.NO_SCAN); // remove the attribute
    auto arr2 = arr[0..1];
    assert(arr2.capacity == 0); // cannot append
    arr2 ~= 0;
    assert(arr2.ptr !is arr.ptr);
    info = GC.query(arr2.ptr);
    assert(!(info.attr & BlkAttr.NO_SCAN)); // ensure attribute sticks

    // do the same via setting length
    arr = new ubyte[1];
    arr ~= 0; // ensure array is inserted into cache
    GC.clrAttr(arr.ptr, BlkAttr.NO_SCAN); // remove the attribute
    arr2 = arr[0..1];
    assert(arr2.capacity == 0);
    arr2.length += 1;
    assert(arr2.ptr !is arr.ptr); // reallocated
    info = GC.query(arr2.ptr);
    assert(!(info.attr & BlkAttr.NO_SCAN)); // ensure attribute sticks

    // do the same for char[] since we need a type with an initializer to test certain runtime functions
    auto carr = new char[1];
    info = GC.query(carr.ptr);
    assert(info.attr & BlkAttr.NO_SCAN); // should be NO_SCAN
    carr ~= 0; // ensure array is inserted into cache
    debug(SENTINEL) {} else
        assert(carr.ptr is info.base);
    GC.clrAttr(carr.ptr, BlkAttr.NO_SCAN); // remove the attribute
    auto carr2 = carr[0..1];
    assert(carr2.capacity == 0); // cannot append
    carr2 ~= 0;
    assert(carr2.ptr !is carr.ptr);
    info = GC.query(carr2.ptr);
    assert(!(info.attr & BlkAttr.NO_SCAN)); // ensure attribute sticks

    // do the same via setting length
    carr = new char[1];
    carr ~= 0; // ensure array is inserted into cache
    GC.clrAttr(carr.ptr, BlkAttr.NO_SCAN); // remove the attribute
    carr2 = carr[0..1];
    assert(carr2.capacity == 0);
    carr2.length += 1;
    assert(carr2.ptr !is carr.ptr); // reallocated
    info = GC.query(carr2.ptr);
    assert(!(info.attr & BlkAttr.NO_SCAN)); // ensure attribute sticks
}

// test struct finalizers
debug(SENTINEL) {} else
deprecated unittest
{
    __gshared int dtorCount;
    static struct S1
    {
        int x;

        ~this()
        {
            dtorCount++;
        }
    }

    dtorCount = 0;
    S1* s2 = new S1;
    GC.runFinalizers((cast(char*)(typeid(S1).xdtor))[0..1]);
    assert(dtorCount == 1);
    GC.free(s2);

    dtorCount = 0;
    const(S1)* s3 = new const(S1);
    GC.runFinalizers((cast(char*)(typeid(S1).xdtor))[0..1]);
    assert(dtorCount == 1);
    GC.free(cast(void*)s3);

    dtorCount = 0;
    shared(S1)* s4 = new shared(S1);
    GC.runFinalizers((cast(char*)(typeid(S1).xdtor))[0..1]);
    assert(dtorCount == 1);
    GC.free(cast(void*)s4);

    dtorCount = 0;
    const(S1)[] carr1 = new const(S1)[5];
    auto blkinf1 = GC.query(carr1.ptr);
    GC.runFinalizers((cast(char*)(typeid(S1).xdtor))[0..1]);
    assert(dtorCount == 5);
    GC.free(blkinf1.base);

    dtorCount = 0;
    S1[] arr2 = new S1[10];
    arr2.length = 6;
    arr2.assumeSafeAppend;
    assert(dtorCount == 4); // destructors run explicitely?

    dtorCount = 0;
    auto blkinf = GC.query(arr2.ptr);
    GC.runFinalizers((cast(char*)(typeid(S1).xdtor))[0..1]);
    assert(dtorCount == 6);
    GC.free(blkinf.base);

    // associative arrays
    S1[int] aa1;
    aa1[0] = S1(0);
    aa1[1] = S1(1);
    dtorCount = 0;
    aa1 = null;
    auto dtor1 = typeid(TypeInfo_AssociativeArray.Entry!(int, S1)).xdtor;
    GC.runFinalizers((cast(char*)dtor1)[0..1]);
    assert(dtorCount == 2);

    int[S1] aa2;
    aa2[S1(0)] = 0;
    aa2[S1(1)] = 1;
    aa2[S1(2)] = 2;
    dtorCount = 0;
    aa2 = null;
    auto dtor2 = typeid(TypeInfo_AssociativeArray.Entry!(S1, int)).xdtor;
    GC.runFinalizers((cast(char*)dtor2)[0..1]);
    assert(dtorCount == 3);

    S1[2][int] aa3;
    aa3[0] = [S1(0),S1(2)];
    aa3[1] = [S1(1),S1(3)];
    dtorCount = 0;
    aa3 = null;
    auto dtor3 = typeid(TypeInfo_AssociativeArray.Entry!(int, S1[2])).xdtor;
    GC.runFinalizers((cast(char*)dtor3)[0..1]);
    assert(dtorCount == 4);
}

// test struct dtor handling not causing false pointers
unittest
{
    // for 64-bit, allocate a struct of size 40
    static struct S
    {
        size_t[4] data;
        S* ptr4;
    }
    auto p1 = new S;
    auto p2 = new S;
    p2.ptr4 = p1;

    // a struct with a dtor with size 32, but the dtor will cause
    //  allocation to be larger by a pointer
    static struct A
    {
        size_t[3] data;
        S* ptr3;

        ~this() {}
    }

    GC.free(p2);
    auto a = new A; // reuse same memory
    if (cast(void*)a is cast(void*)p2) // reusage not guaranteed
    {
        auto ptr = cast(S**)(a + 1);
        assert(*ptr != p1); // still same data as p2.ptr4?
    }

    // small array
    static struct SArr
    {
        void*[10] data;
    }
    auto arr1 = new SArr;
    arr1.data[] = p1;
    GC.free(arr1);

    // allocates 2*A.sizeof + (void*).sizeof (TypeInfo) + 1 (array length)
    auto arr2 = new A[2];
    if (cast(void*)arr1 is cast(void*)arr2.ptr) // reusage not guaranteed
    {
        auto ptr = cast(S**)(arr2.ptr + 2);
        assert(*ptr != p1); // still same data as p2.ptr4?
    }

    // large array
    static struct LArr
    {
        void*[1023] data;
    }
    auto larr1 = new LArr;
    larr1.data[] = p1;
    GC.free(larr1);

    auto larr2 = new S[255];
    import core.internal.gc.blockmeta : LARGEPREFIX;
    if (cast(void*)larr1 is cast(void*)larr2.ptr - LARGEPREFIX) // reusage not guaranteed
    {
        auto ptr = cast(S**)larr1;
        assert(ptr[0] != p1); // 16 bytes array header
        assert(ptr[1] != p1);
        version (D_LP64) {} else
        {
            assert(ptr[2] != p1);
            assert(ptr[3] != p1);
        }
    }
}

// test class finalizers exception handling
unittest
{
    bool test(E)()
    {
        import core.exception;
        static class C1
        {
            E exc;
            this(E exc) { this.exc = exc; }
            ~this() { throw exc; }
        }

        bool caught = false;
        C1 c = new C1(new E("test onFinalizeError"));
        try
        {
            GC.runFinalizers((cast(uint*)&C1.__dtor)[0..1]);
        }
        catch (FinalizeError err)
        {
            caught = true;
        }
        catch (E)
        {
        }
        GC.free(cast(void*)c);
        return caught;
    }

    assert( test!Exception);
    import core.exception : InvalidMemoryOperationError;
    assert(!test!InvalidMemoryOperationError);
}

// test bug 14126
unittest
{
    static struct S
    {
        S* thisptr;
        ~this() { assert(&this == thisptr); thisptr = null;}
    }

    S[] test14126 = new S[2048]; // make sure we allocate at least a PAGE
    foreach (ref s; test14126)
    {
        s.thisptr = &s;
    }
}
