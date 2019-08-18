/**
* The core.internal.atomic module comtains the low-level atomic features available in hardware.
* This module may be a routing layer for compiler intrinsics.
*
* Copyright: Copyright Manu Evans 2019.
* License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
* Authors:   Sean Kelly, Alex Rønne Petersen, Manu Evans
* Source:    $(DRUNTIMESRC core/internal/_atomic.d)
*/

module core.internal.atomic;

import core.atomic : MemoryOrder;

private
{
    enum : int
    {
        AX, BX, CX, DX, DI, SI, R8, R9
    }

    immutable string[4][8] registerNames = [
        [ "AL", "AX", "EAX", "RAX" ],
        [ "BL", "BX", "EBX", "RBX" ],
        [ "CL", "CX", "ECX", "RCX" ],
        [ "DL", "DX", "EDX", "RDX" ],
        [ "DIL", "DI", "EDI", "RDI" ],
        [ "SIL", "SI", "ESI", "RSI" ],
        [ "R8B", "R8W", "R8D", "R8" ],
        [ "R9B", "R9W", "R9D", "R9" ],
    ];

    template RegIndex(T)
    {
        static if (T.sizeof == 1)
            enum RegIndex = 0;
        else static if (T.sizeof == 2)
            enum RegIndex = 1;
        else static if (T.sizeof == 4)
            enum RegIndex = 2;
        else static if (T.sizeof == 8)
            enum RegIndex = 3;
        else
            static assert(false, "Invalid type");
    }

    enum SizedReg(int reg, T = size_t) = registerNames[reg][RegIndex!T];
}

T atomicLoad(MemoryOrder order = MemoryOrder.seq, T)(T* src) pure nothrow @nogc @safe
{

}

void atomicStore(MemoryOrder order = MemoryOrder.seq, T)(T* src, T value) pure nothrow @nogc @safe
{

}

T atomicFetchAdd(MemoryOrder order = MemoryOrder.seq, bool result = true, T)(T* dest, T value) pure nothrow @nogc @safe
    if (is(T : ulong))
{
    version (D_InlineAsm_X86)
    {
        static assert(T.sizeof <= 4, "64bit atomicFetchAdd not supported on 32bit target." );

        enum DestReg = SizedReg!DX;
        enum ValReg = SizedReg!(AX, T);

        mixin (simpleFormat(q{
            asm pure nothrow @nogc @trusted
            {
                mov %1, value;
                mov %0, dest;
                lock; xadd[%0], %1;
            }
        }, DestReg, ValReg));
    }
    else version (D_InlineAsm_X86_64)
    {
        version (Windows)
        {
            enum DestReg = SizedReg!DX;
            enum ValReg = SizedReg!(CX, T);
        }
        else
        {
            enum DestReg = SizedReg!SI;
            enum ValReg = SizedReg!(DI, T);
        }
        enum ResReg = result ? SizedReg!(AX, T) : null;

        mixin (simpleFormat(q{
            asm pure nothrow @nogc @trusted
            {
                naked;
                lock; xadd[%0], %1;
?2                mov %2, %1;
                ret;
            }
        }, DestReg, ValReg, ResReg));
    }
    else
        static assert (false, "Unsupported architecture.");
}

T atomicFetchSub(MemoryOrder order = MemoryOrder.seq, bool result = true, T)(T* dest, T value) pure nothrow @nogc @safe
    if (is(T : ulong))
{
    return atomicFetchAdd(dest, cast(T)-cast(IntOrLong!T)value);
}

T atomicExchange(MemoryOrder order = MemoryOrder.seq, bool result = true, T)(T* dest, T value) pure nothrow @nogc @safe
    if (is(T : ulong) || is(T == class) || is(T U : U*))
{
    version (D_InlineAsm_X86)
    {
        static assert(T.sizeof <= 4, "64bit atomicExchange not supported on 32bit target." );

        enum DestReg = SizedReg!CX;
        enum ValReg = SizedReg!(AX, T);

        mixin (simpleFormat(q{
            asm pure nothrow @nogc @trusted
            {
                mov %1, value;
                mov %0, dest;
                xchg [%0], %1;
            }
        }, DestReg, ValReg));
    }
    else version (D_InlineAsm_X86_64)
    {
        version (Windows)
        {
            enum DestReg = SizedReg!DX;
            enum ValReg = SizedReg!(CX, T);
        }
        else
        {
            enum DestReg = SizedReg!SI;
            enum ValReg = SizedReg!(DI, T);
        }
        enum ResReg = result ? SizedReg!(AX, T) : null;

        mixin (simpleFormat(q{
            asm pure nothrow @nogc @trusted
            {
                naked;
                xchg [%0], %1;
?2                mov %2, %1;
                ret;
            }
        }, DestReg, ValReg, ResReg));
    }
    else
        static assert (false, "Unsupported architecture.");
}

alias atomicCompareExchangeWeak = atomicCompareExchangeStrong;

bool atomicCompareExchangeStrong(MemoryOrder succ = MemoryOrder.seq, MemoryOrder fail = MemoryOrder.seq, T)(T* dest, T* compare, T value) pure nothrow @nogc @safe
    if (CanCAS!T)
{
    version (D_InlineAsm_X86)
    {
        static if (T.sizeof <= 4)
        {
            enum DestAddr = SizedReg!CX;
            enum CmpAddr = SizedReg!DI;
            enum Val = SizedReg!(DX, T);
            enum Cmp = SizedReg!(AX, T);

            mixin (simpleFormat(q{
                asm pure nothrow @nogc @trusted
                {
                    push %1;
                    mov %2, value;
                    mov %1, compare;
                    mov %3, [%1];
                    mov %0, dest;
                    lock; cmpxchg [%0], %2;
                    mov [%1], %3;
                    setz AL;
                    pop %1;
                }
            }, DestAddr, CmpAddr, Val, Cmp));
        }
        else static if (T.sizeof == 8)
        {
            asm pure nothrow @nogc @trusted
            {
                push EDI;
                push EBX;
                lea EDI, value;
                mov EBX, [EDI];
                mov ECX, 4[EDI];
                mov EDI, compare;
                mov EAX, [EDI];
                mov EDX, 4[EDI];
                mov EDI, dest;
                lock; cmpxchg8b [EDI];
                mov EDI, compare;
                mov [EDI], EAX;
                mov 4[EDI], EDX;
                setz AL;
                pop EBX;
                pop EDI;
            }
        }
        else
            static assert(T.sizeof <= 8, "128bit atomicCompareExchangeStrong not supported on 32bit target." );
    }
    else version (D_InlineAsm_X86_64)
    {
        static if (T.sizeof <= 8)
        {
            version (Windows)
            {
                enum DestAddr = SizedReg!R8;
                enum CmpAddr = SizedReg!DX;
                enum Val = SizedReg!(CX, T);
            }
            else
            {
                enum DestAddr = SizedReg!DX;
                enum CmpAddr = SizedReg!SI;
                enum Val = SizedReg!(DI, T);
            }
            enum Res = SizedReg!(AX, T);

            mixin (simpleFormat(q{
                asm pure nothrow @nogc @trusted
                {
                    naked;
                    mov %3, [%1];
                    lock; cmpxchg [%0], %2;
                    jne compare_fail;
                    mov AL, 1;
                    ret;
                compare_fail:
                    mov [%1], %3;
                    xor AL, AL;
                    ret;
                }
            }, DestAddr, CmpAddr, Val, Res));
        }
        else
        {
            version (Windows)
            {
                asm pure nothrow @nogc @trusted
                {
                    naked;
                    push RBX;
                    mov R9, RDX;
                    mov RAX, [RDX];
                    mov RDX, 8[RDX];
                    mov RBX, [RCX];
                    mov RCX, 8[RCX];
                    lock; cmpxchg16b [R8];
                    pop RBX;
                    jne compare_fail;
                    mov AL, 1;
                    ret;
                compare_fail:
                    mov [R9], RAX;
                    mov 8[R9], RDX;
                    xor AL, AL;
                    ret;
                }
            }
            else
            {
                asm pure nothrow @nogc @trusted
                {
                    naked;
                    push RBX;
                    mov R8, RCX;
                    mov R9, RDX;
                    mov RAX, [RDX];
                    mov RDX, 8[RDX];
                    mov RBX, RDI;
                    mov RCX, RSI;
                    lock; cmpxchg16b [R8];
                    pop RBX;
                    jne compare_fail;
                    mov AL, 1;
                    ret;
                compare_fail:
                    mov [R9], RAX;
                    mov 8[R9], RDX;
                    xor AL, AL;
                    ret;
                }
            }
        }
    }
    else
        static assert (false, "Unsupported architecture.");
}

bool atomicCompareExchangeStrongNoResult(MemoryOrder succ = MemoryOrder.seq, MemoryOrder fail = MemoryOrder.seq, T)(T* dest, T compare, T value) pure nothrow @nogc @safe
    if (CanCAS!T)
{
    version (D_InlineAsm_X86)
    {
        static if (T.sizeof <= 4)
        {
            enum DestAddr = SizedReg!CX;
            enum Cmp = SizedReg!(AX, T);
            enum Val = SizedReg!(DX, T);

            mixin (simpleFormat(q{
                asm pure nothrow @nogc @trusted
                {
                    mov %2, value;
                    mov %1, compare;
                    mov %0, dest;
                    lock; cmpxchg [%0], %2;
                    setz AL;
                }
            }, DestAddr, Cmp, Val));
        }
        else static if (T.sizeof == 8)
        {
            asm pure nothrow @nogc @trusted
            {
                push EDI;
                push EBX;
                lea EDI, value;
                mov EBX, [EDI];
                mov ECX, 4[EDI];
                lea EDI, compare;
                mov EAX, [EDI];
                mov EDX, 4[EDI];
                mov EDI, dest;
                lock; cmpxchg8b [EDI];
                setz AL;
                pop EBX;
                pop EDI;
            }
        }
        else
            static assert(T.sizeof <= 8, "128bit atomicCompareExchangeStrong not supported on 32bit target." );
    }
    else version (D_InlineAsm_X86_64)
    {
        static if (T.sizeof <= 8)
        {
            version (Windows)
            {
                enum DestAddr = SizedReg!R8;
                enum Cmp = SizedReg!(DX, T);
                enum Val = SizedReg!(CX, T);
            }
            else
            {
                enum DestAddr = SizedReg!DX;
                enum Cmp = SizedReg!(SI, T);
                enum Val = SizedReg!(DI, T);
            }
            enum AXReg = SizedReg!(AX, T);

            mixin (simpleFormat(q{
                asm pure nothrow @nogc @trusted
                {
                    naked;
                    mov %3, %1;
                    lock; cmpxchg [%0], %2;
                    setz AL;
                    ret;
                }
            }, DestAddr, Cmp, Val, AXReg));
        }
        else
        {
            version (Windows)
            {
                asm pure nothrow @nogc @trusted
                {
                    naked;
                    push RBX;
                    mov RAX, [RDX];
                    mov RDX, 8[RDX];
                    mov RBX, [RCX];
                    mov RCX, 8[RCX];
                    lock; cmpxchg16b [R8];
                    setz AL;
                    pop RBX;
                    ret;
                }
            }
            else
            {
                asm pure nothrow @nogc @trusted
                {
                    naked;
                    push RBX;
                    mov RAX, RDX;
                    mov RDX, RCX;
                    mov RBX, RDI;
                    mov RCX, RSI;
                    lock; cmpxchg16b [R8];
                    setz AL;
                    pop RBX;
                    ret;
                }
            }
        }
    }
    else
        static assert (false, "Unsupported architecture.");
}

void atomicFence(MemoryOrder order = MemoryOrder.seq)() nothrow @nogc @safe
{
    // TODO: `mfence` should only be required for seq_cst operations, but this depends on
    //       the compiler's backend knowledge to not reorder code inappropriately,
    //       so we'll apply it conservatively.
    static if (order != MemoryOrder.raw)
    {
        version (D_InlineAsm_X86)
        {
            import core.cpuid;

            // TODO: review this implementation; it seems way overly complicated
            asm pure nothrow @nogc @trusted
            {
                naked;

                call sse2;
                test AL, AL;
                jne Lcpuid;

                // Fast path: We have SSE2, so just use mfence.
                mfence;
                jmp Lend;

            Lcpuid:

                // Slow path: We use cpuid to serialize. This is
                // significantly slower than mfence, but is the
                // only serialization facility we have available
                // on older non-SSE2 chips.
                push EBX;

                mov EAX, 0;
                cpuid;

                pop EBX;

            Lend:

                ret;
            }
        }
        else version (D_InlineAsm_X86_64)
        {
            asm nothrow @nogc @trusted
            {
                naked;
                mfence;
                ret;
            }
        }
    }
    else
        static assert (false, "Unsupported architecture.");
}


private:

enum CanCAS(T) = is(T : ulong) ||
                 is(T == class) ||
                 is(T : U*, U) ||
                 (is(T == struct) && T.sizeof <= 16 && (T.sizeof & (T.sizeof - 1)) == 0);

template IntOrLong(T)
{
    static if (T.sizeof > 4)
        alias IntOrLong = long;
    else
        alias IntOrLong = int;
}

// this is a helper to build asm blocks
string simpleFormat(string format, string[] args...)
{
    string result;
    outer: while (format.length)
    {
        foreach (i; 0 .. format.length)
        {
            if (format[i] == '%' || format[i] == '?')
            {
                bool isQ = format[i] == '?';
                result ~= format[0 .. i++];
                assert (i < format.length, "Invalid format string");
                if (format[i] == '%' || format[i] == '?')
                {
                    assert(!isQ, "Invalid format string");
                    result ~= format[i++];
                }
                else
                {
                    int index = 0;
                    assert (format[i] >= '0' && format[i] <= '9', "Invalid format string");
                    while (i < format.length && format[i] >= '0' && format[i] <= '9')
                        index = index * 10 + (ubyte(format[i++]) - ubyte('0'));
                    if (!isQ)
                        result ~= args[index];
                    else if (!args[index])
                    {
                        size_t j = i;
                        for (; j < format.length;)
                        {
                            if (format[j++] == '\n')
                                break;
                        }
                        i = j;
                    }
                }
                format = format[i .. $];
                continue outer;
            }
        }
        result ~= format;
        break;
    }
    return result;
}
