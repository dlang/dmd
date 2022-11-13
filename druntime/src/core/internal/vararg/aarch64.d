/**
 * Varargs implementation for the AArch64 Procedure Call Standard (not followed by Apple).
 * Used by core.stdc.stdarg and core.vararg.
 *
 * Reference: https://github.com/ARM-software/abi-aa/blob/master/aapcs64/aapcs64.rst#appendix-variable-argument-lists
 *
 * Copyright: Copyright Digital Mars 2020 - 2020.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Martin Kinkelin
 * Source: $(DRUNTIMESRC core/internal/vararg/aarch64.d)
 */

module core.internal.vararg.aarch64;

version (AArch64):

// Darwin uses a simpler varargs implementation
version (OSX) {}
else version (iOS) {}
else version (TVOS) {}
else version (WatchOS) {}
else:

import core.stdc.stdarg : alignUp;

//@nogc:    // Not yet, need to make TypeInfo's member functions @nogc first
nothrow:

extern (C++, std) struct __va_list
{
    void* __stack;
    void* __gr_top;
    void* __vr_top;
    int __gr_offs;
    int __vr_offs;
}

///
alias va_list = __va_list;

///
T va_arg(T)(ref va_list ap)
{
    static if (is(T ArgTypes == __argTypes))
    {
        T onStack()
        {
            void* arg = ap.__stack;
            static if (T.alignof > 8)
                arg = arg.alignUp!16;
            ap.__stack = alignUp(arg + T.sizeof);
            version (BigEndian)
                static if (T.sizeof < 8)
                    arg += 8 - T.sizeof;
            return *cast(T*) arg;
        }

        static if (ArgTypes.length == 0)
        {
            // indirectly by value; get pointer and copy
            T* ptr = va_arg!(T*)(ap);
            return *ptr;
        }

        static assert(ArgTypes.length == 1);

        static if (is(ArgTypes[0] E : E[N], int N))
            alias FundamentalType = E; // static array element type
        else
            alias FundamentalType = ArgTypes[0];

        static if (__traits(isFloating, FundamentalType) || is(FundamentalType == __vector))
        {
            import core.stdc.string : memcpy;

            // SIMD register(s)
            int offs = ap.__vr_offs;
            if (offs >= 0)
                return onStack();           // reg save area empty
            enum int usedRegSize = FundamentalType.sizeof;
            static assert(T.sizeof % usedRegSize == 0);
            enum int nreg = T.sizeof / usedRegSize;
            ap.__vr_offs = offs + (nreg * 16);
            if (ap.__vr_offs > 0)
                return onStack();           // overflowed reg save area
            version (BigEndian)
                static if (usedRegSize < 16)
                    offs += 16 - usedRegSize;

            T result = void;
            static foreach (i; 0 .. nreg)
                memcpy((cast(void*) &result) + i * usedRegSize, ap.__vr_top + (offs + i * 16), usedRegSize);
            return result;
        }
        else
        {
            // GP register(s)
            int offs = ap.__gr_offs;
            if (offs >= 0)
                return onStack();           // reg save area empty
            static if (T.alignof > 8)
                offs = offs.alignUp!16;
            enum int nreg = (T.sizeof + 7) / 8;
            ap.__gr_offs = offs + (nreg * 8);
            if (ap.__gr_offs > 0)
                return onStack();           // overflowed reg save area
            version (BigEndian)
                static if (T.sizeof < 8)
                    offs += 8 - T.sizeof;
            return *cast(T*) (ap.__gr_top + offs);
        }
    }
    else
    {
        static assert(false, "not a valid argument type for va_arg");
    }
}

///
void va_arg()(ref va_list ap, TypeInfo ti, void* parmn)
{
    import core.stdc.string : memcpy;

    const size = ti.tsize;
    const alignment = ti.talign;

    if (auto ti_struct = cast(TypeInfo_Struct) ti)
    {
        TypeInfo arg1, arg2;
        ti.argTypes(arg1, arg2);

        if (!arg1)
        {
            // indirectly by value; get pointer and move
            void* ptr = va_arg!(void*)(ap);
            memcpy(parmn, ptr, size);
            return;
        }

        assert(!arg2);
        ti = arg1;
    }

    void onStack()
    {
        void* arg = ap.__stack;
        if (alignment > 8)
            arg = arg.alignUp!16;
        ap.__stack = alignUp(arg + size);
        version (BigEndian)
            if (size < 8)
                arg += 8 - size;
        memcpy(parmn, arg, size);
    }

    // HFVA structs have already been lowered to static arrays;
    // lower `ti` further to the fundamental type, including HFVA
    // static arrays.
    // TODO: complex numbers
    if (auto ti_sarray = cast(TypeInfo_StaticArray) ti)
        ti = ti_sarray.value;

    if (ti.flags() & 2)
    {
        // SIMD register(s)
        int offs = ap.__vr_offs;
        if (offs >= 0)
            return onStack();           // reg save area empty
        const usedRegSize = cast(int) ti.tsize;
        assert(size % usedRegSize == 0);
        const nreg = cast(int) (size / usedRegSize);
        ap.__vr_offs = offs + (nreg * 16);
        if (ap.__vr_offs > 0)
            return onStack();           // overflowed reg save area
        version (BigEndian)
            if (usedRegSize < 16)
                offs += 16 - usedRegSize;
        foreach (i; 0 .. nreg)
            memcpy(parmn + i * usedRegSize, ap.__vr_top + (offs + i * 16), usedRegSize);

        return;
    }

    // GP register(s)
    int offs = ap.__gr_offs;
    if (offs >= 0)
        return onStack();           // reg save area empty
    if (alignment > 8)
        offs = offs.alignUp!16;
    const nreg = cast(int) ((size + 7) / 8);
    ap.__gr_offs = offs + (nreg * 8);
    if (ap.__gr_offs > 0)
        return onStack();           // overflowed reg save area
    version (BigEndian)
        if (size < 8)
            offs += 8 - size;
    memcpy(parmn, ap.__gr_top + offs, size);
}
