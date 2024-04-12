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

             version (X86_64_Or_X86) private enum gccBuiltins = "ldc.gccbuiltins_x86";
        else version (ARM) private enum gccBuiltins = "ldc.gccbuiltins_arm";
        else version (AArch64) private enum gccBuiltins = "ldc.gccbuiltins_aarch64";
    }
    else version (GNU)
    {
        version = LDC_Or_GNU;

        private enum gccBuiltins = "gcc.builtins";
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

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        void __cpuid(scope int[4]* cpuInfo, int function_id) @safe pure nothrow @nogc
        {
            cpuID(cpuInfo, function_id);
        }

        extern(C)
        pragma(inline, true)
        void __cpuidex(scope int[4]* cpuInfo, int function_id, int subfunction_id) @safe pure nothrow @nogc
        {
            cpuID(cpuInfo, function_id, subfunction_id);
        }

        extern(C)
        pragma(inline, true)
        private void cpuID(Args...)(scope int[4]* cpuInfo, int function_id, Args args) @safe pure nothrow @nogc
        if (Args.length == 0 || (Args.length == 1 && is(Args[0] == int)))
        {
            version (LDC_Or_GNU)
            {
                asm @trusted pure nothrow @nogc
                {
                      "cpuid"
                    : "=a" ((*cpuInfo)[0]), "=b" ((*cpuInfo)[1]), "=c" ((*cpuInfo)[2]), "=d" ((*cpuInfo)[3])
                    : "0" (function_id), "2" (mixin(Args.length == 0 ? q{0} : q{args[0]}));
                }
            }
            else version (InlineAsm_X86_64_Or_X86)
            {
                version (D_InlineAsm_X86_64)
                {
                    mixin(
                        "asm @trusted pure nothrow @nogc
                         {
                             /* RCX is cpuInfo; EDX is function_id;
                                R8D is subfunction_id (args[0]), if it's present. */
                             naked;
                             mov R9, RCX; /* Save the cpuInfo pointer before cpuid clobbers RCX. */
                             mov EAX, EDX;
                             " ~ (Args.length == 0 ? "xor ECX, ECX" : "mov ECX, R8D") ~ ";
                             mov R10, RBX; /* RBX is non-volatile so we save it before cpuid clobbers it. */
                             cpuid;
                             mov [R9], EAX;
                             mov [R9 +  4], EBX;
                             mov [R9 +  8], ECX;
                             mov [R9 + 12], EDX;
                             mov RBX, R10;
                             ret;
                         }"
                    );
                }
                else version (D_InlineAsm_X86)
                {
                    mixin(
                        "asm @trusted pure nothrow @nogc
                         {
                             naked;
                             push EBX; /* EBX is non-volatile so we save it before cpuid clobbers it. */
                             push ESI; /* ESI is non-volatile so we save it before we clobber it. */
                             mov EAX, [ESP + 16]; /* function_id. */
                             mov ESI, [ESP + 12]; /* cpuInfo. */
                            " ~ (Args.length == 0 ? "xor ECX, ECX" : "mov ECX, [ESP + 20] /* subfunction_id */") ~ ";
                             cpuid;
                             mov [ESI], EAX;
                             mov [ESI +  4], EBX;
                             mov [ESI +  8], ECX;
                             mov [ESI + 12], EDX;
                             pop ESI;
                             pop EBX;
                             ret;
                         }"
                    );
                }
            }
            else
            {
                static assert(false);
            }
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        @trusted pure nothrow @nogc unittest
        {
            import core.cpuid : vendor;

            scope int[4] values = 0x18181818;

            char[12] manufacturer()
            {
                typeof(return) characters;
                characters[0 ..  4] = *cast(const(char)[4]*) &values[1];
                characters[4 ..  8] = *cast(const(char)[4]*) &values[3];
                characters[8 .. 12] = *cast(const(char)[4]*) &values[2];
                return characters;
            }

            __cpuid(&values, 0);
            assert(manufacturer == vendor);

            values = 0x18181818;
            __cpuidex(&values, 0, 0);
            assert(manufacturer == vendor);

            if (values[0] < 7)
            {
                return;
            }

            __cpuidex(&values, 7, 0);

            if (values[0] < 1)
            {
                return;
            }

            /* Is the subfunction_id being used? Or, is __cpuidex mistakenly ignoring it? Let's test. */
            scope oldValues = values;
            __cpuidex(&values, 7, 1);
            assert(values != oldValues);
        }
    }

    version (X86_64_Or_X86)
    {
        private enum float twoExp31Float = 2147483648.0f;
        private enum float twoExp32Float = 4294967296.0f;
        private enum float twoExp63Float = 9223372036854775808.0f;
        private enum float twoExp64Float = 18446744073709551616.0f;
        private enum double twoExp31Double = 2147483648.0;
        private enum double twoExp32Double = 4294967296.0;
        private enum double twoExp63Double = 9223372036854775808.0;
        private enum double twoExp64Double = 18446744073709551616.0;
        private enum float justUnderTwoExp63Float = 9223371487098961920.0f;
        private enum double justUnderTwoExp63Double = 9223371487098961920.0f;

        version (LDC_Or_GNU)
        {}
        else version (InlineAsm_X86_64_Or_X86)
        {
            private static immutable float twoExp31FloatInstance = twoExp31Float;
            private static immutable float twoExp63FloatInstance = twoExp63Float;
            private static immutable double twoExp31DoubleInstance = twoExp31Double;
            private static immutable double twoExp63DoubleInstance = twoExp63Double;
        }

        extern(C)
        pragma(inline, true)
        int _cvt_ftoi_fast(float value) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                if (value < twoExp31Float && value >= -twoExp31Float)
                {
                    return cast(int) value;
                }

                return 0x80000000;
            }
            else
            {
                version (LDC_Or_GNU)
                {
                    mixin(q{import }, gccBuiltins, q{ : __builtin_ia32_cvttss2si;});

                    return __builtin_ia32_cvttss2si(value);
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        cvttss2si EAX, XMM0;
                        ret;
                    }
                }
                else version (D_InlineAsm_X86)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        cvttss2si EAX, [ESP + 4];
                        ret;
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoi_fast(0.0f) == 0);
                assert(_cvt_ftoi_fast(-0.0f) == 0);
                assert(_cvt_ftoi_fast(float.nan) == 0x80000000);
                assert(_cvt_ftoi_fast(-float.nan) == 0x80000000);
                assert(_cvt_ftoi_fast(float.infinity) == 0x80000000);
                assert(_cvt_ftoi_fast(-float.infinity) == 0x80000000);
                assert(_cvt_ftoi_fast(1.0f) == 1);
                assert(_cvt_ftoi_fast(-1.0f) == -1);
                assert(_cvt_ftoi_fast(2.5f) == 2);
                assert(_cvt_ftoi_fast(-2.5f) == -2);
                assert(_cvt_ftoi_fast(3.5f) == 3);
                assert(_cvt_ftoi_fast(-3.5f) == -3);
                assert(_cvt_ftoi_fast(3.49f) == 3);
                assert(_cvt_ftoi_fast(-3.49f) == -3);
                assert(_cvt_ftoi_fast(twoExp31Float) == 0x80000000);
                assert(_cvt_ftoi_fast(-twoExp31Float) == int.min);
                assert(_cvt_ftoi_fast(twoExp63Float) == 0x80000000);
                assert(_cvt_ftoi_fast(-twoExp63Float) == int.min);
                assert(_cvt_ftoi_fast(justUnderTwoExp63Float) == int.min);
                assert(_cvt_ftoi_fast(33554432.0f) == 33554432);
                assert(_cvt_ftoi_fast(-33554432.0f) == -33554432);
                assert(_cvt_ftoi_fast(33554436.0f) == 33554436);
                assert(_cvt_ftoi_fast(-33554436.0f) == -33554436);
                assert(_cvt_ftoi_fast(70369281048576.0f) == 0x80000000);
                assert(_cvt_ftoi_fast(-70369281048576.0f) == 0x80000000);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        long _cvt_ftoll_fast(float value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                if (__ctfe)
                {
                    if (value < twoExp63Float && value >= -twoExp63Float)
                    {
                        return cast(long) value;
                    }

                    return 0x80000000_00000000;
                }
                else
                {
                    version (LDC_Or_GNU)
                    {
                        mixin(q{import }, gccBuiltins, q{ : __builtin_ia32_cvttss2si64;});

                        return __builtin_ia32_cvttss2si64(value);
                    }
                    else version (D_InlineAsm_X86_64)
                    {
                        enum ubyte REX_W = 0b0100_1000;
                        enum ubyte RAX_XMM0 = 0b11_000_000;

                        asm @trusted pure nothrow @nogc
                        {
                            naked;
                            /* DMD refuses to encode `cvttss2si RAX, XMM0`, so we'll encode it by hand. */
                            db 0xF3, REX_W, 0x0F, 0x2C, RAX_XMM0; /* cvttss2si RAX, XMM0 */
                            ret;
                        }
                    }
                }
            }
            else version (X86)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Float && value >= -twoExp31Float)
                {
                    return _cvt_ftoi_fast(value);
                }

                /* At this point, the exponent is at-least 31, and the value may be an infinity or NaN.
                   We care about being correct for values with only an exponent less-than 63,
                   which excludes infinities and NaNs, because that's how the MSVC intrinsic behaves.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                int asInt = *(cast(const(int)*) &value);

                uint sign = asInt >> 31;
                assert(sign == 0 || sign == -1);

                bool isNaN = (asInt & 0b0_11111111_11111111111111111111111) > 0b0_11111111_00000000000000000000000;

                if (isNaN)
                {
                    /* The MSVC intrinsic converts signalling NaNs to quiet NaNs, and this is observable
                       in the returned value, so we do the same.  */
                    asInt |= (1 << 22);
                }

                /* The exponent is biased by +127, but we subtract only 126 as we want the exponent
                   to be one-higher than it actually is, so that we shift the correct number of bits
                   after we mask the exponent by 31.
                   E.g. with an exponent of 31 we should shift 0 bits, 32 should shift 1 bit, etc.. */
                byte exponent = cast(byte) ((cast(ubyte) (asInt >>> 23)) - 126);
                assert(exponent <= -127 || exponent >= 32);

                /* We have 23-bits stored for the significand, and we know that the exponent is
                   at-least 31, which means that we can shift left unconditionally by 8, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit.
                   Conveniently, this means that the variable shifting for the exponent concerns only
                   the high half (remember that this is for 32-bit mode). */
                uint unadjustedSignificand = (asInt << 8) | (1 << 31);

                /* If the sign bit is set, we need to negate the significand; we can do that branchlessly
                   by taking advantage of the fact that `sign` is either 0 or -1.
                   As `(s ^ 0) - 0 == s`, whereas `(s ^ -1) - -1 == -s`. */
                uint significand = (unadjustedSignificand ^ sign) - sign;
                assert(sign == 0 ? significand == unadjustedSignificand : significand == -unadjustedSignificand);

                uint highHalf = funnelShiftLeft(significand, sign, exponent & 31);

                return (ulong(highHalf) << 32) | ulong(significand << (exponent & 31));
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoll_fast(0.0f) == 0);
                assert(_cvt_ftoll_fast(-0.0f) == 0);
                assert(_cvt_ftoll_fast(1.0f) == 1);
                assert(_cvt_ftoll_fast(-1.0f) == -1);
                assert(_cvt_ftoll_fast(2.5f) == 2);
                assert(_cvt_ftoll_fast(-2.5f) == -2);
                assert(_cvt_ftoll_fast(3.5f) == 3);
                assert(_cvt_ftoll_fast(-3.5f) == -3);
                assert(_cvt_ftoll_fast(3.49f) == 3);
                assert(_cvt_ftoll_fast(-3.49f) == -3);
                assert(_cvt_ftoll_fast(twoExp31Float) == 2147483648);
                assert(_cvt_ftoll_fast(-twoExp31Float) == -2147483648);
                assert(_cvt_ftoll_fast(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_ftoll_fast(33554432.0f) == 33554432);
                assert(_cvt_ftoll_fast(-33554432.0f) == -33554432);
                assert(_cvt_ftoll_fast(33554436.0f) == 33554436);
                assert(_cvt_ftoll_fast(-33554436.0f) == -33554436);
                assert(_cvt_ftoll_fast(70369281048576.0f) == 70369281048576);
                assert(_cvt_ftoll_fast(-70369281048576.0f) == -70369281048576);

                version (X86_64)
                {
                    assert(_cvt_ftoll_fast(float.nan) == -9223372036854775808);
                    assert(_cvt_ftoll_fast(-float.nan) == -9223372036854775808);
                    assert(_cvt_ftoll_fast(float.infinity) == -9223372036854775808);
                    assert(_cvt_ftoll_fast(-float.infinity) == -9223372036854775808);
                    assert(_cvt_ftoll_fast(twoExp63Float) == -9223372036854775808);
                    assert(_cvt_ftoll_fast(-twoExp63Float) == -9223372036854775808);
                }
                else version (X86)
                {
                    assert(_cvt_ftoll_fast(float.nan) == 6442450944);
                    assert(_cvt_ftoll_fast(-float.nan) == -6442450944);
                    assert(_cvt_ftoll_fast(float.infinity) == 4294967296);
                    assert(_cvt_ftoll_fast(-float.infinity) == -4294967296);
                    assert(_cvt_ftoll_fast(twoExp63Float) == 2147483648);
                    assert(_cvt_ftoll_fast(-twoExp63Float) == -2147483648);
                }

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        uint _cvt_ftoui_fast(float value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                return cast(uint) _cvt_ftoll_fast(value);
            }
            else version (X86)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Float || value != value)
                {
                    return cast(uint) _cvt_ftoi_fast(value);
                }

                /* At this point, the exponent is at-least 31, and the value may be an infinity or NaN.
                   We care about being correct for values with only an exponent of 31,
                   which excludes infinities and NaNs, because that's how the MSVC intrinsic behaves.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                /* We have 23-bits stored for the significand, and we know that the exponent is
                   at-least 31, and we only care about being correct for an exponent of 31,
                   which means that we can just shift left unconditionally by 8, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit. */
                return (*(cast(const(uint)*) &value) << 8) | (1 << 31);
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoui_fast(0.0f) == 0);
                assert(_cvt_ftoui_fast(-0.0f) == 0);
                assert(_cvt_ftoui_fast(1.0f) == 1);
                assert(_cvt_ftoui_fast(-1.0f) == 4294967295);
                assert(_cvt_ftoui_fast(2.5f) == 2);
                assert(_cvt_ftoui_fast(-2.5f) == 4294967294);
                assert(_cvt_ftoui_fast(3.5f) == 3);
                assert(_cvt_ftoui_fast(-3.5f) == 4294967293);
                assert(_cvt_ftoui_fast(3.49f) == 3);
                assert(_cvt_ftoui_fast(-3.49f) == 4294967293);
                assert(_cvt_ftoui_fast(twoExp31Float) == 2147483648);
                assert(_cvt_ftoui_fast(-twoExp31Float) == 2147483648);
                assert(_cvt_ftoui_fast(33554432.0f) == 33554432);
                assert(_cvt_ftoui_fast(-33554432.0f) == 4261412864);
                assert(_cvt_ftoui_fast(33554436.0f) == 33554436);
                assert(_cvt_ftoui_fast(-33554436.0f) == 4261412860);

                version (X86_64)
                {
                    assert(_cvt_ftoui_fast(twoExp63Float) == 0);
                    assert(_cvt_ftoui_fast(-twoExp63Float) == 0);
                    assert(_cvt_ftoui_fast(justUnderTwoExp63Float) == 0);
                    assert(_cvt_ftoui_fast(float.nan) == 0);
                    assert(_cvt_ftoui_fast(-float.nan) == 0);
                    assert(_cvt_ftoui_fast(float.infinity) == 0);
                    assert(_cvt_ftoui_fast(-float.infinity) == 0);
                    assert(_cvt_ftoui_fast(70369281048576.0f) == 536870912);
                    assert(_cvt_ftoui_fast(-70369281048576.0f) == 3758096384);
                }
                else version (X86)
                {
                    assert(_cvt_ftoui_fast(twoExp63Float) == 2147483648);
                    assert(_cvt_ftoui_fast(-twoExp63Float) == 2147483648);
                    assert(_cvt_ftoui_fast(justUnderTwoExp63Float) == 4294967040);
                    assert(_cvt_ftoui_fast(float.nan) == 2147483648);
                    assert(_cvt_ftoui_fast(-float.nan) == 2147483648);
                    assert(_cvt_ftoui_fast(float.infinity) == 2147483648);
                    assert(_cvt_ftoui_fast(-float.infinity) == 2147483648);
                    assert(_cvt_ftoui_fast(70369281048576.0f) == 2147500032);
                    assert(_cvt_ftoui_fast(-70369281048576.0f) == 2147483648);
                }

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        ulong _cvt_ftoull_fast(float value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp63Float || value != value)
                {
                    return cast(ulong) _cvt_ftoll_fast(value);
                }

                /* At this point, the exponent is at-least 63, and the value may be an infinity or NaN.
                   We care about being correct for values with only an exponent of 63,
                   which excludes infinities and NaNs, because that's how the MSVC intrinsic behaves.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                /* We have 23-bits stored for the significand, and we know that the exponent is
                   at-least 63, and we only care about being correct for an exponent of 63,
                   which means that we can just shift left unconditionally by 40, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit. */
                return (ulong(*(cast(const(uint)*) &value)) << 40) | (ulong(1) << 63);
            }
            else version (X86)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Float || value != value)
                {
                    return cast(ulong) cast(uint) _cvt_ftoi_fast(value);
                }

                /* At this point, the exponent is at-least 31, and the value may be an infinity or NaN.
                   We care about being correct for values with only an exponent less-than 64,
                   which excludes infinities and NaNs, because that's how the MSVC intrinsic behaves.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                int asInt = *(cast(const(int)*) &value);

                /* The exponent is biased by +127, but we subtract only 126 as we want the exponent
                   to be one-higher than it actually is, so that we shift the correct number of bits
                   after we mask the exponent by 31.
                   E.g. with an exponent of 31 we should shift 0 bits, 32 should shift 1 bit, etc.. */
                byte exponent = cast(byte) ((cast(ubyte) (asInt >>> 23)) - 126);
                assert(exponent <= -127 || exponent >= 32);

                /* We have 23-bits stored for the significand, and we know that the exponent is
                   at-least 31, which means that we can shift left unconditionally by 8, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit.
                   Conveniently, this means that the variable shifting for the exponent concerns only
                   the high half (remember that this is for 32-bit mode). */
                uint significand = (asInt << 8) | (1 << 31);

                return ulong(significand) << (exponent == 64 ? 32 : (exponent & 31));
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoull_fast(0.0f) == 0);
                assert(_cvt_ftoull_fast(-0.0f) == 0);
                assert(_cvt_ftoull_fast(1.0f) == 1);
                assert(_cvt_ftoull_fast(2.5f) == 2);
                assert(_cvt_ftoull_fast(3.5f) == 3);
                assert(_cvt_ftoull_fast(3.49f) == 3);
                assert(_cvt_ftoull_fast(twoExp31Float) == 2147483648);
                assert(_cvt_ftoull_fast(twoExp63Float) == 9223372036854775808);
                assert(_cvt_ftoull_fast(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_ftoull_fast(33554432.0f) == 33554432);
                assert(_cvt_ftoull_fast(33554436.0f) == 33554436);
                assert(_cvt_ftoull_fast(70369281048576.0f) == 70369281048576);

                version (X86_64)
                {
                    assert(_cvt_ftoull_fast(-1.0f) == 18446744073709551615);
                    assert(_cvt_ftoull_fast(-2.5f) == 18446744073709551614);
                    assert(_cvt_ftoull_fast(-3.5f) == 18446744073709551613);
                    assert(_cvt_ftoull_fast(-3.49f) == 18446744073709551613);
                    assert(_cvt_ftoull_fast(-twoExp31Float) == 18446744071562067968);
                    assert(_cvt_ftoull_fast(-twoExp63Float) == 9223372036854775808);
                    assert(_cvt_ftoull_fast(float.nan) == 9223372036854775808);
                    assert(_cvt_ftoull_fast(-float.nan) == 9223372036854775808);
                    assert(_cvt_ftoull_fast(float.infinity) == 9223372036854775808);
                    assert(_cvt_ftoull_fast(-float.infinity) == 9223372036854775808);
                    assert(_cvt_ftoull_fast(-33554432.0f) == 18446744073675997184);
                    assert(_cvt_ftoull_fast(-33554436.0f) == 18446744073675997180);
                    assert(_cvt_ftoull_fast(-70369281048576.0f) == 18446673704428503040);
                }
                else version (X86)
                {
                    assert(_cvt_ftoull_fast(-1.0f) == 4294967295);
                    assert(_cvt_ftoull_fast(-2.5f) == 4294967294);
                    assert(_cvt_ftoull_fast(-3.5f) == 4294967293);
                    assert(_cvt_ftoull_fast(-3.49f) == 4294967293);
                    assert(_cvt_ftoull_fast(-twoExp31Float) == 2147483648);
                    assert(_cvt_ftoull_fast(-twoExp63Float) == 2147483648);
                    assert(_cvt_ftoull_fast(float.nan) == 2147483648);
                    assert(_cvt_ftoull_fast(-float.nan) == 2147483648);
                    assert(_cvt_ftoull_fast(float.infinity) == 4294967296);
                    assert(_cvt_ftoull_fast(-float.infinity) == 2147483648);
                    assert(_cvt_ftoull_fast(-33554432.0f) == 4261412864);
                    assert(_cvt_ftoull_fast(-33554436.0f) == 4261412860);
                    assert(_cvt_ftoull_fast(-70369281048576.0f) == 2147483648);
                }

                return true;
            }

            assert(test());
            static assert(test());
        }

        extern(C)
        pragma(inline, true)
        int _cvt_dtoi_fast(double value) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                if (value < twoExp31Double && value >= -twoExp31Double)
                {
                    return cast(int) value;
                }

                return 0x80000000;
            }
            else
            {
                version (LDC_Or_GNU)
                {
                    mixin(q{import }, gccBuiltins, q{ : __builtin_ia32_cvttsd2si;});

                    return __builtin_ia32_cvttsd2si(value);
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        cvttsd2si EAX, XMM0;
                        ret;
                    }
                }
                else version (D_InlineAsm_X86)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        cvttsd2si EAX, [ESP + 4];
                        ret;
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoi_fast(0.0) == 0);
                assert(_cvt_dtoi_fast(-0.0) == 0);
                assert(_cvt_dtoi_fast(float.nan) == -2147483648);
                assert(_cvt_dtoi_fast(-float.nan) == -2147483648);
                assert(_cvt_dtoi_fast(float.infinity) == -2147483648);
                assert(_cvt_dtoi_fast(-float.infinity) == -2147483648);
                assert(_cvt_dtoi_fast(1.0) == 1);
                assert(_cvt_dtoi_fast(-1.0) == -1);
                assert(_cvt_dtoi_fast(2.5) == 2);
                assert(_cvt_dtoi_fast(-2.5) == -2);
                assert(_cvt_dtoi_fast(3.5) == 3);
                assert(_cvt_dtoi_fast(-3.5) == -3);
                assert(_cvt_dtoi_fast(3.49) == 3);
                assert(_cvt_dtoi_fast(-3.49) == -3);
                assert(_cvt_dtoi_fast(twoExp31Float) == -2147483648);
                assert(_cvt_dtoi_fast(-twoExp31Float) == -2147483648);
                assert(_cvt_dtoi_fast(twoExp63Float) == -2147483648);
                assert(_cvt_dtoi_fast(-twoExp63Float) == -2147483648);
                assert(_cvt_dtoi_fast(justUnderTwoExp63Float) == -2147483648);
                assert(_cvt_dtoi_fast(33554432.0) == 33554432);
                assert(_cvt_dtoi_fast(-33554432.0) == -33554432);
                assert(_cvt_dtoi_fast(33554436.0) == 33554436);
                assert(_cvt_dtoi_fast(-33554436.0) == -33554436);
                assert(_cvt_dtoi_fast(70369281048576.0) == -2147483648);
                assert(_cvt_dtoi_fast(-70369281048576.0) == -2147483648);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        long _cvt_dtoll_fast(double value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                if (__ctfe)
                {
                    if (value < twoExp63Double && value >= -twoExp63Double)
                    {
                        return cast(long) value;
                    }

                    return 0x80000000_00000000;
                }
                else
                {
                    version (LDC_Or_GNU)
                    {
                        mixin(q{import }, gccBuiltins, q{ : __builtin_ia32_cvttsd2si64;});

                        return __builtin_ia32_cvttsd2si64(value);
                    }
                    else version (D_InlineAsm_X86_64)
                    {
                        enum ubyte REX_W = 0b0100_1000;
                        enum ubyte RAX_XMM0 = 0b11_000_000;

                        asm @trusted pure nothrow @nogc
                        {
                            naked;
                            /* DMD refuses to encode `cvttsd2si RAX, XMM0`, so we'll encode it by hand. */
                            db 0xF2, REX_W, 0x0F, 0x2C, RAX_XMM0; /* cvttsd2si RAX, XMM0 */
                            ret;
                        }
                    }
                }
            }
            else version (X86)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Double && value >= -twoExp31Double)
                {
                    return _cvt_dtoi_fast(value);
                }

                /* At this point, the exponent is at-least 31, and the value may be an infinity or NaN.
                   We care about being correct for values with only an exponent less-than 63,
                   which excludes infinities and NaNs, because that's how the MSVC intrinsic behaves. */

                long asInt = *(cast(const(long)*) &value);

                uint high = cast(uint) (asInt >>> 32);
                uint low = cast(uint) asInt;

                long sign = (cast(int) high) >> 31;
                assert(sign == 0 || sign == -1);

                int exponent = ((high >>> 20) & 2047) - 1023;
                /* NaNs and infinity exponents will result in 1024, whereas numeric exponents will be at-least 31. */
                assert(exponent >= 31);

                /* When the value is an infinity or NaN, the MSVC intrinsic always negates the significand. */
                if (exponent == 1024)
                {
                    sign = -1;
                }

                ulong significand = (ulong((high & 0b00000000_00001111_11111111_11111111) | (1 << 20)) << 32) | low;
                uint shiftCount = (exponent < 52 ? 52 : exponent) - (exponent < 52 ? exponent : 52);

                if (exponent < 52)
                {
                    significand >>>= (shiftCount & 31);
                }
                else
                {
                    significand <<= (shiftCount & 31);
                }

                /* If the sign bit is set, we need to negate the significand; we can do that branchlessly
                   by taking advantage of the fact that `sign` is either 0 or -1.
                   As `(s ^ 0) - 0 == s`, whereas `(s ^ -1) - -1 == -s`. */
                ulong adjustedSignificand = (significand ^ sign) - sign;
                assert(sign == 0 ? adjustedSignificand == significand : adjustedSignificand == -significand);

                return adjustedSignificand;
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoll_fast(0.0) == 0);
                assert(_cvt_dtoll_fast(-0.0) == 0);
                assert(_cvt_dtoll_fast(float.nan) == -9223372036854775808);
                assert(_cvt_dtoll_fast(-float.nan) == -9223372036854775808);
                assert(_cvt_dtoll_fast(1.0) == 1);
                assert(_cvt_dtoll_fast(-1.0) == -1);
                assert(_cvt_dtoll_fast(2.5) == 2);
                assert(_cvt_dtoll_fast(-2.5) == -2);
                assert(_cvt_dtoll_fast(3.5) == 3);
                assert(_cvt_dtoll_fast(-3.5) == -3);
                assert(_cvt_dtoll_fast(3.49) == 3);
                assert(_cvt_dtoll_fast(-3.49) == -3);
                assert(_cvt_dtoll_fast(twoExp31Float) == 2147483648);
                assert(_cvt_dtoll_fast(-twoExp31Float) == -2147483648);
                assert(_cvt_dtoll_fast(twoExp63Float) == -9223372036854775808);
                assert(_cvt_dtoll_fast(-twoExp63Float) == -9223372036854775808);
                assert(_cvt_dtoll_fast(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_dtoll_fast(33554432.0) == 33554432);
                assert(_cvt_dtoll_fast(-33554432.0) == -33554432);
                assert(_cvt_dtoll_fast(33554436.0) == 33554436);
                assert(_cvt_dtoll_fast(-33554436.0) == -33554436);
                assert(_cvt_dtoll_fast(70369281048576.0) == 70369281048576);
                assert(_cvt_dtoll_fast(-70369281048576.0) == -70369281048576);

                version (X86_64)
                {
                    assert(_cvt_dtoll_fast(float.infinity) == -9223372036854775808);
                    assert(_cvt_dtoll_fast(-float.infinity) == -9223372036854775808);
                }
                else version (X86)
                {
                    assert(_cvt_dtoll_fast(float.infinity) == 0);
                    assert(_cvt_dtoll_fast(-float.infinity) == 0);
                }

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        uint _cvt_dtoui_fast(double value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                return cast(uint) _cvt_dtoll_fast(value);
            }
            else version (X86)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Double || value != value)
                {
                    return cast(uint) _cvt_dtoi_fast(value);
                }

                /* At this point, the exponent is at-least 31, and the value may be an infinity or NaN.
                   We care about being correct for values with only an exponent of 31,
                   which excludes infinities and NaNs, because that's how the MSVC intrinsic behaves. */

                /* We have 52-bits stored for the significand, and we know that the exponent is
                   at-least 31, and we only care about being correct for an exponent of 31,
                   which means that we can just shift left unconditionally by 21 (52 - 31), which leaves
                   the implicit bit of the full 53-bit significand to be set at the most-significant bit. */
                return cast(uint) (*(cast(const(ulong)*) &value) >>> 21) | (1 << 31);
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoui_fast(0.0) == 0);
                assert(_cvt_dtoui_fast(-0.0) == 0);
                assert(_cvt_dtoui_fast(1.0) == 1);
                assert(_cvt_dtoui_fast(-1.0) == 4294967295);
                assert(_cvt_dtoui_fast(2.5) == 2);
                assert(_cvt_dtoui_fast(-2.5) == 4294967294);
                assert(_cvt_dtoui_fast(3.5) == 3);
                assert(_cvt_dtoui_fast(-3.5) == 4294967293);
                assert(_cvt_dtoui_fast(3.49) == 3);
                assert(_cvt_dtoui_fast(-3.49) == 4294967293);
                assert(_cvt_dtoui_fast(twoExp31Float) == 2147483648);
                assert(_cvt_dtoui_fast(-twoExp31Float) == 2147483648);
                assert(_cvt_dtoui_fast(33554432.0) == 33554432);
                assert(_cvt_dtoui_fast(-33554432.0) == 4261412864);
                assert(_cvt_dtoui_fast(33554436.0) == 33554436);
                assert(_cvt_dtoui_fast(-33554436.0) == 4261412860);

                version (X86_64)
                {
                    assert(_cvt_dtoui_fast(float.nan) == 0);
                    assert(_cvt_dtoui_fast(-float.nan) == 0);
                    assert(_cvt_dtoui_fast(float.infinity) == 0);
                    assert(_cvt_dtoui_fast(-float.infinity) == 0);
                    assert(_cvt_dtoui_fast(twoExp63Float) == 0);
                    assert(_cvt_dtoui_fast(-twoExp63Float) == 0);
                    assert(_cvt_dtoui_fast(justUnderTwoExp63Float) == 0);
                    assert(_cvt_dtoui_fast(70369281048576.0) == 536870912);
                    assert(_cvt_dtoui_fast(-70369281048576.0) == 3758096384);
                }
                else version (X86)
                {
                    assert(_cvt_dtoui_fast(float.nan) == 2147483648);
                    assert(_cvt_dtoui_fast(-float.nan) == 2147483648);
                    assert(_cvt_dtoui_fast(float.infinity) == 2147483648);
                    assert(_cvt_dtoui_fast(-float.infinity) == 2147483648);
                    assert(_cvt_dtoui_fast(twoExp63Float) == 2147483648);
                    assert(_cvt_dtoui_fast(-twoExp63Float) == 2147483648);
                    assert(_cvt_dtoui_fast(justUnderTwoExp63Float) == 4294967040);
                    assert(_cvt_dtoui_fast(70369281048576.0) == 2147500032);
                    assert(_cvt_dtoui_fast(-70369281048576.0) == 2147483648);
                }

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        ulong _cvt_dtoull_fast(double value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp63Double || value != value)
                {
                    return cast(ulong) _cvt_dtoll_fast(value);
                }

                /* At this point, the exponent is at-least 63, and the value may be an infinity or NaN.
                   We care about being correct for values with only an exponent of 63,
                   which excludes infinities and NaNs, because that's how the MSVC intrinsic behaves. */

                /* We have 52-bits stored for the significand, and we know that the exponent is
                   at-least 63, and we only care about being correct for an exponent of 63,
                   which means that we can just shift left unconditionally by 11 (63 - 52), which leaves
                   the implicit bit of the full 53-bit significand to be set at the most-significant bit. */
                return (*(cast(const(ulong)*) &value) << 11) | (ulong(1) << 63);
            }
            else version (X86)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Double || value != value)
                {
                    return cast(uint) _cvt_dtoi_fast(value);
                }

                /* At this point, the exponent is at-least 31, and the value may be an infinity or NaN.
                   We care about being correct for values with only an exponent less-than 64,
                   which excludes infinities and NaNs, because that's how the MSVC intrinsic behaves. */

                long asInt = *(cast(const(long)*) &value);

                uint high = cast(uint) (asInt >>> 32);
                uint low = cast(uint) asInt;

                int exponent = ((high >>> 20) & 2047) - 1023;
                /* NaNs and infinity exponents will result in 1024, whereas numeric exponents will be at-least 31. */
                assert(exponent >= 31);

                ulong significand = (ulong((high & 0b00000000_00001111_11111111_11111111) | (1 << 20)) << 32) | low;
                uint shiftCount = (exponent < 52 ? 52 : exponent) - (exponent < 52 ? exponent : 52);

                if (exponent < 52)
                {
                    significand >>>= (shiftCount & 31);
                }
                else
                {
                    significand <<= (shiftCount & 31);
                }

                return significand;
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoull_fast(0.0) == 0);
                assert(_cvt_dtoull_fast(-0.0) == 0);
                assert(_cvt_dtoull_fast(1.0) == 1);
                assert(_cvt_dtoull_fast(2.5) == 2);
                assert(_cvt_dtoull_fast(3.5) == 3);
                assert(_cvt_dtoull_fast(3.49) == 3);
                assert(_cvt_dtoull_fast(twoExp31Float) == 2147483648);
                assert(_cvt_dtoull_fast(twoExp63Float) == 9223372036854775808);
                assert(_cvt_dtoull_fast(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_dtoull_fast(33554432.0) == 33554432);
                assert(_cvt_dtoull_fast(33554436.0) == 33554436);
                assert(_cvt_dtoull_fast(70369281048576.0) == 70369281048576);

                version (X86_64)
                {
                    assert(_cvt_dtoull_fast(float.nan) == 9223372036854775808);
                    assert(_cvt_dtoull_fast(-float.nan) == 9223372036854775808);
                    assert(_cvt_dtoull_fast(float.infinity) == 9223372036854775808);
                    assert(_cvt_dtoull_fast(-float.infinity) == 9223372036854775808);
                    assert(_cvt_dtoull_fast(-1.0) == 18446744073709551615);
                    assert(_cvt_dtoull_fast(-2.5) == 18446744073709551614);
                    assert(_cvt_dtoull_fast(-3.5) == 18446744073709551613);
                    assert(_cvt_dtoull_fast(-3.49) == 18446744073709551613);
                    assert(_cvt_dtoull_fast(-twoExp31Float) == 18446744071562067968);
                    assert(_cvt_dtoull_fast(-twoExp63Float) == 9223372036854775808);
                    assert(_cvt_dtoull_fast(-33554432.0) == 18446744073675997184);
                    assert(_cvt_dtoull_fast(-33554436.0) == 18446744073675997180);
                    assert(_cvt_dtoull_fast(-70369281048576.0) == 18446673704428503040);
                }
                else version (X86)
                {
                    assert(_cvt_dtoull_fast(float.nan) == 2147483648);
                    assert(_cvt_dtoull_fast(-float.nan) == 2147483648);
                    assert(_cvt_dtoull_fast(float.infinity) == 0);
                    assert(_cvt_dtoull_fast(-float.infinity) == 2147483648);
                    assert(_cvt_dtoull_fast(-1.0) == 4294967295);
                    assert(_cvt_dtoull_fast(-2.5) == 4294967294);
                    assert(_cvt_dtoull_fast(-3.5) == 4294967293);
                    assert(_cvt_dtoull_fast(-3.49) == 4294967293);
                    assert(_cvt_dtoull_fast(-twoExp31Float) == 2147483648);
                    assert(_cvt_dtoull_fast(-twoExp63Float) == 2147483648);
                    assert(_cvt_dtoull_fast(-33554432.0) == 4261412864);
                    assert(_cvt_dtoull_fast(-33554436.0) == 4261412860);
                    assert(_cvt_dtoull_fast(-70369281048576.0) == 2147483648);
                }

                return true;
            }

            assert(test());
            static assert(test());
        }

        extern(C)
        pragma(inline, true)
        int _cvt_ftoi_sat(float value) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                if (value >= twoExp31Float)
                {
                    return int.max;
                }

                if (value < -twoExp31Float)
                {
                    return int.min;
                }

                if (value != value)
                {
                    return 0;
                }

                return cast(int) value;
            }
            else
            {
                version (LDC_Or_GNU)
                {
                    mixin(q{import }, gccBuiltins, q{ : __builtin_ia32_cvttss2si;});

                    if (value >= twoExp31Float)
                    {
                        return int.max;
                    }

                    if (value != value)
                    {
                        return 0;
                    }

                    /* If value is less-than -twoExp31Float cvttss2si will evaluate to int.min. */
                    return __builtin_ia32_cvttss2si(value);
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        ucomiss XMM0, twoExp31FloatInstance;
                        mov EAX, int.max;
                        jae tooBig; /* Jump if value is greater-or-equal to twoExp31Float. */
                        jp isNaN; /* Jump if value is NaN. */
                        /* If value is less-than -twoExp31Float cvttss2si will evaluate to int.min. */
                        cvttss2si EAX, XMM0;
                        ret;
                    isNaN:
                        xor EAX, EAX;
                    tooBig:
                        ret;
                    }
                }
                else version (D_InlineAsm_X86)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        movss XMM0, [ESP + 4];
                        ucomiss XMM0, twoExp31FloatInstance;
                        mov EAX, int.max;
                        jae tooBig; /* Jump if value is greater-or-equal to twoExp31Float. */
                        jp isNaN; /* Jump if value is NaN. */
                        /* If value is less-than -twoExp31Float cvttss2si will evaluate to int.min. */
                        cvttss2si EAX, XMM0;
                        ret;
                    isNaN:
                        xor EAX, EAX;
                    tooBig:
                        ret;
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoi_sat(0.0f) == 0);
                assert(_cvt_ftoi_sat(-0.0f) == 0);
                assert(_cvt_ftoi_sat(float.nan) == 0);
                assert(_cvt_ftoi_sat(-float.nan) == 0);
                assert(_cvt_ftoi_sat(float.infinity) == 2147483647);
                assert(_cvt_ftoi_sat(-float.infinity) == -2147483648);
                assert(_cvt_ftoi_sat(1.0f) == 1);
                assert(_cvt_ftoi_sat(-1.0f) == -1);
                assert(_cvt_ftoi_sat(2.5f) == 2);
                assert(_cvt_ftoi_sat(-2.5f) == -2);
                assert(_cvt_ftoi_sat(3.5f) == 3);
                assert(_cvt_ftoi_sat(-3.5f) == -3);
                assert(_cvt_ftoi_sat(3.49f) == 3);
                assert(_cvt_ftoi_sat(-3.49f) == -3);
                assert(_cvt_ftoi_sat(twoExp31Float) == 2147483647);
                assert(_cvt_ftoi_sat(-twoExp31Float) == -2147483648);
                assert(_cvt_ftoi_sat(twoExp63Float) == 2147483647);
                assert(_cvt_ftoi_sat(-twoExp63Float) == -2147483648);
                assert(_cvt_ftoi_sat(justUnderTwoExp63Float) == 2147483647);
                assert(_cvt_ftoi_sat(33554432.0f) == 33554432);
                assert(_cvt_ftoi_sat(-33554432.0f) == -33554432);
                assert(_cvt_ftoi_sat(33554436.0f) == 33554436);
                assert(_cvt_ftoi_sat(-33554436.0f) == -33554436);
                assert(_cvt_ftoi_sat(70369281048576.0f) == 2147483647);
                assert(_cvt_ftoi_sat(-70369281048576.0f) == -2147483648);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        long _cvt_ftoll_sat(float value) @trusted pure nothrow @nogc
        {
            if (__ctfe)
            {
                if (value >= twoExp63Float)
                {
                    return long.max;
                }

                if (value < -twoExp63Float)
                {
                    return long.min;
                }

                if (value != value)
                {
                    return 0;
                }

                return cast(long) value;
            }
            else
            {
                version (X86_64)
                {
                    version (LDC_Or_GNU)
                    {
                        mixin(q{import }, gccBuiltins, q{ : __builtin_ia32_cvttss2si64;});

                        if (value >= twoExp63Float)
                        {
                            return long.max;
                        }

                        if (value != value)
                        {
                            return 0;
                        }

                        /* If value is less-than -twoExp63Float cvttss2si will evaluate to long.min. */
                        return __builtin_ia32_cvttss2si64(value);
                    }
                    else version (D_InlineAsm_X86_64)
                    {
                        enum ubyte REX_W = 0b0100_1000;
                        enum ubyte RAX_XMM0 = 0b11_000_000;

                        asm @trusted pure nothrow @nogc
                        {
                            naked;
                            ucomiss XMM0, twoExp63FloatInstance;
                            mov RAX, long.max;
                            jae tooBig; /* Jump if value is greater-or-equal to twoExp63Float. */
                            jp isNaN; /* Jump if value is NaN. */
                            /* If value is less-than -twoExp63Float cvttss2si will evaluate to long.min. */
                            /* DMD refuses to encode `cvttss2si RAX, XMM0`, so we'll encode it by hand. */
                            db 0xF3, REX_W, 0x0F, 0x2C, RAX_XMM0; /* cvttss2si RAX, XMM0 */
                            ret;
                        isNaN:
                            xor EAX, EAX;
                        tooBig:
                            ret;
                        }
                    }
                }
                else version (X86)
                {
                    import std.math : nextUp;

                    /* If the hardware can handle it, let it handle it. */
                    if (value < twoExp31Float && value >= -twoExp31Float)
                    {
                        return _cvt_ftoi_fast(value);
                    }

                    if (value >= twoExp63Float)
                    {
                        return long.max;
                    }

                    if (value <= -twoExp63Float)
                    {
                        return long.min;
                    }

                    if (value != value)
                    {
                        return 0;
                    }

                    /* At this point, the exponent is at-least 31 and less-than 64.
                       Because the exponent is at-least 23, the value will never actually contain any
                       fractional digits, so we can just shift the significand left to get an integer. */

                    int asInt = *(cast(const(int)*) &value);

                    uint sign = asInt >> 31;
                    assert(sign == 0 || sign == -1);

                    /* The exponent is biased by +127, but we subtract only 126 as we want the exponent
                       to be one-higher than it actually is, so that we shift the correct number of bits
                       after we mask the exponent by 31.
                       E.g. with an exponent of 31 we should shift 0 bits, 32 should shift 1 bit, etc.. */
                    byte exponent = cast(byte) ((cast(ubyte) (asInt >>> 23)) - 126);
                    assert(exponent >= 32);
                    assert(exponent <= 63);

                    /* We have 23-bits stored for the significand, and we know that the exponent is
                       at-least 31, which means that we can shift left unconditionally by 8, which leaves
                       the implicit bit of the full 24-bit significand to be set at the most-significant bit.
                       Conveniently, this means that the variable shifting for the exponent concerns only
                       the high half (remember that this is for 32-bit mode). */
                    uint unadjustedSignificand = (asInt << 8) | (1 << 31);

                    /* If the sign bit is set, we need to negate the significand; we can do that branchlessly
                       by taking advantage of the fact that `sign` is either 0 or -1.
                       As `(s ^ 0) - 0 == s`, whereas `(s ^ -1) - -1 == -s`. */
                    uint significand = (unadjustedSignificand ^ sign) - sign;
                    assert(sign == 0 ? significand == unadjustedSignificand : significand == -unadjustedSignificand);

                    uint highHalf = funnelShiftLeft(significand, sign, exponent & 31);

                    return (ulong(highHalf) << 32) | ulong(significand << (exponent & 31));
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoll_sat(0.0f) == 0);
                assert(_cvt_ftoll_sat(-0.0f) == 0);
                assert(_cvt_ftoll_sat(float.nan) == 0);
                assert(_cvt_ftoll_sat(-float.nan) == 0);
                assert(_cvt_ftoll_sat(float.infinity) == 9223372036854775807);
                assert(_cvt_ftoll_sat(-float.infinity) == -9223372036854775808);
                assert(_cvt_ftoll_sat(1.0f) == 1);
                assert(_cvt_ftoll_sat(-1.0f) == -1);
                assert(_cvt_ftoll_sat(2.5f) == 2);
                assert(_cvt_ftoll_sat(-2.5f) == -2);
                assert(_cvt_ftoll_sat(3.5f) == 3);
                assert(_cvt_ftoll_sat(-3.5f) == -3);
                assert(_cvt_ftoll_sat(3.49f) == 3);
                assert(_cvt_ftoll_sat(-3.49f) == -3);
                assert(_cvt_ftoll_sat(twoExp31Float) == 2147483648);
                assert(_cvt_ftoll_sat(-twoExp31Float) == -2147483648);
                assert(_cvt_ftoll_sat(twoExp63Float) == 9223372036854775807);
                assert(_cvt_ftoll_sat(-twoExp63Float) == -9223372036854775808);
                assert(_cvt_ftoll_sat(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_ftoll_sat(33554432.0f) == 33554432);
                assert(_cvt_ftoll_sat(-33554432.0f) == -33554432);
                assert(_cvt_ftoll_sat(33554436.0f) == 33554436);
                assert(_cvt_ftoll_sat(-33554436.0f) == -33554436);
                assert(_cvt_ftoll_sat(70369281048576.0f) == 70369281048576);
                assert(_cvt_ftoll_sat(-70369281048576.0f) == -70369281048576);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        uint _cvt_ftoui_sat(float value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                if (value >= twoExp32Float)
                {
                    return uint.max;
                }

                if (value < 0.0f || value != value)
                {
                    return 0;
                }

                return cast(uint) _cvt_ftoll_fast(value);
            }
            else version (X86)
            {
                if (value < 0.0f || value != value)
                {
                    return 0;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Float)
                {
                    return cast(uint) _cvt_ftoi_fast(value);
                }

                if (value >= twoExp32Float)
                {
                    return uint.max;
                }

                /* At this point, the exponent is 31.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                /* We have 23-bits stored for the significand, and we know that the exponent is 31,
                   which means that we can just shift left unconditionally by 8, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit. */
                return (*(cast(const(uint)*) &value) << 8) | (1 << 31);
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoui_sat(0.0f) == 0);
                assert(_cvt_ftoui_sat(-0.0f) == 0);
                assert(_cvt_ftoui_sat(float.nan) == 0);
                assert(_cvt_ftoui_sat(-float.nan) == 0);
                assert(_cvt_ftoui_sat(float.infinity) == 4294967295);
                assert(_cvt_ftoui_sat(-float.infinity) == 0);
                assert(_cvt_ftoui_sat(1.0f) == 1);
                assert(_cvt_ftoui_sat(-1.0f) == 0);
                assert(_cvt_ftoui_sat(2.5f) == 2);
                assert(_cvt_ftoui_sat(-2.5f) == 0);
                assert(_cvt_ftoui_sat(3.5f) == 3);
                assert(_cvt_ftoui_sat(-3.5f) == 0);
                assert(_cvt_ftoui_sat(3.49f) == 3);
                assert(_cvt_ftoui_sat(-3.49f) == 0);
                assert(_cvt_ftoui_sat(twoExp31Float) == 2147483648);
                assert(_cvt_ftoui_sat(-twoExp31Float) == 0);
                assert(_cvt_ftoui_sat(twoExp63Float) == 4294967295);
                assert(_cvt_ftoui_sat(-twoExp63Float) == 0);
                assert(_cvt_ftoui_sat(justUnderTwoExp63Float) == 4294967295);
                assert(_cvt_ftoui_sat(33554432.0f) == 33554432);
                assert(_cvt_ftoui_sat(-33554432.0f) == 0);
                assert(_cvt_ftoui_sat(33554436.0f) == 33554436);
                assert(_cvt_ftoui_sat(-33554436.0f) == 0);
                assert(_cvt_ftoui_sat(70369281048576.0f) == 4294967295);
                assert(_cvt_ftoui_sat(-70369281048576.0f) == 0);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        ulong _cvt_ftoull_sat(float value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                if (value < 0.0f || value != value)
                {
                    return 0;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp63Float)
                {
                    return cast(ulong) _cvt_ftoll_fast(value);
                }

                if (value >= twoExp64Float)
                {
                    return ulong.max;
                }

                /* At this point, the exponent is 63.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                /* We have 23-bits stored for the significand, and we know that the exponent is 63,
                   which means that we can just shift left unconditionally by 40, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit. */
                return (ulong(*(cast(const(uint)*) &value)) << 40) | (ulong(1) << 63);
            }
            else version (X86)
            {
                if (value < 0.0f || value != value)
                {
                    return 0;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Float)
                {
                    return cast(ulong) _cvt_ftoi_fast(value);
                }

                if (value >= twoExp64Float)
                {
                    return ulong.max;
                }

                /* At this point, the exponent is at-least 31 and less-than 64.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                int asInt = *(cast(const(int)*) &value);

                /* The exponent is biased by +127, but we subtract only 126 as we want the exponent
                   to be one-higher than it actually is, so that we shift the correct number of bits
                   after we mask the exponent by 31.
                   E.g. with an exponent of 31 we should shift 0 bits, 32 should shift 1 bit, etc.. */
                byte exponent = cast(byte) ((cast(ubyte) (asInt >>> 23)) - 126);
                assert(exponent >= 32);
                assert(exponent <= 64);

                /* We have 23-bits stored for the significand, and we know that the exponent is
                   at-least 31, which means that we can shift left unconditionally by 8, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit.
                   Conveniently, this means that the variable shifting for the exponent concerns only
                   the high half (remember that this is for 32-bit mode). */
                uint significand = (asInt << 8) | (1 << 31);

                return ulong(significand) << (exponent == 64 ? 32 : (exponent & 31));
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoull_sat(0.0f) == 0);
                assert(_cvt_ftoull_sat(-0.0f) == 0);
                assert(_cvt_ftoull_sat(float.nan) == 0);
                assert(_cvt_ftoull_sat(-float.nan) == 0);
                assert(_cvt_ftoull_sat(float.infinity) == 18446744073709551615);
                assert(_cvt_ftoull_sat(-float.infinity) == 0);
                assert(_cvt_ftoull_sat(1.0f) == 1);
                assert(_cvt_ftoull_sat(-1.0f) == 0);
                assert(_cvt_ftoull_sat(2.5f) == 2);
                assert(_cvt_ftoull_sat(-2.5f) == 0);
                assert(_cvt_ftoull_sat(3.5f) == 3);
                assert(_cvt_ftoull_sat(-3.5f) == 0);
                assert(_cvt_ftoull_sat(3.49f) == 3);
                assert(_cvt_ftoull_sat(-3.49f) == 0);
                assert(_cvt_ftoull_sat(twoExp31Float) == 2147483648);
                assert(_cvt_ftoull_sat(-twoExp31Float) == 0);
                assert(_cvt_ftoull_sat(twoExp63Float) == 9223372036854775808);
                assert(_cvt_ftoull_sat(-twoExp63Float) == 0);
                assert(_cvt_ftoull_sat(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_ftoull_sat(33554432.0f) == 33554432);
                assert(_cvt_ftoull_sat(-33554432.0f) == 0);
                assert(_cvt_ftoull_sat(33554436.0f) == 33554436);
                assert(_cvt_ftoull_sat(-33554436.0f) == 0);
                assert(_cvt_ftoull_sat(70369281048576.0f) == 70369281048576);
                assert(_cvt_ftoull_sat(-70369281048576.0f) == 0);

                return true;
            }

            assert(test());
            static assert(test());
        }

        extern(C)
        pragma(inline, true)
        int _cvt_dtoi_sat(double value) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                if (value >= twoExp31Double)
                {
                    return int.max;
                }

                if (value < -twoExp31Double)
                {
                    return int.min;
                }

                if (value != value)
                {
                    return 0;
                }

                return cast(int) value;
            }
            else
            {
                version (LDC_Or_GNU)
                {
                    mixin(q{import }, gccBuiltins, q{ : __builtin_ia32_cvttsd2si;});

                    if (value >= twoExp31Double)
                    {
                        return int.max;
                    }

                    if (value != value)
                    {
                        return 0;
                    }

                    /* If value is less-than -twoExp31Double cvttsd2si will evaluate to int.min. */
                    return __builtin_ia32_cvttsd2si(value);
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        ucomisd XMM0, twoExp31DoubleInstance;
                        mov EAX, int.max;
                        jae tooBig; /* Jump if value is greater-or-equal to twoExp31DoubleInstance. */
                        jp isNaN; /* Jump if value is NaN. */
                        /* If value is less-than -twoExp31DoubleInstance cvttsd2si will evaluate to int.min. */
                        cvttsd2si EAX, XMM0;
                        ret;
                    isNaN:
                        xor EAX, EAX;
                    tooBig:
                        ret;
                    }
                }
                else version (D_InlineAsm_X86)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        movsd XMM0, [ESP + 4];
                        ucomisd XMM0, twoExp31DoubleInstance;
                        mov EAX, int.max;
                        jae tooBig; /* Jump if value is greater-or-equal to twoExp31DoubleInstance. */
                        jp isNaN; /* Jump if value is NaN. */
                        /* If value is less-than -twoExp31DoubleInstance cvttsd2si will evaluate to int.min. */
                        cvttsd2si EAX, XMM0;
                        ret;
                    isNaN:
                        xor EAX, EAX;
                    tooBig:
                        ret;
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoi_sat(0.0) == 0);
                assert(_cvt_dtoi_sat(-0.0) == 0);
                assert(_cvt_dtoi_sat(float.nan) == 0);
                assert(_cvt_dtoi_sat(-float.nan) == 0);
                assert(_cvt_dtoi_sat(float.infinity) == 2147483647);
                assert(_cvt_dtoi_sat(-float.infinity) == -2147483648);
                assert(_cvt_dtoi_sat(1.0) == 1);
                assert(_cvt_dtoi_sat(-1.0) == -1);
                assert(_cvt_dtoi_sat(2.5) == 2);
                assert(_cvt_dtoi_sat(-2.5) == -2);
                assert(_cvt_dtoi_sat(3.5) == 3);
                assert(_cvt_dtoi_sat(-3.5) == -3);
                assert(_cvt_dtoi_sat(3.49) == 3);
                assert(_cvt_dtoi_sat(-3.49) == -3);
                assert(_cvt_dtoi_sat(twoExp31Float) == 2147483647);
                assert(_cvt_dtoi_sat(-twoExp31Float) == -2147483648);
                assert(_cvt_dtoi_sat(twoExp63Float) == 2147483647);
                assert(_cvt_dtoi_sat(-twoExp63Float) == -2147483648);
                assert(_cvt_dtoi_sat(justUnderTwoExp63Float) == 2147483647);
                assert(_cvt_dtoi_sat(33554432.0) == 33554432);
                assert(_cvt_dtoi_sat(-33554432.0) == -33554432);
                assert(_cvt_dtoi_sat(33554436.0) == 33554436);
                assert(_cvt_dtoi_sat(-33554436.0) == -33554436);
                assert(_cvt_dtoi_sat(70369281048576.0) == 2147483647);
                assert(_cvt_dtoi_sat(-70369281048576.0) == -2147483648);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        long _cvt_dtoll_sat(double value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                if (__ctfe)
                {
                    if (value >= twoExp63Double)
                    {
                        return long.max;
                    }

                    if (value < -twoExp63Double)
                    {
                        return long.min;
                    }

                    if (value != value)
                    {
                        return 0;
                    }

                    return cast(long) value;
                }
                else
                {
                    version (LDC_Or_GNU)
                    {
                        mixin(q{import }, gccBuiltins, q{ : __builtin_ia32_cvttsd2si64;});

                        if (value >= twoExp63Double)
                        {
                            return long.max;
                        }

                        if (value != value)
                        {
                            return 0;
                        }

                        /* If value is less-than -twoExp63Double cvttsd2si will evaluate to long.min. */
                        return __builtin_ia32_cvttsd2si64(value);
                    }
                    else version (D_InlineAsm_X86_64)
                    {
                        enum ubyte REX_W = 0b0100_1000;
                        enum ubyte RAX_XMM0 = 0b11_000_000;

                        asm @trusted pure nothrow @nogc
                        {
                            naked;
                            ucomisd XMM0, twoExp63DoubleInstance;
                            mov RAX, long.max;
                            jae tooBig; /* Jump if value is greater-or-equal to twoExp63DoubleInstance. */
                            jp isNaN; /* Jump if value is NaN. */
                            /* If value is less-than -twoExp63DoubleInstance cvttsd2si will evaluate to long.min. */
                            /* DMD refuses to encode `cvttsd2si RAX, XMM0`, so we'll encode it by hand. */
                            db 0xF2, REX_W, 0x0F, 0x2C, RAX_XMM0; /* cvttsd2si RAX, XMM0 */
                            ret;
                        isNaN:
                            xor EAX, EAX;
                        tooBig:
                            ret;
                        }
                    }
                }
            }
            else version (X86)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Double && value >= -twoExp31Double)
                {
                    return _cvt_dtoi_fast(value);
                }

                if (value >= twoExp63Double)
                {
                    return long.max;
                }

                if (value < -twoExp63Double)
                {
                    return long.min;
                }

                if (value != value)
                {
                    return 0;
                }

                /* At this point, the exponent is at-least 31 and less-than 64. */

                long asInt = *(cast(const(long)*) &value);

                uint high = cast(uint) (asInt >>> 32);
                uint low = cast(uint) asInt;

                long sign = (cast(int) high) >> 31;
                assert(sign == 0 || sign == -1);

                int exponent = ((high >>> 20) & 2047) - 1023;
                assert(exponent >= 31);
                assert(exponent <= 63);

                ulong significand = (ulong((high & 0b00000000_00001111_11111111_11111111) | (1 << 20)) << 32) | low;
                uint shiftCount = (exponent < 52 ? 52 : exponent) - (exponent < 52 ? exponent : 52);

                if (exponent < 52)
                {
                    significand >>>= (shiftCount & 63);
                }
                else
                {
                    significand <<= (shiftCount & 63);
                }

                /* If the sign bit is set, we need to negate the significand; we can do that branchlessly
                   by taking advantage of the fact that `sign` is either 0 or -1.
                   As `(s ^ 0) - 0 == s`, whereas `(s ^ -1) - -1 == -s`. */
                ulong adjustedSignificand = (significand ^ sign) - sign;
                assert(sign == 0 ? adjustedSignificand == significand : adjustedSignificand == -significand);

                return adjustedSignificand;
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoll_sat(0.0) == 0);
                assert(_cvt_dtoll_sat(-0.0) == 0);
                assert(_cvt_dtoll_sat(double.nan) == 0);
                assert(_cvt_dtoll_sat(-double.nan) == 0);
                assert(_cvt_dtoll_sat(double.infinity) == 9223372036854775807);
                assert(_cvt_dtoll_sat(-double.infinity) == -9223372036854775808);
                assert(_cvt_dtoll_sat(1.0) == 1);
                assert(_cvt_dtoll_sat(-1.0) == -1);
                assert(_cvt_dtoll_sat(2.5) == 2);
                assert(_cvt_dtoll_sat(-2.5) == -2);
                assert(_cvt_dtoll_sat(3.5) == 3);
                assert(_cvt_dtoll_sat(-3.5) == -3);
                assert(_cvt_dtoll_sat(3.49) == 3);
                assert(_cvt_dtoll_sat(-3.49) == -3);
                assert(_cvt_dtoll_sat(twoExp31Double) == 2147483648);
                assert(_cvt_dtoll_sat(-twoExp31Double) == -2147483648);
                assert(_cvt_dtoll_sat(twoExp63Double) == 9223372036854775807);
                assert(_cvt_dtoll_sat(-twoExp63Double) == -9223372036854775808);
                assert(_cvt_dtoll_sat(justUnderTwoExp63Double) == 9223371487098961920);
                assert(_cvt_dtoll_sat(33554432.0) == 33554432);
                assert(_cvt_dtoll_sat(-33554432.0) == -33554432);
                assert(_cvt_dtoll_sat(33554436.0) == 33554436);
                assert(_cvt_dtoll_sat(-33554436.0) == -33554436);
                assert(_cvt_dtoll_sat(70369281048576.0) == 70369281048576);
                assert(_cvt_dtoll_sat(-70369281048576.0) == -70369281048576);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        uint _cvt_dtoui_sat(double value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                if (value >= twoExp32Double)
                {
                    return uint.max;
                }

                if (value < 0.0 || value != value)
                {
                    return 0;
                }

                return cast(uint) _cvt_dtoll_fast(value);
            }
            else version (X86)
            {
                if (value < 0.0 || value != value)
                {
                    return 0;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Double)
                {
                    return cast(uint) _cvt_dtoi_fast(value);
                }

                if (value >= twoExp32Double)
                {
                    return uint.max;
                }

                /* At this point, the exponent is 31. */

                /* We have 52-bits stored for the significand, and we know that the exponent is 31,
                   which means that we can just shift left unconditionally by 21 (52 - 31), which leaves
                   the implicit bit of the full 53-bit significand to be set at the most-significant bit. */
                return cast(uint) (*(cast(const(ulong)*) &value) >>> 21) | (1 << 31);
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoui_sat(0.0) == 0);
                assert(_cvt_dtoui_sat(-0.0) == 0);
                assert(_cvt_dtoui_sat(float.nan) == 0);
                assert(_cvt_dtoui_sat(-float.nan) == 0);
                assert(_cvt_dtoui_sat(float.infinity) == 4294967295);
                assert(_cvt_dtoui_sat(-float.infinity) == 0);
                assert(_cvt_dtoui_sat(1.0) == 1);
                assert(_cvt_dtoui_sat(-1.0) == 0);
                assert(_cvt_dtoui_sat(2.5) == 2);
                assert(_cvt_dtoui_sat(-2.5) == 0);
                assert(_cvt_dtoui_sat(3.5) == 3);
                assert(_cvt_dtoui_sat(-3.5) == 0);
                assert(_cvt_dtoui_sat(3.49) == 3);
                assert(_cvt_dtoui_sat(-3.49) == 0);
                assert(_cvt_dtoui_sat(twoExp31Float) == 2147483648);
                assert(_cvt_dtoui_sat(-twoExp31Float) == 0);
                assert(_cvt_dtoui_sat(twoExp63Float) == 4294967295);
                assert(_cvt_dtoui_sat(-twoExp63Float) == 0);
                assert(_cvt_dtoui_sat(justUnderTwoExp63Float) == 4294967295);
                assert(_cvt_dtoui_sat(33554432.0) == 33554432);
                assert(_cvt_dtoui_sat(-33554432.0) == 0);
                assert(_cvt_dtoui_sat(33554436.0) == 33554436);
                assert(_cvt_dtoui_sat(-33554436.0) == 0);
                assert(_cvt_dtoui_sat(70369281048576.0) == 4294967295);
                assert(_cvt_dtoui_sat(-70369281048576.0) == 0);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        ulong _cvt_dtoull_sat(double value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                if (value < 0.0 || value != value)
                {
                    return 0;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp63Double)
                {
                    return cast(ulong) _cvt_dtoll_fast(value);
                }

                if (value >= twoExp64Double)
                {
                    return ulong.max;
                }

                /* At this point, the exponent is 63. */

                /* We have 52-bits stored for the significand, and we know that the exponent is 63,
                   which means that we can just shift left unconditionally by 11 (63 - 52), which leaves
                   the implicit bit of the full 53-bit significand to be set at the most-significant bit. */
                return (*(cast(const(ulong)*) &value) << 11) | (ulong(1) << 63);
            }
            else version (X86)
            {
                if (value < 0.0 || value != value)
                {
                    return 0;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Double)
                {
                    return cast(ulong) _cvt_dtoi_fast(value);
                }

                if (value >= twoExp64Double)
                {
                    return ulong.max;
                }

                /* At this point, the exponent is at-least 31 and less-than 64. */

                long asInt = *(cast(const(long)*) &value);

                uint high = cast(uint) (asInt >>> 32);
                uint low = cast(uint) asInt;

                int exponent = ((high >>> 20) & 2047) - 1023;
                assert(exponent >= 31);
                assert(exponent <= 63);

                ulong significand = (ulong((high & 0b00000000_00001111_11111111_11111111) | (1 << 20)) << 32) | low;
                uint shiftCount = (exponent < 52 ? 52 : exponent) - (exponent < 52 ? exponent : 52);

                if (exponent < 52)
                {
                    significand >>>= (shiftCount & 63);
                }
                else
                {
                    significand <<= (shiftCount & 63);
                }

                return significand;
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoull_sat(0.0) == 0);
                assert(_cvt_dtoull_sat(-0.0) == 0);
                assert(_cvt_dtoull_sat(float.nan) == 0);
                assert(_cvt_dtoull_sat(-float.nan) == 0);
                assert(_cvt_dtoull_sat(float.infinity) == 18446744073709551615);
                assert(_cvt_dtoull_sat(-float.infinity) == 0);
                assert(_cvt_dtoull_sat(1.0) == 1);
                assert(_cvt_dtoull_sat(-1.0) == 0);
                assert(_cvt_dtoull_sat(2.5) == 2);
                assert(_cvt_dtoull_sat(-2.5) == 0);
                assert(_cvt_dtoull_sat(3.5) == 3);
                assert(_cvt_dtoull_sat(-3.5) == 0);
                assert(_cvt_dtoull_sat(3.49) == 3);
                assert(_cvt_dtoull_sat(-3.49) == 0);
                assert(_cvt_dtoull_sat(twoExp31Float) == 2147483648);
                assert(_cvt_dtoull_sat(-twoExp31Float) == 0);
                assert(_cvt_dtoull_sat(twoExp63Float) == 9223372036854775808);
                assert(_cvt_dtoull_sat(-twoExp63Float) == 0);
                assert(_cvt_dtoull_sat(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_dtoull_sat(33554432.0) == 33554432);
                assert(_cvt_dtoull_sat(-33554432.0) == 0);
                assert(_cvt_dtoull_sat(33554436.0) == 33554436);
                assert(_cvt_dtoull_sat(-33554436.0) == 0);
                assert(_cvt_dtoull_sat(70369281048576.0) == 70369281048576);
                assert(_cvt_dtoull_sat(-70369281048576.0) == 0);

                return true;
            }

            assert(test());
            static assert(test());
        }

        extern(C)
        pragma(inline, true)
        int _cvt_ftoi_sent(float value) @safe pure nothrow @nogc
        {
            return _cvt_ftoi_fast(value);
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoi_sent(0.0f) == 0);
                assert(_cvt_ftoi_sent(-0.0f) == 0);
                assert(_cvt_ftoi_sent(float.nan) == -2147483648);
                assert(_cvt_ftoi_sent(-float.nan) == -2147483648);
                assert(_cvt_ftoi_sent(float.infinity) == -2147483648);
                assert(_cvt_ftoi_sent(-float.infinity) == -2147483648);
                assert(_cvt_ftoi_sent(1.0f) == 1);
                assert(_cvt_ftoi_sent(-1.0f) == -1);
                assert(_cvt_ftoi_sent(2.5f) == 2);
                assert(_cvt_ftoi_sent(-2.5f) == -2);
                assert(_cvt_ftoi_sent(3.5f) == 3);
                assert(_cvt_ftoi_sent(-3.5f) == -3);
                assert(_cvt_ftoi_sent(3.49f) == 3);
                assert(_cvt_ftoi_sent(-3.49f) == -3);
                assert(_cvt_ftoi_sent(twoExp31Float) == -2147483648);
                assert(_cvt_ftoi_sent(-twoExp31Float) == -2147483648);
                assert(_cvt_ftoi_sent(twoExp63Float) == -2147483648);
                assert(_cvt_ftoi_sent(-twoExp63Float) == -2147483648);
                assert(_cvt_ftoi_sent(justUnderTwoExp63Float) == -2147483648);
                assert(_cvt_ftoi_sent(33554432.0f) == 33554432);
                assert(_cvt_ftoi_sent(-33554432.0f) == -33554432);
                assert(_cvt_ftoi_sent(33554436.0f) == 33554436);
                assert(_cvt_ftoi_sent(-33554436.0f) == -33554436);
                assert(_cvt_ftoi_sent(70369281048576.0f) == -2147483648);
                assert(_cvt_ftoi_sent(-70369281048576.0f) == -2147483648);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        long _cvt_ftoll_sent(float value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                return _cvt_ftoll_fast(value);
            }
            else version (X86)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Float && value >= -twoExp31Float)
                {
                    return _cvt_ftoi_fast(value);
                }

                if (!(value < twoExp63Float && value > -twoExp63Float))
                {
                    return 0x80000000_00000000;
                }

                /* At this point, the exponent is at-least 31 and less-than 64.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                int asInt = *(cast(const(int)*) &value);

                uint sign = asInt >> 31;
                assert(sign == 0 || sign == -1);

                /* The exponent is biased by +127, but we subtract only 126 as we want the exponent
                   to be one-higher than it actually is, so that we shift the correct number of bits
                   after we mask the exponent by 31.
                   E.g. with an exponent of 31 we should shift 0 bits, 32 should shift 1 bit, etc.. */
                byte exponent = cast(byte) ((cast(ubyte) (asInt >>> 23)) - 126);
                assert(exponent >= 32);
                assert(exponent <= 63);

                /* We have 23-bits stored for the significand, and we know that the exponent is
                   at-least 31, which means that we can shift left unconditionally by 8, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit.
                   Conveniently, this means that the variable shifting for the exponent concerns only
                   the high half (remember that this is for 32-bit mode). */
                uint unadjustedSignificand = (asInt << 8) | (1 << 31);

                /* If the sign bit is set, we need to negate the significand; we can do that branchlessly
                   by taking advantage of the fact that `sign` is either 0 or -1.
                   As `(s ^ 0) - 0 == s`, whereas `(s ^ -1) - -1 == -s`. */
                uint significand = (unadjustedSignificand ^ sign) - sign;
                assert(sign == 0 ? significand == unadjustedSignificand : significand == -unadjustedSignificand);

                uint highHalf = funnelShiftLeft(significand, sign, exponent & 31);

                return (ulong(highHalf) << 32) | ulong(significand << (exponent & 31));
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoll_sent(0.0f) == 0);
                assert(_cvt_ftoll_sent(-0.0f) == 0);
                assert(_cvt_ftoll_sent(float.nan) == -9223372036854775808);
                assert(_cvt_ftoll_sent(-float.nan) == -9223372036854775808);
                assert(_cvt_ftoll_sent(float.infinity) == -9223372036854775808);
                assert(_cvt_ftoll_sent(-float.infinity) == -9223372036854775808);
                assert(_cvt_ftoll_sent(1.0f) == 1);
                assert(_cvt_ftoll_sent(-1.0f) == -1);
                assert(_cvt_ftoll_sent(2.5f) == 2);
                assert(_cvt_ftoll_sent(-2.5f) == -2);
                assert(_cvt_ftoll_sent(3.5f) == 3);
                assert(_cvt_ftoll_sent(-3.5f) == -3);
                assert(_cvt_ftoll_sent(3.49f) == 3);
                assert(_cvt_ftoll_sent(-3.49f) == -3);
                assert(_cvt_ftoll_sent(twoExp31Float) == 2147483648);
                assert(_cvt_ftoll_sent(-twoExp31Float) == -2147483648);
                assert(_cvt_ftoll_sent(twoExp63Float) == -9223372036854775808);
                assert(_cvt_ftoll_sent(-twoExp63Float) == -9223372036854775808);
                assert(_cvt_ftoll_sent(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_ftoll_sent(33554432.0f) == 33554432);
                assert(_cvt_ftoll_sent(-33554432.0f) == -33554432);
                assert(_cvt_ftoll_sent(33554436.0f) == 33554436);
                assert(_cvt_ftoll_sent(-33554436.0f) == -33554436);
                assert(_cvt_ftoll_sent(70369281048576.0f) == 70369281048576);
                assert(_cvt_ftoll_sent(-70369281048576.0f) == -70369281048576);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        uint _cvt_ftoui_sent(float value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                const integer = cast(ulong) _cvt_ftoll_fast(value);

                return integer > uint.max ? uint.max : cast(uint) integer;
            }
            else version (X86)
            {
                if (*(cast(const(uint)*) &value) <= 0b1_01111111_00000000000000000000000)
                {
                    /* If the hardware can handle it, let it handle it. */
                    if (value < twoExp31Float)
                    {
                        return cast(uint) _cvt_ftoi_fast(value);
                    }
                    else if (value < twoExp32Float)
                    {
                        /* At this point, the exponent is 31,
                           Because the exponent is at-least 23, the value will never actually contain any
                           fractional digits, so we can just shift the significand left to get an integer. */

                        /* We have 23-bits stored for the significand, and we know that the exponent is 31,
                           which means that we can just shift left unconditionally by 8, which leaves
                           the implicit bit of the full 24-bit significand to be set at the most-significant bit. */
                        return (*(cast(const(uint)*) &value) << 8) | (1 << 31);
                    }
                }

                return uint.max;
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoui_sent(0.0f) == 0);
                assert(_cvt_ftoui_sent(-0.0f) == 0);
                assert(_cvt_ftoui_sent(float.nan) == 4294967295);
                assert(_cvt_ftoui_sent(-float.nan) == 4294967295);
                assert(_cvt_ftoui_sent(float.infinity) == 4294967295);
                assert(_cvt_ftoui_sent(-float.infinity) == 4294967295);
                assert(_cvt_ftoui_sent(1.0f) == 1);
                assert(_cvt_ftoui_sent(-1.0f) == 4294967295);
                assert(_cvt_ftoui_sent(2.5f) == 2);
                assert(_cvt_ftoui_sent(-2.5f) == 4294967295);
                assert(_cvt_ftoui_sent(3.5f) == 3);
                assert(_cvt_ftoui_sent(-3.5f) == 4294967295);
                assert(_cvt_ftoui_sent(3.49f) == 3);
                assert(_cvt_ftoui_sent(-3.49f) == 4294967295);
                assert(_cvt_ftoui_sent(twoExp31Float) == 2147483648);
                assert(_cvt_ftoui_sent(-twoExp31Float) == 4294967295);
                assert(_cvt_ftoui_sent(twoExp63Float) == 4294967295);
                assert(_cvt_ftoui_sent(-twoExp63Float) == 4294967295);
                assert(_cvt_ftoui_sent(justUnderTwoExp63Float) == 4294967295);
                assert(_cvt_ftoui_sent(33554432.0f) == 33554432);
                assert(_cvt_ftoui_sent(-33554432.0f) == 4294967295);
                assert(_cvt_ftoui_sent(33554436.0f) == 33554436);
                assert(_cvt_ftoui_sent(-33554436.0f) == 4294967295);
                assert(_cvt_ftoui_sent(70369281048576.0f) == 4294967295);
                assert(_cvt_ftoui_sent(-70369281048576.0f) == 4294967295);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        ulong _cvt_ftoull_sent(float value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                if (value < -1.0f || value != value)
                {
                    return ulong.max;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp63Float)
                {
                    return cast(ulong) _cvt_ftoll_fast(value);
                }

                if (value >= twoExp64Float)
                {
                    return ulong.max;
                }

                /* At this point, the exponent is 63.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                /* We have 23-bits stored for the significand, and we know that the exponent is 63,
                   which means that we can just shift left unconditionally by 40, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit. */
                return (ulong(*(cast(const(uint)*) &value)) << 40) | (ulong(1) << 63);
            }
            else version (X86)
            {
                if (value < -1.0f || value != value)
                {
                    return ulong.max;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Float)
                {
                    return cast(ulong) _cvt_ftoi_fast(value);
                }

                if (value >= twoExp64Float)
                {
                    return ulong.max;
                }

                /* At this point, the exponent is at-least 31 and less-than 64.
                   Because the exponent is at-least 23, the value will never actually contain any
                   fractional digits, so we can just shift the significand left to get an integer. */

                int asInt = *(cast(const(int)*) &value);

                /* The exponent is biased by +127, but we subtract only 126 as we want the exponent
                   to be one-higher than it actually is, so that we shift the correct number of bits
                   after we mask the exponent by 31.
                   E.g. with an exponent of 31 we should shift 0 bits, 32 should shift 1 bit, etc.. */
                byte exponent = cast(byte) ((cast(ubyte) (asInt >>> 23)) - 126);
                assert(exponent >= 32);
                assert(exponent <= 64);

                /* We have 23-bits stored for the significand, and we know that the exponent is
                   at-least 31, which means that we can shift left unconditionally by 8, which leaves
                   the implicit bit of the full 24-bit significand to be set at the most-significant bit.
                   Conveniently, this means that the variable shifting for the exponent concerns only
                   the high half (remember that this is for 32-bit mode). */
                uint significand = (asInt << 8) | (1 << 31);

                return ulong(significand) << (exponent == 64 ? 32 : (exponent & 31));
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_ftoull_sent(0.0f) == 0);
                assert(_cvt_ftoull_sent(-0.0f) == 0);
                assert(_cvt_ftoull_sent(float.nan) == 18446744073709551615);
                assert(_cvt_ftoull_sent(-float.nan) == 18446744073709551615);
                assert(_cvt_ftoull_sent(float.infinity) == 18446744073709551615);
                assert(_cvt_ftoull_sent(-float.infinity) == 18446744073709551615);
                assert(_cvt_ftoull_sent(1.0f) == 1);
                assert(_cvt_ftoull_sent(-1.0f) == 18446744073709551615);
                assert(_cvt_ftoull_sent(2.5f) == 2);
                assert(_cvt_ftoull_sent(-2.5f) == 18446744073709551615);
                assert(_cvt_ftoull_sent(3.5f) == 3);
                assert(_cvt_ftoull_sent(-3.5f) == 18446744073709551615);
                assert(_cvt_ftoull_sent(3.49f) == 3);
                assert(_cvt_ftoull_sent(-3.49f) == 18446744073709551615);
                assert(_cvt_ftoull_sent(twoExp31Float) == 2147483648);
                assert(_cvt_ftoull_sent(-twoExp31Float) == 18446744073709551615);
                assert(_cvt_ftoull_sent(twoExp63Float) == 9223372036854775808);
                assert(_cvt_ftoull_sent(-twoExp63Float) == 18446744073709551615);
                assert(_cvt_ftoull_sent(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_ftoull_sent(33554432.0f) == 33554432);
                assert(_cvt_ftoull_sent(-33554432.0f) == 18446744073709551615);
                assert(_cvt_ftoull_sent(33554436.0f) == 33554436);
                assert(_cvt_ftoull_sent(-33554436.0f) == 18446744073709551615);
                assert(_cvt_ftoull_sent(70369281048576.0f) == 70369281048576);
                assert(_cvt_ftoull_sent(-70369281048576.0f) == 18446744073709551615);

                return true;
            }

            assert(test());
            static assert(test());
        }

        extern(C)
        pragma(inline, true)
        int _cvt_dtoi_sent(double value) @safe pure nothrow @nogc
        {
            return _cvt_dtoi_fast(value);
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoi_sent(0.0) == 0);
                assert(_cvt_dtoi_sent(-0.0) == 0);
                assert(_cvt_dtoi_sent(float.nan) == -2147483648);
                assert(_cvt_dtoi_sent(-float.nan) == -2147483648);
                assert(_cvt_dtoi_sent(float.infinity) == -2147483648);
                assert(_cvt_dtoi_sent(-float.infinity) == -2147483648);
                assert(_cvt_dtoi_sent(1.0) == 1);
                assert(_cvt_dtoi_sent(-1.0) == -1);
                assert(_cvt_dtoi_sent(2.5) == 2);
                assert(_cvt_dtoi_sent(-2.5) == -2);
                assert(_cvt_dtoi_sent(3.5) == 3);
                assert(_cvt_dtoi_sent(-3.5) == -3);
                assert(_cvt_dtoi_sent(3.49) == 3);
                assert(_cvt_dtoi_sent(-3.49) == -3);
                assert(_cvt_dtoi_sent(twoExp31Float) == -2147483648);
                assert(_cvt_dtoi_sent(-twoExp31Float) == -2147483648);
                assert(_cvt_dtoi_sent(twoExp63Float) == -2147483648);
                assert(_cvt_dtoi_sent(-twoExp63Float) == -2147483648);
                assert(_cvt_dtoi_sent(justUnderTwoExp63Float) == -2147483648);
                assert(_cvt_dtoi_sent(33554432.0) == 33554432);
                assert(_cvt_dtoi_sent(-33554432.0) == -33554432);
                assert(_cvt_dtoi_sent(33554436.0) == 33554436);
                assert(_cvt_dtoi_sent(-33554436.0) == -33554436);
                assert(_cvt_dtoi_sent(70369281048576.0) == -2147483648);
                assert(_cvt_dtoi_sent(-70369281048576.0) == -2147483648);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        uint _cvt_dtoui_sent(double value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                const integer = cast(ulong) _cvt_dtoll_fast(value);

                return integer > uint.max ? uint.max : cast(uint) integer;
            }
            else version (X86)
            {
                if (
                       *(cast(const(ulong)*) &value)
                    <= 0b1_01111111111_0000000000000000000000000000000000000000000000000000
                )
                {
                    /* If the hardware can handle it, let it handle it. */
                    if (value < twoExp31Double)
                    {
                        return cast(uint) _cvt_dtoi_fast(value);
                    }
                    else if (value < twoExp32Double)
                    {
                        /* At this point, the exponent is 31. */

                        /* We have 52-bits stored for the significand, and we know that the exponent is 31,
                           which means that we can just shift left unconditionally by 21 (52 - 31), which leaves
                           the implicit bit of the full 53-bit significand to be set at the most-significant bit. */
                        return cast(uint) (*(cast(const(ulong)*) &value) >>> 21) | (1 << 31);
                    }
                }

                return uint.max;
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoui_sent(0.0) == 0);
                assert(_cvt_dtoui_sent(-0.0) == 0);
                assert(_cvt_dtoui_sent(float.nan) == 4294967295);
                assert(_cvt_dtoui_sent(-float.nan) == 4294967295);
                assert(_cvt_dtoui_sent(float.infinity) == 4294967295);
                assert(_cvt_dtoui_sent(-float.infinity) == 4294967295);
                assert(_cvt_dtoui_sent(1.0) == 1);
                assert(_cvt_dtoui_sent(-1.0) == 4294967295);
                assert(_cvt_dtoui_sent(2.5) == 2);
                assert(_cvt_dtoui_sent(-2.5) == 4294967295);
                assert(_cvt_dtoui_sent(3.5) == 3);
                assert(_cvt_dtoui_sent(-3.5) == 4294967295);
                assert(_cvt_dtoui_sent(3.49) == 3);
                assert(_cvt_dtoui_sent(-3.49) == 4294967295);
                assert(_cvt_dtoui_sent(twoExp31Float) == 2147483648);
                assert(_cvt_dtoui_sent(-twoExp31Float) == 4294967295);
                assert(_cvt_dtoui_sent(twoExp63Float) == 4294967295);
                assert(_cvt_dtoui_sent(-twoExp63Float) == 4294967295);
                assert(_cvt_dtoui_sent(justUnderTwoExp63Float) == 4294967295);
                assert(_cvt_dtoui_sent(33554432.0) == 33554432);
                assert(_cvt_dtoui_sent(-33554432.0) == 4294967295);
                assert(_cvt_dtoui_sent(33554436.0) == 33554436);
                assert(_cvt_dtoui_sent(-33554436.0) == 4294967295);
                assert(_cvt_dtoui_sent(70369281048576.0) == 4294967295);
                assert(_cvt_dtoui_sent(-70369281048576.0) == 4294967295);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        long _cvt_dtoll_sent(double value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                return _cvt_dtoll_fast(value);
            }
            else version (X86)
            {
                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Double && value >= -twoExp31Double)
                {
                    return _cvt_dtoi_fast(value);
                }

                if (!(value < twoExp63Double && value > -twoExp63Double))
                {
                    return 0x80000000_00000000;
                }

                /* At this point, the exponent is at-least 31 and less-than 63. */

                long asInt = *(cast(const(long)*) &value);

                uint high = cast(uint) (asInt >>> 32);
                uint low = cast(uint) asInt;

                long sign = (cast(int) high) >> 31;
                assert(sign == 0 || sign == -1);

                int exponent = ((high >>> 20) & 2047) - 1023;
                assert(exponent >= 31);
                assert(exponent <= 62);

                ulong significand = (ulong((high & 0b00000000_00001111_11111111_11111111) | (1 << 20)) << 32) | low;
                uint shiftCount = (exponent < 52 ? 52 : exponent) - (exponent < 52 ? exponent : 52);

                if (exponent < 52)
                {
                    significand >>>= (shiftCount & 63);
                }
                else
                {
                    significand <<= (shiftCount & 63);
                }

                /* If the sign bit is set, we need to negate the significand; we can do that branchlessly
                   by taking advantage of the fact that `sign` is either 0 or -1.
                   As `(s ^ 0) - 0 == s`, whereas `(s ^ -1) - -1 == -s`. */
                ulong adjustedSignificand = (significand ^ sign) - sign;
                assert(sign == 0 ? adjustedSignificand == significand : adjustedSignificand == -significand);

                return adjustedSignificand;
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoll_sent(0.0) == 0);
                assert(_cvt_dtoll_sent(-0.0) == 0);
                assert(_cvt_dtoll_sent(float.nan) == -9223372036854775808);
                assert(_cvt_dtoll_sent(-float.nan) == -9223372036854775808);
                assert(_cvt_dtoll_sent(float.infinity) == -9223372036854775808);
                assert(_cvt_dtoll_sent(-float.infinity) == -9223372036854775808);
                assert(_cvt_dtoll_sent(1.0) == 1);
                assert(_cvt_dtoll_sent(-1.0) == -1);
                assert(_cvt_dtoll_sent(2.5) == 2);
                assert(_cvt_dtoll_sent(-2.5) == -2);
                assert(_cvt_dtoll_sent(3.5) == 3);
                assert(_cvt_dtoll_sent(-3.5) == -3);
                assert(_cvt_dtoll_sent(3.49) == 3);
                assert(_cvt_dtoll_sent(-3.49) == -3);
                assert(_cvt_dtoll_sent(twoExp31Float) == 2147483648);
                assert(_cvt_dtoll_sent(-twoExp31Float) == -2147483648);
                assert(_cvt_dtoll_sent(twoExp63Float) == -9223372036854775808);
                assert(_cvt_dtoll_sent(-twoExp63Float) == -9223372036854775808);
                assert(_cvt_dtoll_sent(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_dtoll_sent(33554432.0) == 33554432);
                assert(_cvt_dtoll_sent(-33554432.0) == -33554432);
                assert(_cvt_dtoll_sent(33554436.0) == 33554436);
                assert(_cvt_dtoll_sent(-33554436.0) == -33554436);
                assert(_cvt_dtoll_sent(70369281048576.0) == 70369281048576);
                assert(_cvt_dtoll_sent(-70369281048576.0) == -70369281048576);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        extern(C)
        pragma(inline, true)
        ulong _cvt_dtoull_sent(double value) @trusted pure nothrow @nogc
        {
            version (X86_64)
            {
                if (value < -1.0 || value != value)
                {
                    return ulong.max;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp63Double)
                {
                    return cast(ulong) _cvt_dtoll_fast(value);
                }

                if (value >= twoExp64Double)
                {
                    return ulong.max;
                }

                /* At this point, the exponent is 63. */

                /* We have 52-bits stored for the significand, and we know that the exponent is 63,
                   which means that we can just shift left unconditionally by 11 (63 - 52), which leaves
                   the implicit bit of the full 53-bit significand to be set at the most-significant bit. */
                return (*(cast(const(ulong)*) &value) << 11) | (ulong(1) << 63);
            }
            else version (X86)
            {
                if (value < -1.0 || value != value)
                {
                    return ulong.max;
                }

                /* If the hardware can handle it, let it handle it. */
                if (value < twoExp31Double)
                {
                    return cast(ulong) _cvt_dtoi_fast(value);
                }

                if (value >= twoExp64Double)
                {
                    return ulong.max;
                }

                /* At this point, the exponent is at-least 31 and less-than 64. */

                long asInt = *(cast(const(long)*) &value);

                uint high = cast(uint) (asInt >>> 32);
                uint low = cast(uint) asInt;

                int exponent = ((high >>> 20) & 2047) - 1023;
                assert(exponent >= 31);
                assert(exponent <= 63);

                ulong significand = (ulong((high & 0b00000000_00001111_11111111_11111111) | (1 << 20)) << 32) | low;
                uint shiftCount = (exponent < 52 ? 52 : exponent) - (exponent < 52 ? exponent : 52);

                if (exponent < 52)
                {
                    significand >>>= (shiftCount & 63);
                }
                else
                {
                    significand <<= (shiftCount & 63);
                }

                return significand;
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_cvt_dtoull_sent(0.0) == 0);
                assert(_cvt_dtoull_sent(-0.0) == 0);
                assert(_cvt_dtoull_sent(float.nan) == 18446744073709551615);
                assert(_cvt_dtoull_sent(-float.nan) == 18446744073709551615);
                assert(_cvt_dtoull_sent(float.infinity) == 18446744073709551615);
                assert(_cvt_dtoull_sent(-float.infinity) == 18446744073709551615);
                assert(_cvt_dtoull_sent(1.0) == 1);
                assert(_cvt_dtoull_sent(-1.0) == 18446744073709551615);
                assert(_cvt_dtoull_sent(2.5) == 2);
                assert(_cvt_dtoull_sent(-2.5) == 18446744073709551615);
                assert(_cvt_dtoull_sent(3.5) == 3);
                assert(_cvt_dtoull_sent(-3.5) == 18446744073709551615);
                assert(_cvt_dtoull_sent(3.49) == 3);
                assert(_cvt_dtoull_sent(-3.49) == 18446744073709551615);
                assert(_cvt_dtoull_sent(twoExp31Float) == 2147483648);
                assert(_cvt_dtoull_sent(-twoExp31Float) == 18446744073709551615);
                assert(_cvt_dtoull_sent(twoExp63Float) == 9223372036854775808);
                assert(_cvt_dtoull_sent(-twoExp63Float) == 18446744073709551615);
                assert(_cvt_dtoull_sent(justUnderTwoExp63Float) == 9223371487098961920);
                assert(_cvt_dtoull_sent(33554432.0) == 33554432);
                assert(_cvt_dtoull_sent(-33554432.0) == 18446744073709551615);
                assert(_cvt_dtoull_sent(33554436.0) == 33554436);
                assert(_cvt_dtoull_sent(-33554436.0) == 18446744073709551615);
                assert(_cvt_dtoull_sent(70369281048576.0) == 70369281048576);
                assert(_cvt_dtoull_sent(-70369281048576.0) == 18446744073709551615);

                return true;
            }

            assert(test());
            static assert(test());
        }
    }

    version (X86_64_Or_X86)
    {
        void __halt() @safe nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                asm @trusted nothrow @nogc
                {
                    "hlt";
                }
            }
            else version (InlineAsm_X86_64_Or_X86)
            {
                asm @trusted nothrow @nogc
                {
                    hlt;
                }
            }
            else
            {
                static assert(false);
            }
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        ubyte __readgsbyte(uint Offset) nothrow @nogc
        {
            return manipulateMemoryThroughTIBSegmentRegister!(ubyte)(Offset);
        }

        extern(C)
        pragma(inline, true)
        ushort __readgsword(uint Offset) nothrow @nogc
        {
            return manipulateMemoryThroughTIBSegmentRegister!(ushort)(Offset);
        }

        extern(C)
        pragma(inline, true)
        uint __readgsdword(uint Offset) nothrow @nogc
        {
            return manipulateMemoryThroughTIBSegmentRegister!(uint)(Offset);
        }

        extern(C)
        pragma(inline, true)
        ulong __readgsqword(uint Offset) nothrow @nogc
        {
            return manipulateMemoryThroughTIBSegmentRegister!(ulong)(Offset);
        }

        extern(C)
        pragma(inline, true)
        void __writegsbyte(uint Offset, ubyte Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, null, ubyte)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __writegsword(uint Offset, ushort Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, null, ushort)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __writegsdword(uint Offset, uint Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, null, uint)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __writegsqword(uint Offset, ulong Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, null, ulong)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __addgsbyte(uint Offset, ubyte Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, "+", ubyte)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __addgsword(uint Offset, ushort Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, "+", ushort)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __addgsdword(uint Offset, uint Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, "+", uint)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __addgsqword(uint Offset, ulong Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, "+", ulong)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __incgsbyte(uint Offset) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(ubyte, "++")(Offset);
        }

        extern(C)
        pragma(inline, true)
        void __incgsword(uint Offset) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(ushort, "++")(Offset);
        }

        extern(C)
        pragma(inline, true)
        void __incgsdword(uint Offset) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(uint, "++")(Offset);
        }

        extern(C)
        pragma(inline, true)
        void __incgsqword(uint Offset) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(ulong, "++")(Offset);
        }
    }

    version (X86)
    {
        extern(C)
        pragma(inline, true)
        ubyte __readfsbyte(uint Offset) nothrow @nogc
        {
            return manipulateMemoryThroughTIBSegmentRegister!(ubyte)(Offset);
        }

        extern(C)
        pragma(inline, true)
        ushort __readfsword(uint Offset) nothrow @nogc
        {
            return manipulateMemoryThroughTIBSegmentRegister!(ushort)(Offset);
        }

        extern(C)
        pragma(inline, true)
        uint __readfsdword(uint Offset) nothrow @nogc
        {
            return manipulateMemoryThroughTIBSegmentRegister!(uint)(Offset);
        }

        extern(C)
        pragma(inline, true)
        ulong __readfsqword(uint Offset) nothrow @nogc
        {
            return manipulateMemoryThroughTIBSegmentRegister!(ulong)(Offset);
        }

        extern(C)
        pragma(inline, true)
        void __writefsbyte(uint Offset, ubyte Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, null, ubyte)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __writefsword(uint Offset, ushort Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, null, ushort)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __writefsdword(uint Offset, uint Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, null, uint)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __writefsqword(uint Offset, ulong Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, null, ulong)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __addfsbyte(uint Offset, ubyte Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, "+", ubyte)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __addfsword(uint Offset, ushort Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, "+", ushort)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __addfsdword(uint Offset, uint Data) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(void, "+", uint)(Offset, Data);
        }

        extern(C)
        pragma(inline, true)
        void __incfsbyte(uint Offset) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(ubyte, "++")(Offset);
        }

        extern(C)
        pragma(inline, true)
        void __incfsword(uint Offset) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(ushort, "++")(Offset);
        }

        extern(C)
        pragma(inline, true)
        void __incfsdword(uint Offset) nothrow @nogc
        {
            manipulateMemoryThroughTIBSegmentRegister!(uint, "++")(Offset);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        private
        mixin(Args.length == 0 && operator == null ? "Integer" : "void")
        manipulateMemoryThroughTIBSegmentRegister(
            Integer = void,
            string operator = null,
            Args...
        )(
            uint offset,
            Args args
        ) nothrow @nogc
        if (
              Args.length == 1
            ? (is(Integer == void) && __traits(isIntegral, Args[0]) && (operator == null || operator == "+"))
            : (Args.length == 0 && __traits(isIntegral, Integer) && (operator == null || operator == "++"))
        )
        {
            enum bool reading = Args.length == 0 && operator == null;
            static if (Args.length == 0) alias Int = Integer; else alias Int = Args[0];

            version (LDC)
            {
                import core.bitop : bsr;
                import ldc.llvmasm : __ir;

                     version (X86) enum addressSpace = "addrspace(257)";
                else version (X86_64) enum addressSpace = "addrspace(256)";

                enum size = Int.sizeof.bsr;
                enum type = ["i8", "i16", "i32", "i64"][size];
                enum ptr = llvmIRPtr!(type, addressSpace);

                enum loadValue = "%address = inttoptr i32 %0 to " ~ ptr ~ ";
                                  %data = load " ~ type ~ ", " ~ ptr ~ " %address;\n";

                static if (reading)
                {
                    return __ir!(
                        loadValue ~ "ret " ~ type ~ " %data;",
                        Int
                    )(offset);
                }
                else
                {
                    static if (operator == null)
                    {
                        enum code = "%address = inttoptr i32 %0 to " ~ ptr ~ ";
                                     store " ~ type ~ " %1, " ~ ptr ~ " %address;";
                    }
                    else static if (operator == "++")
                    {
                        enum code = loadValue
                                    ~ "%changed = add " ~ type ~ " %data, 1;
                                    store " ~ type ~ " %changed, " ~ ptr ~ " %address;";
                    }
                    else static if (operator == "+")
                    {
                        enum code = loadValue
                                    ~ "%changed = add " ~ type ~ " %data, %1;
                                    store " ~ type ~ " %changed, " ~ ptr ~ " %address;";
                    }

                    __ir!(code, void)(offset, args);
                }
            }
            else version (GNU)
            {
                version (X86)
                {
                    enum segment = "fs";
                    enum canMoveEightBytes = false;
                }
                else version (X86_64)
                {
                    enum segment = "gs";
                    enum canMoveEightBytes = true;
                }

                static if (reading)
                {
                    static if (Int.sizeof <= 4 || canMoveEightBytes)
                    {
                        Int result;

                        asm nothrow @nogc
                        {
                            "mov " ~ segment ~ ":(%1), %0 " : "=r" (result) : "ri" (offset) : "memory";
                        }

                        return result;
                    }
                    else
                    {
                        uint lo;
                        uint hi;

                        asm nothrow @nogc
                        {
                              "mov " ~ segment ~ ":(%2), %0
                               mov " ~ segment ~ ":4(%2), %1"
                            : "=&r" (lo), "=r" (hi)
                            : "ri" (offset)
                            : "memory";
                        }

                        return lo | (Int(hi) << 32);
                    }
                }
                else
                {
                    static if (operator == null)
                    {
                        static if (Int.sizeof <= 4 || canMoveEightBytes)
                        {
                            asm nothrow @nogc
                            {
                                "mov %1, " ~ segment ~ ":(%0)" : : "ri" (offset), "r" (args[0]) : "memory";
                            }
                        }
                        else
                        {
                            asm nothrow @nogc
                            {
                                  "mov %1, " ~ segment ~ ":(%0)
                                   mov %2, " ~ segment ~ ":4(%0)"
                                :
                                : "ri" (offset), "r" (cast(uint) args[0]), "r" (cast(uint) (args[0] >>> 32))
                                : "memory";
                            }
                        }
                    }
                    else static if (operator == "++")
                    {
                        import core.bitop : bsr;

                        enum char suffix = "bwlq"[Int.sizeof.bsr];

                        asm nothrow @nogc
                        {
                            "inc" ~ suffix ~ " " ~ segment ~ ":(%0)" : : "ri" (offset) : "memory", "cc";
                        }
                    }
                    else static if (operator == "+")
                    {
                        asm nothrow @nogc
                        {
                            "add %1, " ~ segment ~ ":(%0)" : : "ri" (offset), "r" (args[0]) : "memory", "cc";
                        }
                    }
                }
            }
            else version (InlineAsm_X86_64_Or_X86)
            {
                import core.bitop : bsr;

                enum size = Int.sizeof.bsr;

                version (D_InlineAsm_X86_64)
                {
                    static if (reading)
                    {
                        mixin(
                            /* ECX is offset. */
                            "asm nothrow @nogc
                             {
                                 naked;
                                 mov " ~ ["AL", "AX", "EAX", "RAX"][size] ~ ", GS:[ECX];
                                 ret;
                             }"
                        );
                    }
                    else
                    {
                        static if (operator == "++")
                        {
                            mixin(
                                /* ECX is offset. */
                                "asm nothrow @nogc
                                 {
                                     naked;
                                     inc " ~ ["ubyte", "word", "dword", "qword"][size] ~ " ptr GS:[ECX];
                                     ret;
                                 }"
                            );
                        }
                        else static if (operator == "+" || operator == null)
                        {
                            enum op = operator == "+" ? "add" : "mov";

                            mixin(
                                /* ECX is offset; EDX is args[0]. */
                                "asm nothrow @nogc
                                 {
                                     naked;
                                     " ~ op ~ " GS:[ECX], " ~ ["DL", "DX", "EDX", "RDX"][size] ~ ";
                                     ret;
                                 }"
                            );
                        }
                    }
                }
                else version (D_InlineAsm_X86)
                {
                    static if (reading)
                    {
                        static if (size == 3)
                        {
                            asm nothrow @nogc
                            {
                                naked;
                                mov ECX, [ESP + 4]; /* offset. */
                                mov EAX, FS:[ECX];
                                mov EDX, FS:[ECX + 4];
                                ret;
                            }
                        }
                        else static if (size <= 2)
                        {
                            mixin(
                                "asm nothrow @nogc
                                 {
                                     naked;
                                     mov ECX, [ESP + 4]; /* offset. */
                                     mov " ~ ["AL", "AX", "EAX"][size] ~ ", FS:[ECX];
                                     ret;
                                 }"
                            );
                        }
                    }
                    else
                    {
                        static if (size == 3)
                        {
                            asm nothrow @nogc
                            {
                                naked;
                                mov ECX, [ESP +  4]; /* offset. */
                                mov EAX, [ESP +  8]; /* Low half of args[0]. */
                                mov EDX, [ESP + 12]; /* High half of args[0]. */
                                mov FS:[ECX], EAX;
                                mov FS:[ECX + 4], EDX;
                                ret;
                            }
                        }
                        else static if (size <= 2)
                        {
                            static if (operator == "++")
                            {
                                mixin(
                                    "asm nothrow @nogc
                                     {
                                         naked;
                                         mov ECX, [ESP + 4]; /* offset. */
                                         inc " ~ ["ubyte", "word", "dword"][size] ~ " ptr FS:[ECX];
                                         ret;
                                     }"
                                );
                            }
                            else static if (operator == "+" || operator == null)
                            {
                                enum op = operator == "+" ? "add" : "mov";
                                enum source = ["DL", "DX", "EDX"][size];

                                mixin(
                                    "asm nothrow @nogc
                                     {
                                         naked;
                                         mov ECX, [ESP + 4]; /* offset. */
                                         mov " ~ source ~ ", [ESP + 8]; /* args[0] */
                                         " ~ op ~ " FS:[ECX], " ~ source ~ ";
                                         ret;
                                     }"
                                );
                            }
                        }
                    }
                }
            }
            else
            {
                static assert(false);
            }
        }

        version (Windows)
        {
            @trusted nothrow @nogc unittest
            {
                import core.sys.windows.winbase : GetLastError, SetLastError;

                /* The Win32 last-error is stored in the TIB, at an offset of 13-pointers.
                   Immediately after it is is the number of critical-sections.
                   We can use GetLastError and SetLastError as a known good implementation of
                   reading and writing to FS/GS-segmented memory, and so long as we restore
                   the critical-section count to its original value afterwards, we can use it
                   to test the reading and writing of 8-byte values. */

                enum lastErrorOffset = size_t.sizeof * 13;
                enum criticalSectionCountOffset = lastErrorOffset + 4;

                version (X86_64) enum prefix = 'g'; else version (X86) enum prefix = 'f';

                alias addByte = mixin("__add", prefix, "sbyte");
                alias addDword = mixin("__add", prefix, "sdword");
                alias addWord = mixin("__add", prefix, "sword");
                alias incByte = mixin("__inc", prefix, "sbyte");
                alias incDword = mixin("__inc", prefix, "sdword");
                alias incWord = mixin("__inc", prefix, "sword");
                alias readByte = mixin("__read", prefix, "sbyte");
                alias readDword = mixin("__read", prefix, "sdword");
                alias readWord = mixin("__read", prefix, "sword");
                alias readQword = mixin("__read", prefix, "sqword");
                alias writeByte = mixin("__write", prefix, "sbyte");
                alias writeDword = mixin("__write", prefix, "sdword");
                alias writeWord = mixin("__write", prefix, "sword");
                alias writeQword = mixin("__write", prefix, "sqword");

                SetLastError(0x01234567);
                assert(GetLastError()             == 0x01234567);
                assert(readDword(lastErrorOffset) == 0x01234567);
                assert(readWord(lastErrorOffset)  ==     0x4567);
                assert(readByte(lastErrorOffset)  ==       0x67);

                writeDword(lastErrorOffset, 0x89ABCDEF);
                assert(GetLastError() == 0x89ABCDEF);
                writeWord(lastErrorOffset, 0x0123);
                assert(GetLastError() == 0x89AB0123);
                writeByte(lastErrorOffset, 0x45);
                assert(GetLastError() == 0x89AB0145);

                auto originalCriticalSectionCount = readDword(criticalSectionCountOffset);

                writeDword(criticalSectionCountOffset, 0xCAFEBEEF);
                assert(readQword(lastErrorOffset) == 0xCAFEBEEF_89AB0145);

                writeQword(lastErrorOffset, 0x01234567_89ABCDEF);
                assert(readDword(lastErrorOffset)            == 0x89ABCDEF);
                assert(readDword(criticalSectionCountOffset) == 0x01234567);

                incDword(lastErrorOffset);
                assert(readDword(lastErrorOffset) == 0x89ABCDF0);

                incWord(lastErrorOffset + 2);
                assert(readDword(lastErrorOffset) == 0x89ACCDF0);

                incByte(lastErrorOffset + 3);
                assert(readDword(lastErrorOffset) == 0x8AACCDF0);

                addDword(lastErrorOffset, uint(12));
                assert(readDword(lastErrorOffset) == 0x8AACCDFC);

                addWord(lastErrorOffset + 2, ushort(3));
                assert(readDword(lastErrorOffset) == 0x8AAFCDFC);

                addByte(lastErrorOffset + 3, 4);
                assert(readDword(lastErrorOffset) == 0x8EAFCDFC);

                version (X86_64)
                {
                    assert(__readgsqword(lastErrorOffset) == 0x01234567_8EAFCDFC);

                    __incgsqword(lastErrorOffset);
                    assert(__readgsqword(lastErrorOffset) == 0x01234567_8EAFCDFD);

                    __addgsqword(lastErrorOffset, ulong(2));
                    assert(__readgsqword(lastErrorOffset) == 0x01234567_8EAFCDFF);
                }

                writeDword(criticalSectionCountOffset, originalCriticalSectionCount);
            }
        }
    }
    }
}
