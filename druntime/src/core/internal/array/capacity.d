/**
 This module contains support for controlling dynamic arrays' capacity and length

  Copyright: Copyright Digital Mars 2000 - 2019.
  License: Distributed under the
       $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
     (See accompanying file LICENSE)
  Source: $(DRUNTIMESRC core/internal/_array/_capacity.d)
*/
module core.internal.array.capacity;

debug (PRINTF) import core.stdc.stdio : printf;
debug (VALGRIND) import etc.valgrind.valgrind;

// for now, all GC array functions are not exposed via core.memory.
extern(C) {
    void[] gc_getArrayUsed(void *ptr, bool atomic) nothrow;
    bool gc_expandArrayUsed(void[] slice, size_t newUsed, bool atomic) nothrow pure;
    size_t gc_reserveArrayCapacity(void[] slice, size_t request, bool atomic) nothrow;
    bool gc_shrinkArrayUsed(void[] slice, size_t existingUsed, bool atomic) nothrow;
}

/**
Resize a dynamic array by setting its `.length` property.

Newly created elements are initialized based on their default value.
If the array's elements initialize to `0`, memory is zeroed out. Otherwise, elements are explicitly initialized.

This function handles memory allocation, expansion, and initialization while maintaining array integrity.

---
void main()
{
    int[] a = [1, 2];
    a.length = 3; // Gets lowered to `_d_arraysetlengthT!(int)(a, 3, true)`
}
---

Params:
    arr         = The array to resize.
    newlength   = The new value for the array's `.length`.

Returns:
    The resized array with updated length and properly initialized elements.

Throws:
    OutOfMemoryError if allocation fails.
*/

size_t _d_arraysetlengthT(Tarr : T[], T)(return ref scope Tarr arr, size_t newlength) @trusted
{
    import core.attribute : weak;
    import core.checkedint : mulu;
    import core.exception : onFinalizeError, onOutOfMemoryError;
    import core.stdc.string : memcpy, memset;
    import core.internal.traits : Unqual;
    import core.lifetime : emplace;
    import core.memory;

    alias BlkAttr = GC.BlkAttr;
    alias UnqT = Unqual!T;

    debug(PRINTF) printf("_d_arraysetlengthT(arr.ptr = %p, arr.length = %zd, newlength = %zd)\n", arr.ptr, arr.length, newlength);

    // If the new length is less than or equal to the current length, just truncate the array
    if (newlength <= arr.length)
    {
        arr = arr[0 .. newlength];
        return newlength;
    }

    enum sizeelem = T.sizeof;
    ubyte overflow = 0;

    size_t newsize = void;

    version (D_InlineAsm_X86)
    {
        asm pure nothrow @nogc
        {
            mov EAX, sizeelem;
            mul newlength;        // EDX:EAX = EAX * newlength
            mov newsize, EAX;
            setc overflow;
        }
    }
    else version (D_InlineAsm_X86_64)
    {
        asm pure nothrow @nogc
        {
            mov RAX, sizeelem;
            mul newlength;        // RDX:RAX = RAX * newlength
            mov newsize, RAX;
            setc overflow;
        }
    }
    else
    {
        newsize = mulu(sizeelem, newlength, overflow);
    }

    if (overflow)
    {
        onOutOfMemoryError();
        assert(0);
    }

    debug(PRINTF) printf("newsize = %zx\n", newsize);

    uint gcAttrs = BlkAttr.APPENDABLE;
    static if (is(T == struct) && __traits(hasMember, T, "xdtor"))
    {
        gcAttrs |= BlkAttr.FINALIZE;
    }

    if (!arr.ptr)
    {
        assert(arr.length == 0);
        void* ptr = GC.malloc(newsize, gcAttrs);
        if (!ptr)
        {
            onOutOfMemoryError();
            assert(0);
        }

        static if (__traits(isZeroInit, T))
        {
            memset(ptr, 0, newsize);
        }
        else static if (is(T == inout U, U))
        {
            // Cannot directly construct inout types; use unqualified T.init
            foreach (i; 0 .. newlength)
                emplace(cast(UnqT*) ptr + i, UnqT.init);
        }
        else
        {
            foreach (i; 0 .. newlength)
                emplace(cast(T*) ptr + i, T.init);
        }

        arr = (cast(T*) ptr)[0 .. newlength];
        return newlength;
    }

    size_t oldsize = arr.length * sizeelem;
    bool isshared = is(T == shared T);

    auto newdata = cast(void*) arr.ptr;

    if (!gc_expandArrayUsed(newdata[0 .. oldsize], newsize, isshared))
    {
        newdata = GC.malloc(newsize, gcAttrs);
        if (!newdata)
        {
            onOutOfMemoryError();
            assert(0);
        }

        static if (__traits(compiles, emplace(cast(UnqT*)newdata, arr[0])))
        {
            foreach (i; 0 .. arr.length)
                emplace(cast(UnqT*)newdata + i, arr[i]); // safe copy
        }
        else
        {
            memcpy(newdata, cast(const(void)*)arr.ptr, oldsize);
        }
    }

    // Handle initialization based on whether the type requires zero-init
    static if (__traits(isZeroInit, T))
        memset(cast(void*) (cast(ubyte*)newdata + oldsize), 0, newsize - oldsize);
    else static if (__traits(compiles, emplace(cast(UnqT*) (cast(ubyte*)newdata + oldsize), UnqT.init)))
    {
        foreach (i; 0 .. newlength - arr.length)
            emplace(cast(UnqT*) (cast(ubyte*)newdata + oldsize) + i, UnqT.init);
    }
    else
    {
        foreach (i; 0 .. newlength - arr.length)
            memcpy(cast(UnqT*) (cast(ubyte*)newdata + oldsize) + i, cast(const void*)&UnqT.init, T.sizeof);
    }

    arr = (cast(T*) newdata)[0 .. newlength];
    return newlength;
}

version (D_ProfileGC)
{
    enum errorMessage = "Cannot resize arrays";
    import core.internal.array.utils : _d_HookTraceImpl;

    // Function wrapper around the hook, so it’s callable
    size_t _d_arraysetlengthTTrace(Tarr : T[], T)(
        return ref scope Tarr arr,
        size_t newlength,
        string file = __FILE__,
        int line = __LINE__,
        string func = __FUNCTION__
    ) @trusted
    {
        alias Hook = _d_HookTraceImpl!(Tarr, _d_arraysetlengthT!Tarr, errorMessage);
        return Hook(arr, newlength, file, line, func);
    }
}

// @safe unittest remains intact
@safe unittest
{
    struct S
    {
        float f = 1.0;
    }

    int[] arr;
    _d_arraysetlengthT!(typeof(arr))(arr, 16);
    assert(arr.length == 16);
    foreach (int i; arr)
        assert(i == int.init);

    shared S[] arr2;
    _d_arraysetlengthT!(typeof(arr2))(arr2, 16);
    assert(arr2.length == 16);
    foreach (s; arr2)
        assert(s == S.init);
}
