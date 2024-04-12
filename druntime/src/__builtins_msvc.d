/* This file contains D reimplementations of some of the intrinsics recognised
   by the MSVC compiler, for ImportC.
   This module is intended for only internal use, hence the leading double underscore.

   Copyright: Copyright D Language Foundation 2024-2024
   License: $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
   Authors: Harry Gillanders
   Source: $(DRUNTIMESRC __builtins_msvc.d) */

module __builtins_msvc;

version (CRuntime_Microsoft)
{
    version = MSVCIntrinsics;
}

version (MSVCIntrinsics)
{
    version (X86)
    {
        version = X86_64_Or_X86;
    }
    else version (X86_64)
    {
        version = X86_64_Or_X86;
        version = X86_64_Or_AArch64;
        version = X86_64_Or_AArch64_Or_ARM;
    }
    else version (AArch64)
    {
        version = X86_64_Or_AArch64;
        version = X86_64_Or_AArch64_Or_ARM;
        version = AArch64_Or_ARM;
    }
    else version (ARM)
    {
        version = X86_64_Or_AArch64_Or_ARM;
        version = AArch64_Or_ARM;
    }

    version (D_InlineAsm_X86)
    {
        version = InlineAsm_X86_64_Or_X86;
    }
    else version (D_InlineAsm_X86_64)
    {
        version = InlineAsm_X86_64_Or_X86;
    }

    version (LDC)
    {
        version = LDC_Or_GNU;
    }
    else version (GNU)
    {
        version = LDC_Or_GNU;
    }

    static if (__traits(compiles, () {import core.simd : float4;}))
    {
        private enum canPassVectors = true;
    }
    else
    {
        private enum canPassVectors = false;
    }

    version (X86_64_Or_AArch64)
    {
        import core.internal.traits : AliasSeq;
    }

    version (LDC)
    {
        private template llvmIRPtr(string type, string postfix = null)
        {
            version (LDC_LLVM_OpaquePointers)
            {
                enum llvmIRPtr = postfix is null ? "ptr" : "ptr " ~ postfix;
            }
            else
            {
                enum llvmIRPtr = postfix is null ? type ~ "*" : type ~ " " ~ postfix ~ "*";
            }
        }
    }

    version (X86_64_Or_AArch64)
    {
        extern(C)
        pragma(inline, true)
        ulong __umulh(ulong a, ulong b) @safe pure nothrow @nogc
        {
            return multiplyWithDoubleWidthProduct!(ulong, true)(a, b);
        }

        extern(C)
        pragma(inline, true)
        long __mulh(long a, long b) @safe pure nothrow @nogc
        {
            return multiplyWithDoubleWidthProduct!(long, true)(a, b);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        ulong _umul128(ulong Multiplier, ulong Multiplicand, scope ulong* HighProduct) @safe pure nothrow @nogc
        {
            return multiplyWithDoubleWidthProduct!(ulong, false)(Multiplier, Multiplicand, HighProduct);
        }

        extern(C)
        pragma(inline, true)
        long _mul128(long Multiplier, long Multiplicand, scope long* HighProduct) @safe pure nothrow @nogc
        {
            return multiplyWithDoubleWidthProduct!(long, false)(Multiplier, Multiplicand, HighProduct);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        long __emul(int a, int b) @safe pure nothrow @nogc
        {
            return long(a) * b;
        }

        extern(C)
        pragma(inline, true)
        ulong __emulu(uint a, uint b) @safe pure nothrow @nogc
        {
            return ulong(a) * b;
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static bool test()
        {
            version (X86_64_Or_X86)
            {
                assert(__emul(7, -5) == -35);
                assert(__emul(-11, 13) == -143);
                assert(__emul(0x00FFFFFF, 1 << 16) == 0xFF_FFFF0000);

                assert(__emulu(7, 5) == 35);
                assert(__emulu(11, 13) == 143);
                assert(__emulu(0xFFFFFFFF, 1 << 8) == 0xFF_FFFFFF00);
            }

            version (X86_64)
            {
                {
                    long hi = 3;
                    assert(_mul128(7, -5, &hi) == -35);
                    assert(hi == -1);
                    assert(_mul128(-11, 13, &hi) == -143);
                    assert(hi == -1);
                    assert(_mul128(0x00FFFFFF, 1 << 16, &hi) == 0xFF_FFFF0000);
                    assert(hi == 0);
                    assert(_mul128(0x00FFFFFF_FFFFFFFF, long(1) << 32, &hi) == 0xFFFFFFFF_00000000);
                    assert(hi == 0x00FFFFFF);
                }

                {
                    ulong hi = 3;
                    assert(_umul128(7, 5, &hi) == 35);
                    assert(hi == 0);
                    assert(_umul128(11, 13, &hi) == 143);
                    assert(hi == 0);
                    assert(_umul128(0x00FFFFFF, 1 << 16, &hi) == 0xFF_FFFF0000);
                    assert(hi == 0);
                    assert(_umul128(0xFFFFFFFF_FFFFFFFF, long(1) << 32, &hi) == 0xFFFFFFFF_00000000);
                    assert(hi == 0xFFFFFFFF);
                }
            }

            version (X86_64_Or_AArch64)
            {
                assert(__mulh(7, -5) == -1);
                assert(__mulh(-11, 13) == -1);
                assert(__mulh(0x00FFFFFF, 1 << 16) == 0);
                assert(__mulh(0x00FFFFFF_FFFFFFFF, long(1) << 32) == 0x00FFFFFF);

                assert(__umulh(7, 5) == 0);
                assert(__umulh(11, 13) == 0);
                assert(__umulh(0x00FFFFFF, 1 << 16) == 0);
                assert(__umulh(0xFFFFFFFF_FFFFFFFF, long(1) << 32) == 0xFFFFFFFF);
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    version (X86_64_Or_AArch64)
    {
        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        private I multiplyWithDoubleWidthProduct(I, bool onlyHighHalf)(
            I low,
            I high,
            scope AliasSeq!(I*)[0 .. !onlyHighHalf] highProduct
        ) @trusted
        if (is(I == ulong) || is(I == long))
        {
            enum bool unsigned = is(I == ulong);

            static if (unsigned)
            {
                alias multiplyViaSoftware = unsignedMultiplyWithDoubleWidthProduct;
            }
            else
            {
                alias multiplyViaSoftware = signedMultiplyWithDoubleWidthProduct;
            }

            if (__ctfe)
            {
                return multiplyViaSoftware!(I, onlyHighHalf)(low, high, highProduct);
            }
            else
            {
                version (LDC)
                {
                    import ldc.llvmasm : __ir_pure;

                    enum ptr = llvmIRPtr!"i64";
                    enum ext = unsigned ? "zext" : "sext";

                    I a = low;
                    I b = high;
                    I lo;
                    I hi;

                    __ir_pure!(
                        "%a = " ~ ext ~ " i64 %0 to i128
                         %b = " ~ ext ~ " i64 %1 to i128

                         %product = mul i128 %a, %b

                        " ~ (onlyHighHalf ? "" : "%lo = trunc i128 %product to i64\n")

                        ~ "%hi128 = lshr i128 %product, 64
                         %hi = trunc i128 %hi128 to i64

                        " ~ (onlyHighHalf ? "" : "store i64 %lo, " ~ ptr ~ " %2\n")
                        ~ "store i64 %hi, " ~ ptr ~ " %3",
                        void
                    )(a, b, &lo, &hi);

                    static if (onlyHighHalf)
                    {
                        return hi;
                    }
                    else
                    {
                        *highProduct[0] = hi;
                        return lo;
                    }
                }
                else version (GNU)
                {
                    I lo;
                    I hi;

                    version (X86_64)
                    {
                        /* for unsigned operands; if we have PEXT, then the target has BMI2, ergo we can use MULX. */
                        static if (unsigned && __traits(compiles, () {import gcc.builtins : __builtin_ia32_pext_si;}))
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                  "mulx %2, %0, %1"
                                : "=r" (lo), "=r" (hi)
                                : "rm" (low), "d" (high);
                            }
                        }
                        else
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                  (unsigned ? "mul" : "imul") ~ " %3"
                                : "=a" (lo), "=d" (hi)
                                : "%0" (low), "rm" (high)
                                : "cc";
                            }
                        }
                    }
                    else version (AArch64)
                    {
                        static if (!onlyHighHalf)
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                  "mul %0, %1, %2"
                                : "=r" (lo)
                                : "%r" (low), "r" (high);
                            }
                        }

                        asm @trusted pure nothrow @nogc
                        {
                              "umulh %0, %1, %2"
                            : "=r" (hi)
                            : "%r" (low), "r" (high);
                        }
                    }

                    static if (onlyHighHalf)
                    {
                        return hi;
                    }
                    else
                    {
                        *highProduct[0] = hi;
                        return lo;
                    }
                }
                else version (D_InlineAsm_X86_64)
                {
                    mixin(
                        "asm @trusted pure nothrow @nogc
                         {
                             /* RCX is low; RDX is high; R8 is highProduct, if present. */
                             naked;
                             mov RAX, RCX;
                             " ~ (unsigned ? "mul" : "imul") ~ " RDX;
                             mov " ~ (onlyHighHalf ? "RAX" : "[R8]") ~ ", RDX;
                             ret;
                         }"
                    );
                }
                else
                {
                    return multiplyViaSoftware!(I, onlyHighHalf)(low, high, highProduct);
                }
            }
        }

        pragma(inline, true)
        private I unsignedMultiplyWithDoubleWidthProduct(I, bool onlyHighHalf)(
            I low,
            I high,
            scope AliasSeq!(I*)[0 .. !onlyHighHalf] highProduct
        ) @safe pure nothrow @nogc
        if (__traits(isIntegral, I) && __traits(isUnsigned, I))
        {
            enum uint halfWidth = I.sizeof << 2;
            enum I lowerHalf = (cast(I) ~I(0)) >>> halfWidth;

            auto first = low & lowerHalf;
            auto second = low >>> halfWidth;
            auto third = high & lowerHalf;
            auto fourth = high >>> halfWidth;

            I lowest = cast(I) (cast(I) first * cast(I) third);
            I lower = cast(I) (cast(I) first * cast(I) fourth);
            I higher = cast(I) (cast(I) second * cast(I) third);
            I highest = cast(I) (cast(I) second * cast(I) fourth);

            I middle = cast(I) ((higher & lowerHalf) + lower + (lowest >>> halfWidth));
            static if (!onlyHighHalf) I bottom = cast(I) ((middle << halfWidth) + (lowest & lowerHalf));
            I top = cast(I) (highest + (higher >>> halfWidth) + (middle >>> halfWidth));

            static if (onlyHighHalf)
            {
                return top;
            }
            else
            {
                *highProduct[0] = top;
                return bottom;
            }
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        @trusted pure nothrow @nogc unittest
        {
            /* The mechanics used to get a double-width product from two operands are the same regardless of the width.
               So, if this works for 8x8->16-bit multiplication, it'll work for 64x64->128-bit multiplication. */

            ubyte left = 0;
            ubyte right = 0;

            do
            {
                do
                {
                    ushort expectedResult = left * right;

                    ubyte hi = left;
                    ubyte lo = right;
                    lo = unsignedMultiplyWithDoubleWidthProduct!(ubyte, false)(lo, hi, &hi);

                    assert(((ushort(hi) << 8) | lo) == expectedResult);
                    assert(unsignedMultiplyWithDoubleWidthProduct!(ubyte, true)(left, right) == hi);

                    ++right;
                }
                while (right != 0);

                ++left;
            }
            while (left != 0);
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        pragma(inline, true)
        private I signedMultiplyWithDoubleWidthProduct(I, bool onlyHighHalf)(
            I low,
            I high,
            scope AliasSeq!(I*)[0 .. !onlyHighHalf] highProduct
        ) @trusted pure nothrow @nogc
        if (__traits(isIntegral, I) && !__traits(isUnsigned, I))
        {
            import core.bitop : bsr;

            alias UnsignedI = AliasSeq!(ubyte, ushort, uint, ulong)[I.sizeof.bsr];

            UnsignedI lo = cast(UnsignedI) low;
            UnsignedI hi = cast(UnsignedI) high;

            static if (onlyHighHalf)
            {
                hi = unsignedMultiplyWithDoubleWidthProduct!(UnsignedI, true)(lo, hi);
            }
            else
            {
                lo = unsignedMultiplyWithDoubleWidthProduct!(UnsignedI, false)(lo, hi, &hi);
            }

            hi -= high * (low < 0);
            hi -= low * (high < 0);

            static if (onlyHighHalf)
            {
                return hi;
            }
            else
            {
                *highProduct[0] = hi;
                return lo;
            }
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        @trusted pure nothrow @nogc unittest
        {
            /* The mechanics used to get a double-width product from two operands are the same regardless of the width.
               So, if this works for 8x8->16-bit multiplication, it'll work for 64x64->128-bit multiplication. */

            byte left = byte.min;
            byte right = byte.min;

            do
            {
                do
                {
                    short expectedResult = left * right;

                    byte hi = left;
                    byte lo = right;
                    lo = signedMultiplyWithDoubleWidthProduct!(byte, false)(lo, hi, &hi);

                    assert(cast(short) (((short(hi) << 8) & 0xFF00) | (lo & 0x00FF)) == expectedResult);
                    assert(signedMultiplyWithDoubleWidthProduct!(byte, true)(left, right) == hi);

                    ++right;
                }
                while (right != byte.min);

                ++left;
            }
            while (left != byte.min);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        long _div128(long highDividend, long lowDividend, long divisor, scope long* remainder) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                /* This is an amalgamation of core.int128.divmod and core.int128.neg.  */

                if (highDividend < 0)
                {
                    if (lowDividend == 0)
                    {
                        highDividend = -highDividend;
                    }
                    else
                    {
                        lowDividend = -lowDividend;
                        highDividend = ~highDividend;
                    }

                    ulong quotient;

                    if (divisor < 0)
                    {
                        quotient =  _udiv128(
                            cast(ulong) highDividend,
                            cast(ulong) lowDividend,
                            cast(ulong) -divisor,
                            cast(ulong*) remainder
                        );
                    }
                    else
                    {
                        quotient =  -_udiv128(
                            cast(ulong) highDividend,
                            cast(ulong) lowDividend,
                            cast(ulong) divisor,
                            cast(ulong*) remainder
                        );
                    }

                    *remainder = -*remainder;
                    return quotient;
                }
                else if (divisor < 0)
                {
                    return -_udiv128(
                        cast(ulong) highDividend,
                        cast(ulong) lowDividend,
                        cast(ulong) -divisor,
                        cast(ulong*) remainder
                    );
                }
                else
                {
                    return _udiv128(
                        cast(ulong) highDividend,
                        cast(ulong) lowDividend,
                        cast(ulong) divisor,
                        cast(ulong*) remainder
                    );
                }
            }
            else
            {
                version (LDC)
                {
                    import ldc.llvmasm : __ir_pure;

                    return __ir_pure!(
                        `%result = call {i64, i64} asm
                             "idiv $4",
                             "={rax},={rdx},0,1,r,~{flags}"
                             (i64 %1, i64 %0, i64 %2)

                         %quotient = extractvalue {i64, i64} %result, 0
                         %remainder = extractvalue {i64, i64} %result, 1

                         store i64 %remainder, ` ~ llvmIRPtr!"i64" ~ ` %3
                         ret i64 %quotient`,
                        long
                    )(highDividend, lowDividend, divisor, remainder);
                }
                else version (GNU)
                {
                    long quotient;
                    long remainer;

                    asm @trusted pure nothrow @nogc
                    {
                          "idiv %4"
                        : "=a" (quotient), "=d" (remainer)
                        : "0" (lowDividend), "1" (highDividend), "rm" (divisor)
                        : "cc";
                    }

                    *remainder = remainer;
                    return quotient;
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        /* RCX is highDividend; RDX is lowDividend; R8 is divisor. R9 is remainder. */
                        naked;
                        mov RAX, RDX;
                        mov RDX, RCX;
                        idiv R8;
                        mov [R9], RDX;
                        ret;
                    }
                }
            }
        }

        extern(C)
        pragma(inline, true)
        ulong _udiv128(ulong highDividend, ulong lowDividend, ulong divisor, scope ulong* remainder)
        @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                // This code was copied and adapted from core.int128.udivmod.udivmod128_64.

                import core.bitop : bsr;

                alias U = ulong;
                alias I = long;
                enum uint Ubits = 64;
                // We work in base 2^^32
                enum base = 1UL << 32;
                enum divmask = (1UL << (Ubits / 2)) - 1;
                enum divshift = Ubits / 2;

                // Check for overflow and divide by 0
                if (highDividend >= divisor)
                {
                    // The div instruction will raise a #DE exception on overflow or division-by-zero,
                    // so during CTFE we'll just assert false.
                    version (D_BetterC)
                    {
                        assert(false, "Division by zero, or an overflow of the 64-bit quotient occurred in _udiv128.");
                    }
                    else
                    {
                        import core.internal.string : unsignedToTempString;
                        assert(
                            false,
                              "Division by zero, or an overflow of the 64-bit quotient occurred in _udiv128."
                            ~ " highDividend: 0x" ~ unsignedToTempString!16(highDividend)
                            ~ "; lowDividend: 0x" ~ unsignedToTempString!16(lowDividend)
                            ~ "; divisor: 0x" ~ unsignedToTempString!16(divisor)
                        );
                    }
                }

                // Computes [num1 num0] / den
                static uint udiv96_64(U num1, uint num0, U den)
                {
                    // Extract both digits of the denominator
                    const den1 = cast(uint)(den >> divshift);
                    const den0 = cast(uint)(den & divmask);
                    // Estimate ret as num1 / den1, and then correct it
                    U ret = num1 / den1;
                    const t2 = (num1 % den1) * base + num0;
                    const t1 = ret * den0;
                    if (t1 > t2)
                        ret -= (t1 - t2 > den) ? 2 : 1;
                    return cast(uint)ret;
                }

                // Determine the normalization factor. We multiply divisor by this, so that its leading
                // digit is at least half base. In binary this means just shifting left by the number
                // of leading zeros, so that there's a 1 in the MSB.
                // We also shift number by the same amount. This cannot overflow because highDividend < divisor.
                const shift = (Ubits - 1) - bsr(divisor);
                divisor <<= shift;
                U num2 = highDividend;
                num2 <<= shift;
                num2 |= (lowDividend >> (-shift & 63)) & (-cast(I)shift >> 63);
                lowDividend <<= shift;

                // Extract the low digits of the numerator (after normalizing)
                const num1 = cast(uint)(lowDividend >> divshift);
                const num0 = cast(uint)(lowDividend & divmask);

                // Compute q1 = [num2 num1] / divisor
                const q1 = udiv96_64(num2, num1, divisor);
                // Compute the true (partial) remainder
                const rem = num2 * base + num1 - q1 * divisor;
                // Compute q0 = [rem num0] / divisor
                const q0 = udiv96_64(rem, num0, divisor);

                *remainder = (rem * base + num0 - q0 * divisor) >> shift;
                return (cast(U)q1 << divshift) | q0;
            }
            else
            {
                version (LDC)
                {
                    import ldc.llvmasm : __ir_pure;

                    return __ir_pure!(
                        `%result = call {i64, i64} asm
                             "div $4",
                             "={rax},={rdx},0,1,r,~{flags}"
                             (i64 %1, i64 %0, i64 %2)

                         %quotient = extractvalue {i64, i64} %result, 0
                         %remainder = extractvalue {i64, i64} %result, 1

                         store i64 %remainder, ` ~ llvmIRPtr!"i64" ~ ` %3
                         ret i64 %quotient`,
                        ulong
                    )(highDividend, lowDividend, divisor, remainder);
                }
                else version (GNU)
                {
                    ulong quotient;
                    ulong remainer;

                    asm @trusted pure nothrow @nogc
                    {
                          "div %4"
                        : "=a" (quotient), "=d" (remainer)
                        : "0" (lowDividend), "1" (highDividend), "rm" (divisor)
                        : "cc";
                    }

                    *remainder = remainer;
                    return quotient;
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        /* RCX is highDividend; RDX is lowDividend; R8 is divisor. R9 is remainder. */
                        naked;
                        mov RAX, RDX;
                        mov RDX, RCX;
                        div R8;
                        mov [R9], RDX;
                        ret;
                    }
                }
            }
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        int _div64(long dividend, int divisor, scope int* remainder) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                if (((dividend < 0 ? -dividend : dividend) >>> 32) >= (divisor < 0 ? -divisor : divisor))
                {
                    /* The div instruction will raise a #DE exception on overflow or division-by-zero,
                       so during CTFE we'll just assert false. */
                    version (D_BetterC)
                    {
                        assert(false, "Division by zero, or an overflow of the 32-bit quotient occurred in _div64.");
                    }
                    else
                    {
                        import core.internal.string : signedToTempString;
                        assert(
                            false,
                              "Division by zero, or an overflow of the 32-bit quotient occurred in _div64."
                            ~ " dividend: " ~ signedToTempString(dividend)
                            ~ "; divisor: " ~ signedToTempString(divisor)
                        );
                    }
                }

                *remainder = cast(int) (dividend % divisor);
                return cast(int) (dividend / divisor);
            }
            else
            {
                version (LDC)
                {
                    import ldc.llvmasm : __ir_pure;

                    return __ir_pure!(
                        `%result = call {i32, i32} asm
                             "idiv $4",
                             "={eax},={edx},0,1,r,~{flags}"
                             (i32 %1, i32 %0, i32 %2)

                         %quotient = extractvalue {i32, i32} %result, 0
                         %remainder = extractvalue {i32, i32} %result, 1

                         store i32 %remainder, ` ~ llvmIRPtr!"i32" ~ ` %3
                         ret i32
                          %quotient`,
                        int
                    )(cast(int) (dividend >>> 32), cast(int) (dividend & 0xFFFFFFFF), divisor, remainder);
                }
                else version (GNU)
                {
                    int quotient;
                    int remainer;

                    asm @trusted pure nothrow @nogc
                    {
                          "idiv %4"
                        : "=a" (quotient), "=d" (remainer)
                        : "0" (cast(int) (dividend & 0xFFFFFFFF)), "1" (cast(int) (dividend >>> 32)), "rm" (divisor)
                        : "cc";
                    }

                    *remainder = remainer;
                    return quotient;
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        /* RCX is dividend; EDX is divisor; R8 is remainder. */
                        naked;
                        mov R9D, EDX;
                        mov RDX, RCX;
                        shr RDX, 32;
                        mov EAX, ECX;
                        idiv R9D;
                        mov [R8], EDX;
                        ret;
                    }
                }
                else version (D_InlineAsm_X86)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        mov EAX, [ESP + 4]; /* Low half of dividend. */
                        mov EDX, [ESP + 8]; /* High half of dividend. */
                        idiv dword ptr [ESP + 12]; /* [ESP + 12] is divisor. */
                        mov ECX, [ESP + 16]; /* remainder. */
                        mov [ECX], EDX;
                        ret;
                    }
                }
            }
        }

        extern(C)
        pragma(inline, true)
        uint _udiv64(ulong dividend, uint divisor, scope uint* remainder) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                if ((dividend >>> 32) >= divisor)
                {
                    /* The div instruction will raise a #DE exception on overflow or division-by-zero,
                       so during CTFE we'll just assert false. */
                    version (D_BetterC)
                    {
                        assert(false, "Division by zero, or an overflow of the 32-bit quotient occurred in _udiv64.");
                    }
                    else
                    {
                        import core.internal.string : unsignedToTempString;
                        assert(
                            false,
                              "Division by zero, or an overflow of the 32-bit quotient occurred in _udiv64."
                            ~ " dividend: " ~ unsignedToTempString(dividend)
                            ~ "; divisor: " ~ unsignedToTempString(divisor)
                        );
                    }
                }

                *remainder = cast(uint) (dividend % divisor);
                return cast(uint) (dividend / divisor);
            }
            else
            {
                version (LDC)
                {
                    import ldc.llvmasm : __ir_pure;

                    return __ir_pure!(
                        `%result = call {i32, i32} asm
                             "div $4",
                             "={eax},={edx},0,1,r,~{flags}"
                             (i32 %1, i32 %0, i32 %2)

                         %quotient = extractvalue {i32, i32} %result, 0
                         %remainder = extractvalue {i32, i32} %result, 1

                         store i32 %remainder, ` ~ llvmIRPtr!"i32" ~ ` %3
                         ret i32
                          %quotient`,
                        uint
                    )(uint(dividend >>> 32), uint(dividend & 0xFFFFFFFF), divisor, remainder);
                }
                else version (GNU)
                {
                    uint quotient;
                    uint remainer;

                    asm @trusted pure nothrow @nogc
                    {
                          "div %4"
                        : "=a" (quotient), "=d" (remainer)
                        : "0" (uint(dividend & 0xFFFFFFFF)), "1" (uint(dividend >>> 32)), "rm" (divisor)
                        : "cc";
                    }

                    *remainder = remainer;
                    return quotient;
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        /* RCX is dividend; EDX is divisor; R8 is remainder. */
                        naked;
                        mov R9D, EDX;
                        mov RDX, RCX;
                        shr RDX, 32;
                        mov EAX, ECX;
                        div R9D;
                        mov [R8], EDX;
                        ret;
                    }
                }
                else version (D_InlineAsm_X86)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        mov EAX, [ESP + 4]; /* Low half of dividend. */
                        mov EDX, [ESP + 8]; /* High half of dividend. */
                        div dword ptr [ESP + 12]; /* [ESP + 12] is divisor. */
                        mov ECX, [ESP + 16]; /* remainder. */
                        mov [ECX], EDX;
                        ret;
                    }
                }
            }
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static bool test()
        {
            version (X86_64)
            {
                {
                    ulong remainder;
                    assert(_udiv128(0x0000CAFE, 0x00F00D00, 1 << 16, &remainder) == 0xCAFE0000_000000F0);
                    assert(remainder == (0x00F00D00 & ((1 << 16) - 1)));
                    assert(_udiv128(0x0000CAFE, 0x00F00D00 + (1 << 16), 1 << 16, &remainder) == 0xCAFE0000_000000F1);
                    assert(remainder == (0x00F00D00 & ((1 << 16) - 1)));
                }

                {
                    long remainder;
                    assert(_div128(0, 9, 4, &remainder) == 2);
                    assert(remainder == 1);
                    assert(_div128(0, 9, -4, &remainder) == -2);
                    assert(remainder == 1);
                    assert(_div128(-1, -9, 4, &remainder) == -2);
                    assert(remainder == -1);
                    assert(_div128(-1, -9, -4, &remainder) == 2);
                    assert(remainder == -1);
                    assert(_div128(0x00004AFE, 0x00F10D00, 1 << 16, &remainder) == 0x4AFE0000_000000F1);
                    assert(remainder == (0x00F10D00 & ((1 << 16) - 1)));
                }
            }

            version (X86_64_Or_X86)
            {
                {
                    uint remainder;
                    assert(_udiv64(9, 4, &remainder) == 2);
                    assert(remainder == 1);
                    assert(_udiv64(0x0000CAFE_00001234, 1 << 16, &remainder) == 0x00000000_CAFE0000);
                    assert(remainder == (0x0000CAFE_00001234 & ((1 << 16) - 1)));
                }

                {
                    int remainder;
                    assert(_div64(9, 4, &remainder) == 2);
                    assert(remainder == 1);
                    assert(_div64(9, -4, &remainder) == -2);
                    assert(remainder == 1);
                    assert(_div64(-9, 4, &remainder) == -2);
                    assert(remainder == -1);
                    assert(_div64(-9, -4, &remainder) == 2);
                    assert(remainder == -1);
                    assert(_div64(0x00004AFE_00011234, 1 << 16, &remainder) == 0x00000000_4AFE0001);
                    assert(remainder == (0x00004AFE_00011234 & ((1 << 16) - 1)));
                }
            }

            return true;
        }

        assert(test());
        static assert(test());

        enum bool errorOccursDuringCTFE(alias symbol, T, T divisor) = !__traits(
            compiles,
            ()
            {
                T remainder;
                enum result = symbol(0x0000CAFE, 0x00F00D00, divisor, &remainder);
            }
        );

        version (X86_64)
        {
            /* An error should occur when attempting to divide by zero. */
            static assert(errorOccursDuringCTFE!(_udiv128, ulong, 0));
            static assert(errorOccursDuringCTFE!(_div128, long, 0));
            /* And, when when the quotient overflows 64-bits. */
            static assert(errorOccursDuringCTFE!(_udiv128, ulong, 2));
            static assert(errorOccursDuringCTFE!(_div128, long, 2));
        }

        version (X86_64_Or_X86)
        {
            /* An error should occur when attempting to divide by zero. */
            static assert(errorOccursDuringCTFE!(_udiv64, uint, 0));
            static assert(errorOccursDuringCTFE!(_div64, int, 0));
            /* And, when when the quotient overflows 64-bits. */
            static assert(errorOccursDuringCTFE!(_udiv64, uint, 2));
            static assert(errorOccursDuringCTFE!(_div64, int, 2));
        }
    }
}
