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

    import core.atomic : MemoryOrder;

    static if (__traits(compiles, () {import core.simd : float4;}))
    {
        import core.simd : byte16, float4, long2, int4, ubyte16;

        version (X86_64_Or_X86)
        {
            import core.simd : double2;
        }

        private enum canPassVectors = true;
    }
    else
    {
        private enum canPassVectors = false;
    }

    version (LDC)
    {
        version (X86_64_Or_X86)
        {
            pragma(LDC_intrinsic, "llvm.x86.sse2.pause")
            private void __builtin_ia32_pause() @safe pure nothrow @nogc;

            pragma(LDC_intrinsic, "llvm.x86.rdpmc")
            private long __builtin_ia32_rdpmc(int) @safe nothrow @nogc;

            pragma(LDC_intrinsic, "llvm.x86.rdtsc")
            private long __builtin_ia32_rdtsc() @safe nothrow @nogc;
        }
        else version (AArch64)
        {
            pragma(LDC_intrinsic, "llvm.aarch64.dmb")
            private void __builtin_arm_dmb(int) @safe pure nothrow @nogc;
        }
        else version (ARM)
        {
            pragma(LDC_intrinsic, "llvm.arm.dmb")
            private void __builtin_arm_dmb(int) @safe pure nothrow @nogc;
        }
    }
    else version (GNU)
    {
        version (X86_64_Or_X86)
        {
            import gcc.builtins : __builtin_ia32_pause, __builtin_ia32_rdpmc, __builtin_ia32_rdtsc;
        }
    }

    version (X86_64_Or_X86)
    {
        version (X86_64)
        {
            private alias RegisterSized = ulong;
        }
        else version (X86)
        {
            private alias RegisterSized = uint;
        }
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
        void _mm_pause() @safe pure nothrow @nogc
        {
            if (__ctfe)
            {}
            else
            {
                /* core.atomic.pause won't work for BetterC. */
                version (LDC_Or_GNU)
                {
                    __builtin_ia32_pause();
                }
                else version (InlineAsm_X86_64_Or_X86)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        pause;
                        ret;
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                _mm_pause();
                return true;
            }

            assert(test());
            static assert(test());
        }
    }

    version (AArch64_Or_ARM)
    {
        version (GNU)
        {
            extern(C)
            pragma(inline, true)
            void __builtin_arm_dmb(uint Type) @safe pure nothrow @nogc
            {
                armBarrier!"dmb"(Type);
            }

            extern(C)
            pragma(inline, true)
            void __builtin_arm_dsb(uint Type) @safe pure nothrow @nogc
            {
                armBarrier!"dsb"(Type);
            }

            extern(C)
            pragma(inline, true)
            void __builtin_arm_isb(uint Type) @safe pure nothrow @nogc
            {
                armBarrier!"isb"(Type);
            }

            @safe pure nothrow @nogc unittest
            {
                static bool test(alias barrier)()
                {
                    barrier(0xF);
                    barrier(0xE);
                    barrier(0xB);
                    barrier(0xA);
                    barrier(0x7);
                    barrier(0x6);
                    barrier(0x3);
                    barrier(0x2);

                    try
                    {
                        barrier(0);
                    }
                    catch (AssertError)
                    {
                        return true;
                    }

                    assert(false);
                }

                assert(test!__builtin_arm_dmb());
                static assert(test!__builtin_arm_dmb());
                assert(test!__builtin_arm_dsb());
                static assert(test!__builtin_arm_dsb());
                assert(test!__builtin_arm_isb());
                static assert(test!__builtin_arm_isb());
            }

            extern(C)
            pragma(inline, true)
            private void armBarrier(string barrier)(uint type) @safe pure nothrow @nogc
            {
                enum assertMessage = "Invalid Type supplied to __" ~ barrier ~ ".";

                switch (type)
                {
                case 0xF:
                    if (__ctfe)
                    {}
                    else
                    {
                        asm @trusted pure nothrow @nogc {"" ~ barrier ~ " sy" : : : "memory";} break;
                    }
                    break;
                case 0xE:
                    if (__ctfe)
                    {}
                    else
                    {
                        asm @trusted pure nothrow @nogc {"" ~ barrier ~ " st" : : : "memory";} break;
                    }
                    break;
                case 0xB:
                    if (__ctfe)
                    {}
                    else
                    {
                        asm @trusted pure nothrow @nogc {"" ~ barrier ~ " ish" : : : "memory";} break;
                    }
                    break;
                case 0xA:
                    if (__ctfe)
                    {}
                    else
                    {
                        asm @trusted pure nothrow @nogc {"" ~ barrier ~ " ishst" : : : "memory";} break;
                    }
                    break;
                case 0x7:
                    if (__ctfe)
                    {}
                    else
                    {
                        asm @trusted pure nothrow @nogc {"" ~ barrier ~ " nsh" : : : "memory";} break;
                    }
                    break;
                case 0x6:
                    if (__ctfe)
                    {}
                    else
                    {
                        asm @trusted pure nothrow @nogc {"" ~ barrier ~ " nshst" : : : "memory";} break;
                    }
                    break;
                case 0x3:
                    if (__ctfe)
                    {}
                    else
                    {
                        asm @trusted pure nothrow @nogc {"" ~ barrier ~ " osh" : : : "memory";} break;
                    }
                    break;
                case 0x2:
                    if (__ctfe)
                    {}
                    else
                    {
                        asm @trusted pure nothrow @nogc {"" ~ barrier ~ " oshst" : : : "memory";} break;
                    }
                    break;
                default:
                    assert(false, assertMessage);
                }
            }
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

    extern(C)
    pragma(inline, true)
    void __debugbreak() @safe pure nothrow @nogc
    {
        version (LDC)
        {
            import ldc.intrinsics : llvm_debugtrap;
            llvm_debugtrap();
        }
        else version (GNU)
        {
                 version (X86_64_Or_X86) enum code = "int $3";
            else version (ARM) enum code = "udf #0xFE";
            else version (AArch64) enum code = "brk #0xF000";

            asm @trusted pure nothrow @nogc
            {
                "" ~ code : : : "cc";
            }
        }
        else version (InlineAsm_X86_64_Or_X86)
        {
            asm @trusted pure nothrow @nogc
            {
                naked;
                int 3;
                ret;
            }
        }
        else
        {
            static assert(false);
        }
    }

    version (none)
    {
        @safe pure nothrow @nogc unittest
        {
            /* Run the program in a debugger and it should break here. */
            __debugbreak();
        }
    }

    extern(C)
    pragma(inline, true)
    noreturn __fastfail(uint code) @safe pure nothrow @nogc
    {
        if (__ctfe)
        {
            version (D_BetterC)
            {
                assert(false, "__fastfail(code)");
            }
            else
            {
                import core.internal.string : unsignedToTempString;
                assert(false, "__fastfail(" ~ unsignedToTempString(code) ~ ")");
            }
        }
        else
        {
            version (LDC_Or_GNU)
            {
                version (X86_64_Or_X86)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        "int $41" : : "c" (code);
                    }
                }
                else version (ARM)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        "mov r0, %0
                         udf #0xFB"
                        :
                        : "ir" (code);
                    }
                }
                else version (AArch64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        "mov x0, %0
                         brk #0xF003"
                        :
                        : "ir" (code);
                    }
                }
            }
            else version (D_InlineAsm_X86_64)
            {
                asm @trusted pure nothrow @nogc
                {
                    /* ECX is code. */
                    naked;
                    int 41;
                    ret;
                }
            }
            else version (D_InlineAsm_X86)
            {
                asm @trusted pure nothrow @nogc
                {
                    naked;
                    mov ECX, [ESP + 4]; /* code. */
                    int 41;
                    ret;
                }
            }
            else
            {
                static assert(false);
            }

            version (LDC)
            {
                import ldc.llvmasm : __ir_pure;
                __ir_pure!("unreachable", noreturn)();
            }
            else version (GNU)
            {
                import gcc.builtins : __builtin_unreachable;
                __builtin_unreachable();
                assert(false);
            }
            else
            {
                assert(false);
            }
        }
    }

    version (none)
    {
        @safe pure nothrow @nogc unittest
        {
            /* Run the program and it should crash here. Afterwards, in Windows PowerShell,
               run `Get-EventLog -LogName Application -EntryType Error -Newest 1 | Format-List`,
               and assuming no others errors have happened since, this program's crash should be returned
               and the "Exception code" in the `Message` field should be 0xc0000409. */
            __fastfail(7);
        }
    }

    @safe pure nothrow @nogc
    {
        static assert(__traits(compiles, __fastfail(7)));

        static assert(
            !__traits(
                compiles,
                ()
                {
                    enum bool fastFailDuringCTFE = ()
                    {
                        __fastfail(7);
                        return true;
                    }();
                }
            )
        );
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        void __faststorefence() @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                /* Just do nothing. */
            }
            else
            {
                version (LDC_Or_GNU)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        "lock orl $0, (%%rsp)" : : : "cc";
                    }
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        lock; or dword ptr [RSP], 0;
                        ret;
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                __faststorefence();
                return true;
            }

            assert(test());
            static assert(test());
        }
    }

    extern(C)
    pragma(inline, true)
    void _disable() @safe nothrow @nogc
    {
        version (LDC_Or_GNU)
        {
            version (X86_64_Or_X86) enum code = "cli";
            else version (ARM) enum code = "cpsid i";
            else version (AArch64) enum code = "msr daifset, #2";

            asm @trusted pure nothrow @nogc
            {
                "" ~ code : : : "cc";
            }
        }
        else version (InlineAsm_X86_64_Or_X86)
        {
            asm @trusted pure nothrow @nogc
            {
                cli;
            }
        }
    }

    extern(C)
    pragma(inline, true)
    void _enable() @safe nothrow @nogc
    {
        version (LDC_Or_GNU)
        {
            version (X86_64_Or_X86) enum code = "sti";
            else version (ARM) enum code = "cpsie i";
            else version (AArch64) enum code = "msr daifclr, #2";

            asm @trusted pure nothrow @nogc
            {
                "" ~ code : : : "cc";
            }
        }
        else version (InlineAsm_X86_64_Or_X86)
        {
            asm @trusted pure nothrow @nogc
            {
                sti;
            }
        }
    }

    extern(C)
    pragma(inline, true)
    int _interlockedadd(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
    {
        return interlockedAdd(Addend, Value);
    }

    extern(C)
    pragma(inline, true)
    long _interlockedadd64(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
    {
        import core.internal.atomic : atomicFetchAdd;

        static if (__traits(compiles, atomicFetchAdd(Addend, Value)))
        {
            if (__ctfe)
            {
                return *((a) @trusted => cast(long*) Addend)(Addend) += Value;
            }
            else
            {
                return atomicFetchAdd(Addend, Value) + Value;
            }
        }
        else
        {
            return interlockedOp!("rmw_add", "add_8", "+", MemoryOrder.seq, true)(Addend, Value) + Value;
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedAdd(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
        {
            return interlockedAdd(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedAdd_acq(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedAdd_rel(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq_rel)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedAdd_nf(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.raw)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAdd64(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedAdd(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAdd64_acq(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAdd64_rel(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq_rel)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAdd64_nf(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.raw)(Addend, Value);
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static bool test()
        {
            shared int intValue = 0x2ACD0123;
            shared long longValue = 0x12345678_2ACD0123;

            assert(_interlockedadd(&intValue, 0x10000000) == 0x3ACD0123);
            assert(intValue == 0x3ACD0123);

            assert(_interlockedadd64(&longValue, 0x10000000_00000001) == 0x22345678_2ACD0124);
            assert(longValue == 0x22345678_2ACD0124);

            version (AArch64_Or_ARM)
            {
                assert(_InterlockedAdd(&intValue, 0x10000000) == 0x4ACD0123);
                assert(intValue == 0x4ACD0123);
                assert(_InterlockedAdd_acq(&intValue, 0x10000000) == 0x5ACD0123);
                assert(intValue == 0x5ACD0123);
                assert(_InterlockedAdd_rel(&intValue, 0x10000000) == 0x6ACD0123);
                assert(intValue == 0x6ACD0123);
                assert(_InterlockedAdd_nf(&intValue, 0x10000000) == 0x7ACD0123);
                assert(intValue == 0x7ACD0123);

                assert(_InterlockedAdd64(&longValue, 0x10000000_00000001) == 0x32345678_2ACD0125);
                assert(longValue == 0x32345678_2ACD0125);
                assert(_InterlockedAdd64_acq(&longValue, 0x10000000_00000001) == 0x42345678_2ACD0126);
                assert(longValue == 0x42345678_2ACD0126);
                assert(_InterlockedAdd64_rel(&longValue, 0x10000000_00000001) == 0x52345678_2ACD0127);
                assert(longValue == 0x52345678_2ACD0127);
                assert(_InterlockedAdd64_nf(&longValue, 0x10000000_00000001) == 0x62345678_2ACD0128);
                assert(longValue == 0x62345678_2ACD0128);
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    version (X86)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedAddLargeStatistic(scope shared(long)* Addend, int Value) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                *((a) @trusted => cast(long*) a)(Addend) += Value;
                return Value;
            }
            else
            {
                version (LDC)
                {
                    import ldc.llvmasm : __ir_pure;

                    scope highHalf = ((a) @trusted => &(cast(shared(uint)*) Addend)[1])(Addend);

                    enum ptr = llvmIRPtr!"i32" ~ " elementtype(i32)";

                    __ir_pure!(
                        `call void asm sideeffect inteldialect
                             "lock add dword ptr $0, $2
                              jnc pastAddingOfCarry_${:uid}
                              lock adc dword ptr $1, 0
                         pastAddingOfCarry_${:uid}:",
                             "=*m,=*m,ir,~{memory},~{flags}"
                             (` ~ ptr ~ ` %0, ` ~ ptr ~ ` %1, i32 %2)`,
                        void
                    )(Addend, highHalf, Value);

                    return Value;
                }
                else version (GNU)
                {
                    scope highHalf = ((a) @trusted => &(cast(shared(uint)*) Addend)[1])(Addend);

                    asm @trusted pure nothrow @nogc
                    {
                        "lock addl %2, %0
                         jnc pastAddingOfCarry_%=
                         lock adcl $0, %1
                    pastAddingOfCarry_%=:"
                        : "+m" (*cast(shared(uint)*) Addend), "+m" (*highHalf)
                        : "ir" (Value)
                        : "memory", "cc";
                    }

                    return Value;
                }
                else version (D_InlineAsm_X86)
                {
                    asm @trusted pure nothrow @nogc
                    {
                        naked;
                        mov EDX, [ESP + 4]; /* Addend. */
                        mov EAX, [ESP + 8]; /* Value. */
                        lock; add [EDX], EAX;
                        jnc pastAddingOfCarry; /* If there's no carry we needn't add it. */
                        lock; adc [EDX + 4], 0;
                    pastAddingOfCarry:
                        ret;
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                shared long value = 0x12345678_2ACD0123;

                assert(_InterlockedAddLargeStatistic(&value, 0x10000001) == 0x10000001);
                assert(value == 0x12345678_3ACD0124);

                assert(_InterlockedAddLargeStatistic(&value, 0x62997F6F) == 0x62997F6F);
                assert(value == 0x12345678_9D668093);

                assert(_InterlockedAddLargeStatistic(&value, 0x62997F6F) == 0x62997F6F);
                assert(value == 0x12345679_00000002);

                return true;
            }

            assert(test());
            static assert(test());
        }
    }

    extern(C)
    pragma(inline, true)
    int _InterlockedAnd(scope shared(int)* value, int mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_and", "and_4", "&")(value, mask);
    }

    extern(C)
    pragma(inline, true)
    byte _InterlockedAnd8(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_and", "and_1", "&")(value, mask);
    }

    extern(C)
    pragma(inline, true)
    short _InterlockedAnd16(scope shared(short)* value, short mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_and", "and_2", "&")(value, mask);
    }

    extern(C)
    pragma(inline, true)
    long _interlockedand64(scope shared(long)* value, long mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_and", "and_8", "&")(value, mask);
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedAnd_acq(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_4", "&", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedAnd_rel(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_4", "&", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedAnd_nf(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_4", "&", MemoryOrder.raw)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedAnd8_acq(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_1", "&", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedAnd8_rel(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_1", "&", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedAnd8_nf(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_1", "&", MemoryOrder.raw)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedAnd16_acq(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_2", "&", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedAnd16_rel(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_2", "&", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedAnd16_nf(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_2", "&", MemoryOrder.raw)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAnd64_acq(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_8", "&", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAnd64_rel(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_8", "&", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAnd64_nf(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_8", "&", MemoryOrder.raw)(value, mask);
        }
    }

    version (X86_64_Or_AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        long _InterlockedAnd64(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_8", "&")(value, mask);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedAnd_np(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_4", "&", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedAnd8_np(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_1", "&", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedAnd16_np(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_2", "&", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAnd64_np(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_and", "and_8", "&", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAnd64_HLEAcquire(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(true, "&", "and")(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedAnd64_HLERelease(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(false, "&", "and")(value, mask);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedAnd_HLEAcquire(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(true, "&", "and")(value, mask);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedAnd_HLERelease(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(false, "&", "and")(value, mask);
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static bool test()
        {
            alias t(alias symbol, T) = interlockedOpTest!("&", symbol, T);

            t!(_InterlockedAnd, int)();
            t!(_InterlockedAnd8, byte)();
            t!(_InterlockedAnd16, short)();
            t!(_interlockedand64, long)();

            version (AArch64_Or_ARM)
            {
                t!(_InterlockedAnd_acq, int)();
                t!(_InterlockedAnd_rel, int)();
                t!(_InterlockedAnd_nf, int)();
                t!(_InterlockedAnd8_acq, byte)();
                t!(_InterlockedAnd8_rel, byte)();
                t!(_InterlockedAnd8_nf, byte)();
                t!(_InterlockedAnd16_acq, short)();
                t!(_InterlockedAnd16_rel, short)();
                t!(_InterlockedAnd16_nf, short)();
                t!(_InterlockedAnd64_acq, long)();
                t!(_InterlockedAnd64_rel, long)();
                t!(_InterlockedAnd64_nf, long)();
            }

            version (X86_64_Or_AArch64_Or_ARM)
            {
                t!(_InterlockedAnd64, long)();
            }

            version (X86_64)
            {
                t!(_InterlockedAnd_np, int)();
                t!(_InterlockedAnd8_np, byte)();
                t!(_InterlockedAnd16_np, short)();
                t!(_InterlockedAnd64_np, long)();
                t!(_InterlockedAnd64_HLEAcquire, long)();
                t!(_InterlockedAnd64_HLERelease, long)();
            }

            version (X86_64_Or_X86)
            {
                t!(_InterlockedAnd_HLEAcquire, int)();
                t!(_InterlockedAnd_HLERelease, int)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    ubyte _interlockedbittestandreset(scope shared(int)* a, int b) @system pure nothrow @nogc
    {
        return interlockedBitTestOp!("btr", "rmw_and", "and_4", "&", "~")(a, b);
    }

    version (X86_64_Or_AArch64)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset64(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_8", "&", "~")(a, b);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset_HLEAcquire(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_4", "&", "~", MemoryOrder.seq, 1)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset_HLERelease(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_4", "&", "~", MemoryOrder.seq, 2)(a, b);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset64_HLEAcquire(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_8", "&", "~", MemoryOrder.seq, 1)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset64_HLERelease(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_8", "&", "~", MemoryOrder.seq, 2)(a, b);
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset_acq(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_4", "&", "~", MemoryOrder.acq)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset_rel(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_4", "&", "~", MemoryOrder.acq_rel)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset_nf(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_4", "&", "~", MemoryOrder.raw)(a, b);
        }
    }

    version (AArch64)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset64_acq(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_8", "&", "~", MemoryOrder.acq)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset64_rel(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_8", "&", "~", MemoryOrder.acq_rel)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandreset64_nf(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("btr", "rmw_and", "and_8", "&", "~", MemoryOrder.raw)(a, b);
        }
    }

    @system pure nothrow @nogc unittest
    {
        enum ulong datumA = 0b0111111110100010110111000101011101001111001100111111101100010100;
        enum ulong datumB = 0b0001001000011101110011000010011010101000101000111001000001101110;
        enum ulong datumC = 0b1010010101000100010111111111000100001000010010111000100111100110;
        enum ulong datumD = 0b1011110000010110101001111110000110000011001100101010111100011101;

        static void bitResetTest(alias btr, T)()
        {
            scope shared(T)[4] data = [cast(T) datumA, cast(T) datumB, cast(T) datumC, cast(T) datumD];

            assert(btr(&data[0], T(0)) == 0);
            assert(data[0] == cast(T) 0b0111111110100010110111000101011101001111001100111111101100010100);

            assert(btr(&data[0], T(2)) == 1);
            assert(data[0] == cast(T) 0b0111111110100010110111000101011101001111001100111111101100010000);

            assert(btr(&data[0], cast(T) ((T.sizeof << 3) * 3)) == 1);
            assert(data[3] == cast(T) 0b1011110000010110101001111110000110000011001100101010111100011100);

            assert(btr(&data[0], cast(T) ((T.sizeof << 3) * 3 + 1)) == 0);
            assert(data[3] == cast(T) 0b1011110000010110101001111110000110000011001100101010111100011100);
        }

        static bool test()
        {
            bitResetTest!(_interlockedbittestandreset, int)();

            version (X86_64_Or_AArch64)
            {
                bitResetTest!(_interlockedbittestandreset64, long)();
            }

            version (X86_64_Or_X86)
            {
                bitResetTest!(_interlockedbittestandreset_HLEAcquire, int)();
                bitResetTest!(_interlockedbittestandreset_HLERelease, int)();
            }

            version (X86_64)
            {
                bitResetTest!(_interlockedbittestandreset64_HLEAcquire, long)();
                bitResetTest!(_interlockedbittestandreset64_HLERelease, long)();
            }

            version (AArch64_Or_ARM)
            {
                bitResetTest!(_interlockedbittestandreset_acq, int)();
                bitResetTest!(_interlockedbittestandreset_rel, int)();
                bitResetTest!(_interlockedbittestandreset_nf, int)();
            }

            version (AArch64)
            {
                bitResetTest!(_interlockedbittestandreset64_acq, long)();
                bitResetTest!(_interlockedbittestandreset64_rel, long)();
                bitResetTest!(_interlockedbittestandreset64_nf, long)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    ubyte _interlockedbittestandset(scope shared(int)* a, int b) @system pure nothrow @nogc
    {
        return interlockedBitTestOp!("bts", "rmw_or", "or_4", "|", "")(a, b);
    }

    version (X86_64_Or_AArch64)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset64(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_8", "|", "")(a, b);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset_HLEAcquire(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_4", "|", "", MemoryOrder.seq, 1)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset_HLERelease(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_4", "|", "", MemoryOrder.seq, 2)(a, b);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset64_HLEAcquire(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_8", "|", "", MemoryOrder.seq, 1)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset64_HLERelease(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_8", "|", "", MemoryOrder.seq, 2)(a, b);
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset_acq(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_4", "|", "", MemoryOrder.acq)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset_rel(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_4", "|", "", MemoryOrder.acq_rel)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset_nf(scope shared(int)* a, int b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_4", "|", "", MemoryOrder.raw)(a, b);
        }
    }

    version (AArch64)
    {
        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset64_acq(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_8", "|", "", MemoryOrder.acq)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset64_rel(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_8", "|", "", MemoryOrder.acq_rel)(a, b);
        }

        extern(C)
        pragma(inline, true)
        ubyte _interlockedbittestandset64_nf(scope shared(long)* a, long b) @system pure nothrow @nogc
        {
            return interlockedBitTestOp!("bts", "rmw_or", "or_8", "|", "", MemoryOrder.raw)(a, b);
        }
    }

    @system pure nothrow @nogc unittest
    {
        enum ulong datumA = 0b0111111110100010110111000101011101001111001100111111101100010100;
        enum ulong datumB = 0b0001001000011101110011000010011010101000101000111001000001101110;
        enum ulong datumC = 0b1010010101000100010111111111000100001000010010111000100111100110;
        enum ulong datumD = 0b1011110000010110101001111110000110000011001100101010111100011101;

        static void bitSetTest(alias bts, T)()
        {
            scope shared(T)[4] data = [cast(T) datumA, cast(T) datumB, cast(T) datumC, cast(T) datumD];

            assert(bts(&data[0], T(0)) == 0);
            assert(data[0] == cast(T) 0b0111111110100010110111000101011101001111001100111111101100010101);

            assert(bts(&data[0], T(2)) == 1);
            assert(data[0] == cast(T) 0b0111111110100010110111000101011101001111001100111111101100010101);

            assert(bts(&data[0], cast(T) ((T.sizeof << 3) * 3)) == 1);
            assert(data[3] == cast(T) 0b1011110000010110101001111110000110000011001100101010111100011101);

            assert(bts(&data[0], cast(T) ((T.sizeof << 3) * 3 + 1)) == 0);
            assert(data[3] == cast(T) 0b1011110000010110101001111110000110000011001100101010111100011111);
        }

        static bool test()
        {
            bitSetTest!(_interlockedbittestandset, int)();

            version (X86_64_Or_AArch64)
            {
                bitSetTest!(_interlockedbittestandset64, long)();
            }

            version (X86_64_Or_X86)
            {
                bitSetTest!(_interlockedbittestandset_HLEAcquire, int)();
                bitSetTest!(_interlockedbittestandset_HLERelease, int)();
            }

            version (X86_64)
            {
                bitSetTest!(_interlockedbittestandset64_HLEAcquire, long)();
                bitSetTest!(_interlockedbittestandset64_HLERelease, long)();
            }

            version (AArch64_Or_ARM)
            {
                bitSetTest!(_interlockedbittestandset_acq, int)();
                bitSetTest!(_interlockedbittestandset_rel, int)();
                bitSetTest!(_interlockedbittestandset_nf, int)();
            }

            version (AArch64)
            {
                bitSetTest!(_interlockedbittestandset64_acq, long)();
                bitSetTest!(_interlockedbittestandset64_rel, long)();
                bitSetTest!(_interlockedbittestandset64_nf, long)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    int _InterlockedCompareExchange(scope shared(int)* Destination, int Exchange, int Comparand)
    @safe pure nothrow @nogc
    {
        return interlockedCAS(Destination, Exchange, Comparand);
    }

    extern(C)
    pragma(inline, true)
    byte _InterlockedCompareExchange8(scope shared(byte)* Destination, byte Exchange, byte Comparand)
    @safe pure nothrow @nogc
    {
        return interlockedCAS(Destination, Exchange, Comparand);
    }

    extern(C)
    pragma(inline, true)
    short _InterlockedCompareExchange16(scope shared(short)* Destination, short Exchange, short Comparand)
    @safe pure nothrow @nogc
    {
        return interlockedCAS(Destination, Exchange, Comparand);
    }

    extern(C)
    pragma(inline, true)
    long _InterlockedCompareExchange64(scope shared(long)* Destination, long Exchange, long Comparand)
    @safe pure nothrow @nogc
    {
        return interlockedCAS(Destination, Exchange, Comparand);
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedCompareExchange_HLEAcquire(scope shared(int)* Destination, int Exchange, int Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCASHLE!true(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedCompareExchange_HLERelease(scope shared(int)* Destination, int Exchange, int Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCASHLE!false(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedCompareExchange64_HLEAcquire(scope shared(long)* Destination, long Exchange, long Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCASHLE!true(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedCompareExchange64_HLERelease(scope shared(long)* Destination, long Exchange, long Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCASHLE!false(Destination, Exchange, Comparand);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedCompareExchange_np(scope shared(int)* Destination, int Exchange, int Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedCompareExchange16_np(scope shared(short)* Destination, short Exchange, short Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedCompareExchange64_np(scope shared(long)* Destination, long Exchange, long Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS(Destination, Exchange, Comparand);
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedCompareExchange_acq(scope shared(int)* Destination, int Exchange, int Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedCompareExchange_rel(scope shared(int)* Destination, int Exchange, int Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq_rel, MemoryOrder.raw)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedCompareExchange_nf(scope shared(int)* Destination, int Exchange, int Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.raw)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedCompareExchange8_acq(scope shared(byte)* Destination, byte Exchange, byte Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedCompareExchange8_rel(scope shared(byte)* Destination, byte Exchange, byte Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq_rel, MemoryOrder.raw)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedCompareExchange8_nf(scope shared(byte)* Destination, byte Exchange, byte Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.raw)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedCompareExchange16_acq(scope shared(short)* Destination, short Exchange, short Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedCompareExchange16_rel(scope shared(short)* Destination, short Exchange, short Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq_rel, MemoryOrder.raw)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedCompareExchange16_nf(scope shared(short)* Destination, short Exchange, short Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.raw)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedCompareExchange64_acq(scope shared(long)* Destination, long Exchange, long Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedCompareExchange64_rel(scope shared(long)* Destination, long Exchange, long Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq_rel, MemoryOrder.raw)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedCompareExchange64_nf(scope shared(long)* Destination, long Exchange, long Comparand)
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.raw)(Destination, Exchange, Comparand);
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static void compareExchangeTest(alias symbol, T)()
        {
            shared T value = cast(T) 0x6B2E38BF9FAF53EC;

            assert(symbol(&value, value, value) == cast(T) 0x6B2E38BF9FAF53EC);
            assert(value == cast(T) 0x6B2E38BF9FAF53EC);

            assert(symbol(&value, cast(T) 0x24AC9053985CF040, value) == cast(T) 0x6B2E38BF9FAF53EC);
            assert(value == cast(T) 0x24AC9053985CF040);

            assert(symbol(&value, cast(T) 0x426A6F348BBD3430, 123) == cast(T) 0x24AC9053985CF040);
            assert(value == cast(T) 0x24AC9053985CF040);
        }

        static bool test()
        {
            compareExchangeTest!(_InterlockedCompareExchange, int)();
            compareExchangeTest!(_InterlockedCompareExchange8, byte)();
            compareExchangeTest!(_InterlockedCompareExchange16, short)();
            compareExchangeTest!(_InterlockedCompareExchange64, long)();

            version (X86_64_Or_X86)
            {
                compareExchangeTest!(_InterlockedCompareExchange_HLEAcquire, int)();
                compareExchangeTest!(_InterlockedCompareExchange_HLERelease, int)();
                compareExchangeTest!(_InterlockedCompareExchange64_HLEAcquire, long)();
                compareExchangeTest!(_InterlockedCompareExchange64_HLERelease, long)();
            }

            version (X86_64)
            {
                compareExchangeTest!(_InterlockedCompareExchange_np, int)();
                compareExchangeTest!(_InterlockedCompareExchange16_np, short)();
                compareExchangeTest!(_InterlockedCompareExchange64_np, long)();
            }

            version (AArch64_Or_ARM)
            {
                compareExchangeTest!(_InterlockedCompareExchange_acq, int)();
                compareExchangeTest!(_InterlockedCompareExchange_rel, int)();
                compareExchangeTest!(_InterlockedCompareExchange_nf, int)();
                compareExchangeTest!(_InterlockedCompareExchange8_acq, byte)();
                compareExchangeTest!(_InterlockedCompareExchange8_rel, byte)();
                compareExchangeTest!(_InterlockedCompareExchange8_nf, byte)();
                compareExchangeTest!(_InterlockedCompareExchange16_acq, short)();
                compareExchangeTest!(_InterlockedCompareExchange16_rel, short)();
                compareExchangeTest!(_InterlockedCompareExchange16_nf, short)();
                compareExchangeTest!(_InterlockedCompareExchange64_acq, long)();
                compareExchangeTest!(_InterlockedCompareExchange64_rel, long)();
                compareExchangeTest!(_InterlockedCompareExchange64_nf, long)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    version (X86_64_Or_AArch64)
    {
        extern(C)
        pragma(inline, true)
        ubyte _InterlockedCompareExchange128(
            scope shared(long)* Destination,
            long ExchangeHigh,
            long ExchangeLow,
            scope long* ComparandResult
        ) @system pure nothrow @nogc
        {
            return interlockedCAS128(Destination, ExchangeHigh, ExchangeLow, ComparandResult);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        ubyte _InterlockedCompareExchange128_np(
            scope shared(long)* Destination,
            long ExchangeHigh,
            long ExchangeLow,
            scope long* ComparandResult
        ) @system pure nothrow @nogc
        {
            return interlockedCAS128(Destination, ExchangeHigh, ExchangeLow, ComparandResult);
        }
    }

    version (AArch64)
    {
        extern(C)
        pragma(inline, true)
        ubyte _InterlockedCompareExchange128_acq(
            scope shared(long)* Destination,
            long ExchangeHigh,
            long ExchangeLow,
            scope long* ComparandResult
        ) @system pure nothrow @nogc
        {
            return interlockedCAS128!(MemoryOrder.acq)(Destination, ExchangeHigh, ExchangeLow, ComparandResult);
        }

        extern(C)
        pragma(inline, true)
        ubyte _InterlockedCompareExchange128_rel(
            scope shared(long)* Destination,
            long ExchangeHigh,
            long ExchangeLow,
            scope long* ComparandResult
        ) @system pure nothrow @nogc
        {
            return interlockedCAS128!(MemoryOrder.acq_rel, MemoryOrder.raw)(
                Destination,
                ExchangeHigh,
                ExchangeLow,
                ComparandResult
            );
        }

        extern(C)
        pragma(inline, true)
        ubyte _InterlockedCompareExchange128_nf(
            scope shared(long)* Destination,
            long ExchangeHigh,
            long ExchangeLow,
            scope long* ComparandResult
        ) @system pure nothrow @nogc
        {
            return interlockedCAS128!(MemoryOrder.raw)(Destination, ExchangeHigh, ExchangeLow, ComparandResult);
        }
    }

    @system pure nothrow @nogc unittest
    {
        version (LittleEndian)
        {
            enum size_t lo = 0;
            enum size_t hi = 1;
        }
        else version (BigEndian)
        {
            enum size_t lo = 1;
            enum size_t hi = 0;
        }

        static void compareExchangeTest(alias symbol)()
        {
            shared scope long[2] value;
            value[lo] = 0x6B2E38BF9FAF53EC;
            value[hi] = 0x5E81D5FBA4340FD3;

            scope long[2] expected = value;

            assert(symbol(&value[0], value[hi], value[lo], &expected[0]) == 1);
            assert(value[lo] == 0x6B2E38BF9FAF53EC);
            assert(value[hi] == 0x5E81D5FBA4340FD3);
            assert(expected[lo] == 0x6B2E38BF9FAF53EC);
            assert(expected[hi] == 0x5E81D5FBA4340FD3);

            assert(symbol(&value[0], 0x24AC9053985CF040, 0x936644BBF7E7DD76, &expected[0]) == 1);
            assert(value[lo] == 0x936644BBF7E7DD76);
            assert(value[hi] == 0x24AC9053985CF040);
            assert(expected[lo] == 0x6B2E38BF9FAF53EC);
            assert(expected[hi] == 0x5E81D5FBA4340FD3);

            assert(symbol(&value[0], 0x6EEFACD4571F6679, 0xB2281F742F268665, &expected[0]) == 0);
            assert(value[lo] == 0x936644BBF7E7DD76);
            assert(value[hi] == 0x24AC9053985CF040);
            assert(expected[lo] == 0x936644BBF7E7DD76);
            assert(expected[hi] == 0x24AC9053985CF040);
        }

        static bool test()
        {
            version (X86_64_Or_AArch64)
            {
                compareExchangeTest!_InterlockedCompareExchange128();
            }

            version (X86_64)
            {
                compareExchangeTest!_InterlockedCompareExchange128_np();
            }

            version (AArch64)
            {
                compareExchangeTest!_InterlockedCompareExchange128_acq();
                compareExchangeTest!_InterlockedCompareExchange128_rel();
                compareExchangeTest!_InterlockedCompareExchange128_nf();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    void* _InterlockedCompareExchangePointer(
        scope shared(void*)* Destination,
        scope void* Exchange,
        return scope void* Comparand
    )
    @safe pure nothrow @nogc
    {
        return interlockedCAS!(MemoryOrder.seq, MemoryOrder.seq, void*)(Destination, Exchange, Comparand);
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        void* _InterlockedCompareExchangePointer_HLEAcquire(
            scope shared(void*)* Destination,
            scope void* Exchange,
            return scope void* Comparand
        )
        @safe pure nothrow @nogc
        {
            return interlockedCASHLE!(true, void*)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        void* _InterlockedCompareExchangePointer_HLERelease(
            scope shared(void*)* Destination,
            scope void* Exchange,
            return scope void* Comparand
        )
        @safe pure nothrow @nogc
        {
            return interlockedCASHLE!(false, void*)(Destination, Exchange, Comparand);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        void* _InterlockedCompareExchangePointer_np(
            scope shared(void*)* Destination,
            scope void* Exchange,
            return scope void* Comparand
        )
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.seq, MemoryOrder.seq, void*)(Destination, Exchange, Comparand);
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        void* _InterlockedCompareExchangePointer_acq(
            scope shared(void*)* Destination,
            scope void* Exchange,
            return scope void* Comparand
        )
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq, MemoryOrder.acq, void*)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        void* _InterlockedCompareExchangePointer_rel(
            scope shared(void*)* Destination,
            scope void* Exchange,
            return scope void* Comparand
        )
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.acq_rel, MemoryOrder.raw, void*)(Destination, Exchange, Comparand);
        }

        extern(C)
        pragma(inline, true)
        void* _InterlockedCompareExchangePointer_nf(
            scope shared(void*)* Destination,
            scope void* Exchange,
            return scope void* Comparand
        )
        @safe pure nothrow @nogc
        {
            return interlockedCAS!(MemoryOrder.raw, MemoryOrder.raw, void*)(Destination, Exchange, Comparand);
        }
    }

    @safe pure nothrow @nogc unittest
    {
        static void* p(ulong value) @trusted
        {
            return cast(void*) cast(size_t) value;
        }

        static void compareExchangeTest(alias symbol)()
        {
            scope void* value = p(0x6B2E38BF9FAF53EC);
            scope shared(void*)* valueAddress = ((return scope ref v) @trusted => cast(shared(void*)*) &v)(value);

            assert(symbol(valueAddress, value, value) == p(0x6B2E38BF9FAF53EC));
            assert(value == p(0x6B2E38BF9FAF53EC));

            assert(symbol(valueAddress, p(0x24AC9053985CF040), value) == p(0x6B2E38BF9FAF53EC));
            assert(value == p(0x24AC9053985CF040));

            assert(symbol(valueAddress, p(0x426A6F348BBD3430), p(123)) == p(0x24AC9053985CF040));
            assert(value == p(0x24AC9053985CF040));
        }

        static bool test()
        {
            compareExchangeTest!_InterlockedCompareExchangePointer();

            version (X86_64_Or_X86)
            {
                compareExchangeTest!_InterlockedCompareExchangePointer_HLEAcquire();
                compareExchangeTest!_InterlockedCompareExchangePointer_HLERelease();
            }

            version (X86_64)
            {
                compareExchangeTest!_InterlockedCompareExchangePointer_np();
            }

            version (AArch64_Or_ARM)
            {
                compareExchangeTest!_InterlockedCompareExchangePointer_acq();
                compareExchangeTest!_InterlockedCompareExchangePointer_rel();
                compareExchangeTest!_InterlockedCompareExchangePointer_nf();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    int _InterlockedDecrement(scope shared(int)* lpAddend) @safe pure nothrow @nogc
    {
        return interlockedAdd(lpAddend, -1);
    }

    extern(C)
    pragma(inline, true)
    short _InterlockedDecrement16(scope shared(short)* lpAddend) @safe pure nothrow @nogc
    {
        return interlockedAdd(lpAddend, -1);
    }

    extern(C)
    pragma(inline, true)
    long _interlockeddecrement64(scope shared(long)* lpAddend) @safe pure nothrow @nogc
    {
        import core.internal.atomic : atomicFetchAdd;

        static if (__traits(compiles, atomicFetchAdd(lpAddend, -1)))
        {
            if (__ctfe)
            {
                return *((a) @trusted => cast(long*) a)(lpAddend) += -1;
            }
            else
            {
                return atomicFetchAdd(lpAddend, -1) - 1;
            }
        }
        else
        {
            return interlockedOp!("rmw_add", "add_8", "+", MemoryOrder.seq, true)(lpAddend, -1) - 1;
        }
    }

    version (X86_64_Or_AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        long _InterlockedDecrement64(scope shared(long)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd(lpAddend, -1);
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedDecrement_acq(scope shared(int)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq)(lpAddend, -1);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedDecrement_rel(scope shared(int)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq_rel)(lpAddend, -1);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedDecrement_nf(scope shared(int)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.raw)(lpAddend, -1);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedDecrement16_acq(scope shared(short)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq)(lpAddend, -1);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedDecrement16_rel(scope shared(short)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq_rel)(lpAddend, -1);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedDecrement16_nf(scope shared(short)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.raw)(lpAddend, -1);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedDecrement64_acq(scope shared(long)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq)(lpAddend, -1);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedDecrement64_rel(scope shared(long)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq_rel)(lpAddend, -1);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedDecrement64_nf(scope shared(long)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.raw)(lpAddend, -1);
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static void decrementTest(alias symbol, T)()
        {
            shared T value = 1;

            assert(symbol(&value) == 0);
            assert(value == 0);

            assert(symbol(&value) == -1);
            assert(value == -1);
        }

        static bool test()
        {
            decrementTest!(_InterlockedDecrement, int)();
            decrementTest!(_InterlockedDecrement16, short)();
            decrementTest!(_interlockeddecrement64, long)();

            version (X86_64_Or_AArch64_Or_ARM)
            {
                decrementTest!(_InterlockedDecrement64, long)();
            }

            version (AArch64_Or_ARM)
            {
                decrementTest!(_InterlockedDecrement_acq, int)();
                decrementTest!(_InterlockedDecrement_rel, int)();
                decrementTest!(_InterlockedDecrement_nf, int)();
                decrementTest!(_InterlockedDecrement16_acq, short)();
                decrementTest!(_InterlockedDecrement16_rel, short)();
                decrementTest!(_InterlockedDecrement16_nf, short)();
                decrementTest!(_InterlockedDecrement64_acq, long)();
                decrementTest!(_InterlockedDecrement64_rel, long)();
                decrementTest!(_InterlockedDecrement64_nf, long)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    int _InterlockedExchange(scope shared(int)* Target, int Value) @safe pure nothrow @nogc
    {
        return interlockedExchange(Target, Value);
    }

    extern(C)
    pragma(inline, true)
    byte _InterlockedExchange8(scope shared(byte)* Target, byte Value) @safe pure nothrow @nogc
    {
        return interlockedExchange(Target, Value);
    }

    extern(C)
    pragma(inline, true)
    short _InterlockedExchange16(scope shared(short)* Target, short Value) @safe pure nothrow @nogc
    {
        return interlockedExchange(Target, Value);
    }

    extern(C)
    pragma(inline, true)
    long _interlockedexchange64(scope shared(long)* Target, long Value) @trusted pure nothrow @nogc
    {
        static if (__traits(compiles, interlockedExchange(Target, Value)))
        {
            return interlockedExchange(Target, Value);
        }
        else
        {
            if (__ctfe)
            {
                long oldValue = *cast(long*) Target;
                *cast(long*) Target = Value;
                return oldValue;
            }
            else
            {
                import core.internal.atomic : atomicCompareExchangeWeak, atomicLoad;

                long data = atomicLoad!(MemoryOrder.raw)(Target);

                while (!atomicCompareExchangeWeak(cast(long*) Target, &data, Value))
                {}

                return data;
            }
        }
    }

    version (X86_64_Or_AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        long _InterlockedExchange64(scope shared(long)* Target, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchange(Target, Value);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedExchange_HLEAcquire(scope shared(int)* Target, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeHLE!true(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedExchange_HLERelease(scope shared(int)* Target, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeHLE!false(Target, Value);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        long _InterlockedExchange64_HLEAcquire(scope shared(long)* Target, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeHLE!true(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedExchange64_HLERelease(scope shared(long)* Target, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeHLE!false(Target, Value);
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedExchange_acq(scope shared(int)* Target, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedExchange_rel(scope shared(int)* Target, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq_rel)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedExchange_nf(scope shared(int)* Target, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.raw)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedExchange8_acq(scope shared(byte)* Target, byte Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedExchange8_rel(scope shared(byte)* Target, byte Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq_rel)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedExchange8_nf(scope shared(byte)* Target, byte Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.raw)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedExchange16_acq(scope shared(short)* Target, short Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedExchange16_rel(scope shared(short)* Target, short Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq_rel)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedExchange16_nf(scope shared(short)* Target, short Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.raw)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedExchange64_acq(scope shared(long)* Target, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedExchange64_rel(scope shared(long)* Target, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq_rel)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedExchange64_nf(scope shared(long)* Target, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.raw)(Target, Value);
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static void exchangeTest(alias symbol, T)()
        {
            shared T value = cast(T) 0x0790C852D0938C7B;

            assert(symbol(&value, cast(T) 0x612396D4FDC2C66A) == cast(T) 0x0790C852D0938C7B);
            assert(value == cast(T) 0x612396D4FDC2C66A);

            assert(symbol(&value, cast(T) 0xAA6C3899EABBE818) == cast(T) 0x612396D4FDC2C66A);
            assert(value == cast(T) 0xAA6C3899EABBE818);
        }

        static bool test()
        {
            exchangeTest!(_InterlockedExchange, int)();
            exchangeTest!(_InterlockedExchange8, byte)();
            exchangeTest!(_InterlockedExchange16, short)();
            exchangeTest!(_interlockedexchange64, long)();

            version (X86_64_Or_AArch64_Or_ARM)
            {
                exchangeTest!(_InterlockedExchange64, long)();
            }

            version (X86_64_Or_X86)
            {
                exchangeTest!(_InterlockedExchange_HLEAcquire, int)();
                exchangeTest!(_InterlockedExchange_HLERelease, int)();
            }

            version (X86_64)
            {
                exchangeTest!(_InterlockedExchange64_HLEAcquire, long)();
                exchangeTest!(_InterlockedExchange64_HLERelease, long)();
            }

            version (AArch64_Or_ARM)
            {
                exchangeTest!(_InterlockedExchange_acq, int)();
                exchangeTest!(_InterlockedExchange_rel, int)();
                exchangeTest!(_InterlockedExchange_nf, int)();
                exchangeTest!(_InterlockedExchange8_acq, byte)();
                exchangeTest!(_InterlockedExchange8_rel, byte)();
                exchangeTest!(_InterlockedExchange8_nf, byte)();
                exchangeTest!(_InterlockedExchange16_acq, short)();
                exchangeTest!(_InterlockedExchange16_rel, short)();
                exchangeTest!(_InterlockedExchange16_nf, short)();
                exchangeTest!(_InterlockedExchange64_acq, long)();
                exchangeTest!(_InterlockedExchange64_rel, long)();
                exchangeTest!(_InterlockedExchange64_nf, long)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    int _InterlockedExchangeAdd(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
    {
        return interlockedExchangeAdd(Addend, Value);
    }

    extern(C)
    pragma(inline, true)
    byte _InterlockedExchangeAdd8(scope shared(byte)* Addend, byte Value) @safe pure nothrow @nogc
    {
        return interlockedExchangeAdd(Addend, Value);
    }

    extern(C)
    pragma(inline, true)
    short _InterlockedExchangeAdd16(scope shared(short)* Addend, short Value) @safe pure nothrow @nogc
    {
        return interlockedExchangeAdd(Addend, Value);
    }

    extern(C)
    pragma(inline, true)
    long _interlockedexchangeadd64(scope shared(long)* Addend, long Value) @trusted pure nothrow @nogc
    {
        static if (__traits(compiles, interlockedExchangeAdd(Addend, Value)))
        {
            return interlockedExchangeAdd(Addend, Value);
        }
        else
        {
            return interlockedOp!("rmw_add", "add_8", "+", MemoryOrder.seq, true)(Addend, Value);
        }
    }

    version (X86_64_Or_AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        long _InterlockedExchangeAdd64(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd(Addend, Value);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedExchangeAdd_HLEAcquire(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAddHLE!true(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedExchangeAdd_HLERelease(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAddHLE!false(Addend, Value);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        long _InterlockedExchangeAdd64_HLEAcquire(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAddHLE!true(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedExchangeAdd64_HLERelease(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAddHLE!false(Addend, Value);
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedExchangeAdd_acq(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.acq)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedExchangeAdd_rel(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.acq_rel)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedExchangeAdd_nf(scope shared(int)* Addend, int Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.raw)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedExchangeAdd8_acq(scope shared(byte)* Addend, byte Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.acq)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedExchangeAdd8_rel(scope shared(byte)* Addend, byte Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.acq_rel)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedExchangeAdd8_nf(scope shared(byte)* Addend, byte Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.raw)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedExchangeAdd16_acq(scope shared(short)* Addend, short Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.acq)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedExchangeAdd16_rel(scope shared(short)* Addend, short Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.acq_rel)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedExchangeAdd16_nf(scope shared(short)* Addend, short Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.raw)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedExchangeAdd64_acq(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.acq)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedExchangeAdd64_rel(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.acq_rel)(Addend, Value);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedExchangeAdd64_nf(scope shared(long)* Addend, long Value) @safe pure nothrow @nogc
        {
            return interlockedExchangeAdd!(MemoryOrder.raw)(Addend, Value);
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static bool test()
        {
            alias t(alias symbol, T) = interlockedOpTest!("+", symbol, T);

            t!(_InterlockedExchangeAdd, int)();
            t!(_InterlockedExchangeAdd8, byte)();
            t!(_InterlockedExchangeAdd16, short)();
            t!(_interlockedexchangeadd64, long)();

            version (X86_64_Or_AArch64_Or_ARM)
            {
                t!(_InterlockedExchangeAdd64, long)();
            }

            version (X86_64_Or_X86)
            {
                t!(_InterlockedExchangeAdd_HLEAcquire, int)();
                t!(_InterlockedExchangeAdd_HLERelease, int)();
            }

            version (X86_64)
            {
                t!(_InterlockedExchangeAdd64_HLEAcquire, long)();
                t!(_InterlockedExchangeAdd64_HLERelease, long)();
            }

            version (AArch64_Or_ARM)
            {
                t!(_InterlockedExchangeAdd_acq, int)();
                t!(_InterlockedExchangeAdd_rel, int)();
                t!(_InterlockedExchangeAdd_nf, int)();
                t!(_InterlockedExchangeAdd8_acq, byte)();
                t!(_InterlockedExchangeAdd8_rel, byte)();
                t!(_InterlockedExchangeAdd8_nf, byte)();
                t!(_InterlockedExchangeAdd16_acq, short)();
                t!(_InterlockedExchangeAdd16_rel, short)();
                t!(_InterlockedExchangeAdd16_nf, short)();
                t!(_InterlockedExchangeAdd64_acq, long)();
                t!(_InterlockedExchangeAdd64_rel, long)();
                t!(_InterlockedExchangeAdd64_nf, long)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    void* _InterlockedExchangePointer(scope shared(void*)* Target, scope void* Value) @safe pure nothrow @nogc
    {
        return interlockedExchange!(MemoryOrder.seq, void*)(Target, Value);
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        void* _InterlockedExchangePointer_HLEAcquire(scope shared(void*)* Target, scope void* Value)
        @safe pure nothrow @nogc
        {
            return interlockedExchangeHLE!(true, void*)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        void* _InterlockedExchangePointer_HLERelease(scope shared(void*)* Target, scope void* Value)
        @safe pure nothrow @nogc
        {
            return interlockedExchangeHLE!(false, void*)(Target, Value);
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        void* _InterlockedExchangePointer_acq(scope shared(void*)* Target, scope void* Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq, void*)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        void* _InterlockedExchangePointer_rel(scope shared(void*)* Target, scope void* Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.acq_rel, void*)(Target, Value);
        }

        extern(C)
        pragma(inline, true)
        void* _InterlockedExchangePointer_nf(scope shared(void*)* Target, scope void* Value) @safe pure nothrow @nogc
        {
            return interlockedExchange!(MemoryOrder.raw, void*)(Target, Value);
        }
    }

    @safe pure nothrow @nogc unittest
    {
        static void* p(ulong value) @trusted
        {
            return cast(void*) cast(size_t) value;
        }

        static void exchangeTest(alias symbol)()
        {
            scope void* value = p(0x0790C852D0938C7B);
            scope shared(void*)* valueAddress = ((return scope ref v) @trusted => cast(shared(void*)*) &v)(value);

            assert(symbol(valueAddress, p(0x612396D4FDC2C66A)) == p(0x0790C852D0938C7B));
            assert(value == p(0x612396D4FDC2C66A));

            assert(symbol(valueAddress, p(0xAA6C3899EABBE818)) == p(0x612396D4FDC2C66A));
            assert(value == p(0xAA6C3899EABBE818));
        }

        static bool test()
        {
            exchangeTest!_InterlockedExchangePointer();

            version (X86_64_Or_X86)
            {
                exchangeTest!_InterlockedExchangePointer_HLEAcquire();
                exchangeTest!_InterlockedExchangePointer_HLERelease();
            }

            version (AArch64_Or_ARM)
            {
                exchangeTest!_InterlockedExchangePointer_acq();
                exchangeTest!_InterlockedExchangePointer_rel();
                exchangeTest!_InterlockedExchangePointer_nf();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    int _InterlockedIncrement(scope shared(int)* lpAddend) @safe pure nothrow @nogc
    {
        return interlockedAdd(lpAddend, 1);
    }

    extern(C)
    pragma(inline, true)
    short _InterlockedIncrement16(scope shared(short)* lpAddend) @safe pure nothrow @nogc
    {
        return interlockedAdd(lpAddend, 1);
    }

    extern(C)
    pragma(inline, true)
    long _interlockedincrement64(scope shared(long)* lpAddend) @safe pure nothrow @nogc
    {
        import core.internal.atomic : atomicFetchAdd;

        static if (__traits(compiles, atomicFetchAdd(lpAddend, 1)))
        {
            if (__ctfe)
            {
                return *((a) @trusted => cast(long*) a)(lpAddend) += 1;
            }
            else
            {
                return atomicFetchAdd(lpAddend, 1) + 1;
            }
        }
        else
        {
            return interlockedOp!("rmw_add", "add_8", "+", MemoryOrder.seq, true)(lpAddend, 1) + 1;
        }
    }

    version (X86_64_Or_AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        long _InterlockedIncrement64(scope shared(long)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd(lpAddend, 1);
        }
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedIncrement_acq(scope shared(int)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq)(lpAddend, 1);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedIncrement_rel(scope shared(int)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq_rel)(lpAddend, 1);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedIncrement_nf(scope shared(int)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.raw)(lpAddend, 1);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedIncrement16_acq(scope shared(short)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq)(lpAddend, 1);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedIncrement16_rel(scope shared(short)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq_rel)(lpAddend, 1);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedIncrement16_nf(scope shared(short)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.raw)(lpAddend, 1);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedIncrement64_acq(scope shared(long)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq)(lpAddend, 1);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedIncrement64_rel(scope shared(long)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.acq_rel)(lpAddend, 1);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedIncrement64_nf(scope shared(long)* lpAddend) @safe pure nothrow @nogc
        {
            return interlockedAdd!(MemoryOrder.raw)(lpAddend, 1);
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static void incrementTest(alias symbol, T)()
        {
            shared T value = -2;

            assert(symbol(&value) == -1);
            assert(value == -1);

            assert(symbol(&value) == 0);
            assert(value == 0);

            assert(symbol(&value) == 1);
            assert(value == 1);
        }

        static bool test()
        {
            incrementTest!(_InterlockedIncrement, int)();
            incrementTest!(_InterlockedIncrement16, short)();
            incrementTest!(_interlockedincrement64, long)();

            version (X86_64_Or_AArch64_Or_ARM)
            {
                incrementTest!(_InterlockedIncrement64, long)();
            }

            version (AArch64_Or_ARM)
            {
                incrementTest!(_InterlockedIncrement_acq, int)();
                incrementTest!(_InterlockedIncrement_rel, int)();
                incrementTest!(_InterlockedIncrement_nf, int)();
                incrementTest!(_InterlockedIncrement16_acq, short)();
                incrementTest!(_InterlockedIncrement16_rel, short)();
                incrementTest!(_InterlockedIncrement16_nf, short)();
                incrementTest!(_InterlockedIncrement64_acq, long)();
                incrementTest!(_InterlockedIncrement64_rel, long)();
                incrementTest!(_InterlockedIncrement64_nf, long)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    int _InterlockedOr(scope shared(int)* value, int mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_or", "or_4", "|")(value, mask);
    }

    extern(C)
    pragma(inline, true)
    byte _InterlockedOr8(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_or", "or_1", "|")(value, mask);
    }

    extern(C)
    pragma(inline, true)
    short _InterlockedOr16(scope shared(short)* value, short mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_or", "or_2", "|")(value, mask);
    }

    extern(C)
    pragma(inline, true)
    long _interlockedor64(scope shared(long)* value, long mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_or", "or_8", "|")(value, mask);
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedOr_acq(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_4", "|", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedOr_rel(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_4", "|", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedOr_nf(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_4", "|", MemoryOrder.raw)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedOr8_acq(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_1", "|", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedOr8_rel(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_1", "|", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedOr8_nf(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_1", "|", MemoryOrder.raw)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedOr16_acq(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_2", "|", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedOr16_rel(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_2", "|", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedOr16_nf(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_2", "|", MemoryOrder.raw)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedOr64_acq(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_8", "|", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedOr64_rel(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_8", "|", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedOr64_nf(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_8", "|", MemoryOrder.raw)(value, mask);
        }
    }

    version (X86_64_Or_AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        long _InterlockedOr64(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_8", "|")(value, mask);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedOr_np(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_4", "|", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedOr8_np(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_1", "|", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedOr16_np(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_2", "|", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedOr64_np(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_or", "or_8", "|", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedOr64_HLEAcquire(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(true, "|", "or")(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedOr64_HLERelease(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(false, "|", "or")(value, mask);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedOr_HLEAcquire(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(true, "|", "or")(value, mask);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedOr_HLERelease(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(false, "|", "or")(value, mask);
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static bool test()
        {
            alias t(alias symbol, T) = interlockedOpTest!("|", symbol, T);

            t!(_InterlockedOr, int)();
            t!(_InterlockedOr8, byte)();
            t!(_InterlockedOr16, short)();
            t!(_interlockedor64, long)();

            version (AArch64_Or_ARM)
            {
                t!(_InterlockedOr_acq, int)();
                t!(_InterlockedOr_rel, int)();
                t!(_InterlockedOr_nf, int)();
                t!(_InterlockedOr8_acq, byte)();
                t!(_InterlockedOr8_rel, byte)();
                t!(_InterlockedOr8_nf, byte)();
                t!(_InterlockedOr16_acq, short)();
                t!(_InterlockedOr16_rel, short)();
                t!(_InterlockedOr16_nf, short)();
                t!(_InterlockedOr64_acq, long)();
                t!(_InterlockedOr64_rel, long)();
                t!(_InterlockedOr64_nf, long)();
            }

            version (X86_64_Or_AArch64_Or_ARM)
            {
                t!(_InterlockedOr64, long)();
            }

            version (X86_64)
            {
                t!(_InterlockedOr_np, int)();
                t!(_InterlockedOr8_np, byte)();
                t!(_InterlockedOr16_np, short)();
                t!(_InterlockedOr64_np, long)();
                t!(_InterlockedOr64_HLEAcquire, long)();
                t!(_InterlockedOr64_HLERelease, long)();
            }

            version (X86_64_Or_X86)
            {
                t!(_InterlockedOr_HLEAcquire, int)();
                t!(_InterlockedOr_HLERelease, int)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    int _InterlockedXor(scope shared(int)* value, int mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_xor", "xor_4", "^")(value, mask);
    }

    extern(C)
    pragma(inline, true)
    byte _InterlockedXor8(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_xor", "xor_1", "^")(value, mask);
    }

    extern(C)
    pragma(inline, true)
    short _InterlockedXor16(scope shared(short)* value, short mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_xor", "xor_2", "^")(value, mask);
    }

    extern(C)
    pragma(inline, true)
    long _interlockedxor64(scope shared(long)* value, long mask) @safe pure nothrow @nogc
    {
        return interlockedOp!("rmw_xor", "xor_8", "^")(value, mask);
    }

    version (AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedXor_acq(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_4", "^", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedXor_rel(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_4", "^", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedXor_nf(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_4", "^", MemoryOrder.raw)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedXor8_acq(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_1", "^", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedXor8_rel(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_1", "^", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedXor8_nf(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_1", "^", MemoryOrder.raw)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedXor16_acq(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_2", "^", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedXor16_rel(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_2", "^", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedXor16_nf(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_2", "^", MemoryOrder.raw)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedXor64_acq(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_8", "^", MemoryOrder.acq)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedXor64_rel(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_8", "^", MemoryOrder.acq_rel)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedXor64_nf(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_8", "^", MemoryOrder.raw)(value, mask);
        }
    }

    version (X86_64_Or_AArch64_Or_ARM)
    {
        extern(C)
        pragma(inline, true)
        long _InterlockedXor64(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_8", "^")(value, mask);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedXor_np(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_4", "^", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        byte _InterlockedXor8_np(scope shared(byte)* value, byte mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_1", "^", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        short _InterlockedXor16_np(scope shared(short)* value, short mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_2", "^", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedXor64_np(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOp!("rmw_xor", "xor_8", "^", MemoryOrder.seq, true)(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedXor64_HLEAcquire(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(true, "^", "xor")(value, mask);
        }

        extern(C)
        pragma(inline, true)
        long _InterlockedXor64_HLERelease(scope shared(long)* value, long mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(false, "^", "xor")(value, mask);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        int _InterlockedXor_HLEAcquire(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(true, "^", "xor")(value, mask);
        }

        extern(C)
        pragma(inline, true)
        int _InterlockedXor_HLERelease(scope shared(int)* value, int mask) @safe pure nothrow @nogc
        {
            return interlockedOpHLE!(false, "^", "xor")(value, mask);
        }
    }

    /* This is trusted so that it's @safe without DIP1000 enabled. */
    @trusted pure nothrow @nogc unittest
    {
        static bool test()
        {
            alias t(alias symbol, T) = interlockedOpTest!("^", symbol, T);

            t!(_InterlockedXor, int)();
            t!(_InterlockedXor8, byte)();
            t!(_InterlockedXor16, short)();
            t!(_interlockedxor64, long)();

            version (AArch64_Or_ARM)
            {
                t!(_InterlockedXor_acq, int)();
                t!(_InterlockedXor_rel, int)();
                t!(_InterlockedXor_nf, int)();
                t!(_InterlockedXor8_acq, byte)();
                t!(_InterlockedXor8_rel, byte)();
                t!(_InterlockedXor8_nf, byte)();
                t!(_InterlockedXor16_acq, short)();
                t!(_InterlockedXor16_rel, short)();
                t!(_InterlockedXor16_nf, short)();
                t!(_InterlockedXor64_acq, long)();
                t!(_InterlockedXor64_rel, long)();
                t!(_InterlockedXor64_nf, long)();
            }

            version (X86_64_Or_AArch64_Or_ARM)
            {
                t!(_InterlockedXor64, long)();
            }

            version (X86_64)
            {
                t!(_InterlockedXor_np, int)();
                t!(_InterlockedXor8_np, byte)();
                t!(_InterlockedXor16_np, short)();
                t!(_InterlockedXor64_np, long)();
                t!(_InterlockedXor64_HLEAcquire, long)();
                t!(_InterlockedXor64_HLERelease, long)();
            }

            version (X86_64_Or_X86)
            {
                t!(_InterlockedXor_HLEAcquire, int)();
                t!(_InterlockedXor_HLERelease, int)();
            }

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    private T interlockedAdd(MemoryOrder order = MemoryOrder.seq, T)(scope shared(T)* address, T value)
    @safe pure nothrow @nogc
    {
        if (__ctfe)
        {
            return *((a) @trusted => cast(T*) a)(address) += value;
        }
        else
        {
            import core.internal.atomic : atomicFetchAdd;

            T result = cast(T) (atomicFetchAdd!order(address, value) + value);

            version (AArch64_Or_ARM)
            {
                /* This is what the Interlocked MSVC intrinsics do. */
                static if (order == MemoryOrder.acq)
                {
                    /* dmb ish */
                    __builtin_arm_dmb(11);
                }
            }

            return result;
        }
    }

    extern(C)
    pragma(inline, true)
    private T interlockedExchangeAdd(MemoryOrder order = MemoryOrder.seq, T)(scope shared(T)* address, T value)
    @safe pure nothrow @nogc
    {
        if (__ctfe)
        {
            scope a = ((a) @trusted => cast(T*) a)(address);
            T oldValue = *a;
            *a += value;
            return oldValue;
        }
        else
        {
            import core.internal.atomic : atomicFetchAdd;

            T result = atomicFetchAdd!order(address, value);

            version (AArch64_Or_ARM)
            {
                /* This is what the Interlocked MSVC intrinsics do. */
                static if (order == MemoryOrder.acq)
                {
                    /* dmb ish */
                    __builtin_arm_dmb(11);
                }
            }

            return result;
        }
    }

    extern(C)
    pragma(inline, true)
    private ubyte interlockedBitTestOp(
        string x86OpCode,
        string ldcName,
        string gdcName,
        string op,
        string unaryOp = "",
        MemoryOrder order = MemoryOrder.seq,
        uint x86HLE = 0,
        T
    )(scope shared(T)* address, T bitIndex) @system pure nothrow @nogc
    {
        static ubyte bitTestOpViaSoftware(scope shared(T)* address, T bitIndex)
        {
            import core.bitop : bsr, popcnt;

            enum uint bitCount = T.sizeof << 3;
            enum uint bitShift = bitCount.bsr;
            enum T bitMask = bitCount - 1;

            scope shared(T)* integer = address + (bitIndex >> bitShift);
            const T mask = T(1) << (bitIndex & bitMask);

            return (interlockedOp!(ldcName, gdcName, op, order)(integer, mixin(unaryOp, q{mask})) & mask) != 0;
        }

        if (__ctfe)
        {
            return bitTestOpViaSoftware(address, bitIndex);
        }
        else
        {
            version (X86_64_Or_X86)
            {
                import core.bitop : bsr;

                enum size = T.sizeof.bsr;

                version (LDC)
                {
                    import ldc.llvmasm : __ir_pure;

                    enum type = ["i8", "i16", "i32", "i64"][size];
                    enum x86Ptr = ["byte", "word", "dword", "qword"][size];
                    enum imm = ["", "", "I", "J"][size];
                    enum ptr = llvmIRPtr!type ~ " elementtype(" ~ type ~ ")";
                    enum hlePrefix = x86HLE == 0 ? "" : (x86HLE == 1 ? "xacquire " : "xrelease ");

                    return __ir_pure!(
                        `%bitIsSet = call i8 asm sideeffect inteldialect
                             "` ~ hlePrefix ~ `lock ` ~ x86OpCode ~ ` ` ~ x86Ptr ~ ` ptr $1, $2",
                             "={@ccc},=*m,` ~ imm ~ `r,~{memory},~{flags}"
                             (` ~ ptr ~ ` %0, ` ~ type ~ ` %1)
                         ret i8 %bitIsSet;`,
                        ubyte
                    )(address, bitIndex);
                }
                else version (GNU)
                {
                    enum char suffix = "bwlq"[size];
                    enum imm = ["Wb", "Ww", "I", "J"][size];
                    enum hlePrefix = x86HLE == 0 ? "" : (x86HLE == 1 ? "xacquire " : "xrelease ");

                    ubyte bitIsSet;

                    mixin(
                        `asm @system pure nothrow @nogc
                         {
                             "" ~ hlePrefix ~ "lock " ~ x86OpCode ~ suffix ~ " %2, %0"
                             : "+m" (*address), "=@ccc" (bitIsSet)
                             : "` ~ imm ~ `r" (bitIndex)
                             : "memory", "cc";
                         }`
                    );

                    return bitIsSet;
                }
                else version (InlineAsm_X86_64_Or_X86)
                {
                    enum d = ["DL", "DX", "EDX", "RDX"][size];
                    enum ptr = ["byte", "word", "dword", "qword"][size];
                    enum xacquire = "repne; ";
                    enum xrelease = "rep; ";
                    enum hlePrefix = x86HLE == 0 ? "" : (x86HLE == 1 ? xacquire : xrelease);

                    version (D_InlineAsm_X86_64)
                    {
                        mixin(
                            "asm pure nothrow @nogc
                             {
                                 /* RCX is address; RDX is bitIndex. */
                                 naked;
                                 " ~ hlePrefix ~ "lock; " ~ x86OpCode ~ " " ~ ptr ~ " ptr [RCX], " ~ d ~ ";
                                 setc AL;
                                 ret;
                             }"
                        );
                    }
                    else version (D_InlineAsm_X86)
                    {
                        mixin(
                            "asm pure nothrow @nogc
                             {
                                 naked;
                                 mov ECX, [ESP + 4]; /* address. */
                                 mov EDX, [ESP + 8]; /* bitIndex. */
                                 " ~ hlePrefix ~ "lock; " ~ x86OpCode ~ " " ~ ptr ~ " ptr [ECX], " ~ d ~ ";
                                 setc AL;
                                 ret;
                             }"
                        );
                    }
                }
            }
            else
            {
                return bitTestOpViaSoftware(address, bitIndex);
            }
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        private T interlockedExchangeAddHLE(bool acquire, T)(scope shared(T)* address, scope T value)
        {
            if (__ctfe)
            {
                return interlockedExchangeAdd!(MemoryOrder.seq, T)(address, value);
            }
            else
            {
                version (LDC)
                {
                    import core.bitop : bsr;
                    import ldc.llvmasm : __ir_pure;

                    enum size = T.sizeof.bsr;
                    enum type = ["i8", "i16", "i32", "i64"][size];
                    enum ptr = llvmIRPtr!type;

                    return __ir_pure!(
                        `%oldValue = call ` ~ type ~ ` asm sideeffect inteldialect
                             "` ~ (acquire ? "xacquire" : "xrelease") ~ ` lock xadd $1, $0",
                             "=r,=*m,0,~{memory},~{flags}"
                             ( ` ~ ptr ~ ` elementtype(` ~ type ~ `)` ~ ` %0, ` ~ type ~ ` %1)

                         ret ` ~ type ~ ` %oldValue`,
                        T
                    )(address, value);
                }
                else version (GNU)
                {
                    static if (acquire)
                    {
                        /* This is equivalent to GCC's __ATOMIC_HLE_ACQUIRE. */
                        enum int hleModifier = 1 << 16;
                    }
                    else
                    {
                        /* This is equivalent to GCC's __ATOMIC_HLE_RELEASE. */
                        enum int hleModifier = 1 << 17;
                    }

                    enum int hleOrder = MemoryOrder.seq | hleModifier;
                    enum add = "__atomic_fetch_add_" ~ ('0' + T.sizeof);

                    mixin(q{import gcc.builtins : }, add, q{;});

                    return mixin(add)(address, value, hleOrder);
                }
                else version (InlineAsm_X86_64_Or_X86)
                {
                    import core.bitop : bsr;

                    enum size = T.sizeof.bsr;
                    enum xacquire = "repne";
                    enum xrelease = "rep";

                    version (D_InlineAsm_X86_64)
                    {
                        enum fullA = ["EAX", "EAX", "EAX", "RAX"][size];
                        enum fullD = ["EDX", "EDX", "EDX", "RDX"][size];
                        enum a = ["AL", "AX", "EAX", "RAX"][size];

                        mixin(
                            "asm @trusted pure nothrow @nogc
                             {
                                 /* RCX is address; RDX is value. */
                                 naked;
                                  mov " ~ fullA ~ ", " ~ fullD ~ ";
                                 " ~ (acquire ? xacquire : xrelease) ~ "; lock; xadd [RCX], " ~ a ~ ";
                                 ret;
                             }"
                        );
                    }
                    else version (D_InlineAsm_X86)
                    {
                        enum a = ["AL", "AX", "EAX"][size];

                        mixin(
                            "asm @trusted pure nothrow @nogc
                             {
                                 naked;
                                 mov ECX, [ESP + 4]; /* address. */
                                 mov EAX, [ESP + 8]; /* value. */
                                 " ~ (acquire ? xacquire : xrelease) ~ "; lock; xadd [ECX], " ~ a ~ ";
                                 ret;
                             }"
                        );
                    }
                }
            }
        }

        extern(C)
        pragma(inline, true)
        private T interlockedOpHLE(bool acquire, string op, string x86OpCode, T)(scope shared(T)* address, T operand)
        /* This is trusted so that it's @safe without DIP1000 enabled. */
        @trusted
        {
            if (__ctfe)
            {
                scope a = ((a) @trusted => cast(T*) a)(address);
                T oldValue = *a;
                mixin(q{*a }, op, q{= operand;});
                return oldValue;
            }
            else
            {
                version (X86_64)
                {
                    version (LDC)
                    {
                        import core.simd : prefetch;
                        prefetch!(true, 3)(((a) @trusted => cast(const(void)*) a)(address));
                    }
                    else version (GNU)
                    {
                        import gcc.builtins : __builtin_prefetch;
                        __builtin_prefetch(((a) @trusted => cast(const(void)*) a)(address), 1, 3);
                    }
                }

                version (LDC)
                {
                    import core.bitop : bsr;
                    import core.internal.atomic : atomicLoad;
                    import ldc.llvmasm : __ir_pure;

                    enum size = T.sizeof.bsr;
                    enum type = ["i8", "i16", "i32", "i64"][size];
                    enum a = ["al", "ax", "eax", "rax"][size];

                    enum ptr = llvmIRPtr!type;
                    T value = atomicLoad!(MemoryOrder.raw)(address);

                    while (
                        !__ir_pure!(
                            `%value = load ` ~ type ~ `, ` ~ ptr ~ ` %1

                             %cas = call {` ~ type ~ `, i8} asm sideeffect inteldialect
                                 "` ~ (acquire ? "xacquire" : "xrelease") ~ ` lock cmpxchg $1, $4",
                                 "={` ~ a ~ `},=*m,={@ccz},0,r,~{memory},~{flags}"
                                 (` ~ ptr ~ ` elementtype(` ~ type ~ `)` ~ ` %0, ` ~ type ~ ` %value, ` ~ type ~ ` %2)

                             %oldValue = extractvalue {` ~ type ~ `, i8} %cas, 0
                             %stored = extractvalue {` ~ type ~ `, i8} %cas, 1

                             store ` ~ type ~ ` %oldValue, ` ~ ptr ~ ` %1
                             ret i8 %stored`,
                            ubyte
                        )(address, &value, cast(T) (mixin(q{value }, op, q{ operand})))
                    )
                    {
                        static if (acquire)
                        {
                            __builtin_ia32_pause();
                        }
                    }

                    return value;
                }
                else version (GNU)
                {
                    static if (acquire)
                    {
                        /* This is equivalent to GCC's __ATOMIC_HLE_ACQUIRE. */
                        enum int hleModifier = 1 << 16;
                    }
                    else
                    {
                        /* This is equivalent to GCC's __ATOMIC_HLE_RELEASE. */
                        enum int hleModifier = 1 << 17;
                    }

                    enum int hleOrder = MemoryOrder.seq | hleModifier;
                    enum cas = "__atomic_compare_exchange_" ~ ('0' + T.sizeof);
                    enum load = "__atomic_load_" ~ ('0' + T.sizeof);

                    mixin(q{import gcc.builtins : }, cas, q{, }, load, q{, __builtin_ia32_pause;});

                    T value = mixin(load)(address, MemoryOrder.raw);

                    while (
                        !mixin(cas)(
                            address,
                            &value,
                            cast(T) (mixin(q{value }, op, q{ operand})),
                            true,
                            hleOrder,
                            hleOrder
                        )
                    )
                    {
                        static if (acquire)
                        {
                            __builtin_ia32_pause();
                        }
                    }

                    return value;
                }
                else version (D_InlineAsm_X86_64)
                {
                    import core.bitop : bsr;

                    enum size = T.sizeof.bsr;
                    enum fullA = ["EAX", "EAX", "EAX", "RAX"][size];
                    enum fullR8 = ["R8D", "R8D", "R8D", "R8"][size];
                    enum fullMOV = ["movzx", "movzx", "mov", "mov"][size];
                    enum fastD = ["DL", "EDX", "EDX", "RDX"][size];
                    enum fastR8 = ["R8B", "R8D", "R8D", "R8"][size];
                    enum r8 = ["R8B", "R8W", "R8D", "R8"][size];
                    enum ptr = ["byte", "word", "dword", "qword"][size];
                    enum xacquire = "repne";
                    enum xrelease = "rep";

                    mixin(
                        "asm @trusted pure nothrow @nogc
                         {
                             /* RCX is address; RDX is operand. */
                             naked;
                             prefetchw byte ptr [RCX];
                             " ~ fullMOV ~ " " ~ fullA ~ ", " ~ ptr ~ " ptr [RCX];
                         cas:
                             mov " ~ fullR8 ~ ", " ~ fullA ~ ";
                             " ~ x86OpCode ~ " " ~ fastR8 ~ ", " ~ fastD ~ ";
                             " ~ (acquire ? xacquire : xrelease) ~ "; lock; cmpxchg [RCX], " ~ r8 ~ ";
                             " ~ (
                                   acquire
                                 ? "je swapped;
                                    rep; nop; /* pause */
                                    jmp cas;"
                                 : "jne cas;"
                             ) ~ "
                         swapped:
                             ret;
                         }"
                    );
                }
                else version (D_InlineAsm_X86)
                {
                    import core.bitop : bsr;

                    enum size = T.sizeof.bsr;
                    enum fullA = ["EAX", "EAX", "EAX"][size];
                    enum fullB = ["EBX", "EBX", "EBX"][size];
                    enum fullMOV = ["movzx", "movzx", "mov"][size];
                    enum fastB = ["BL", "EBX", "EBX"][size];
                    enum fastD = ["DL", "EDX", "EDX"][size];
                    enum b = ["BL", "BX", "EBX"][size];
                    enum ptr = ["byte", "word", "dword"][size];
                    enum xacquire = "repne";
                    enum xrelease = "rep";

                    mixin(
                        "asm @trusted pure nothrow @nogc
                         {
                             naked;
                             push EBX;
                             mov ECX, [ESP + 8]; /* address. */
                             " ~ fullMOV ~ " " ~ fullA ~ ", " ~ ptr ~ " ptr [ECX];
                             mov EDX, [ESP + 12]; /* operand. */
                         cas:
                             mov " ~ fullB ~ ", " ~ fullA ~ ";
                             " ~ x86OpCode ~ " " ~ fastB ~ ", " ~ fastD ~ ";
                             " ~ (acquire ? xacquire : xrelease) ~ "; lock; cmpxchg [ECX], " ~ b ~ ";
                             " ~ (
                                   acquire
                                 ? "je swapped;
                                    rep; nop; /* pause */
                                    jmp cas;"
                                 : "jne cas;"
                             ) ~ "
                         swapped:
                             pop EBX;
                             ret;
                         }"
                    );
                }
            }
        }

        extern(C)
        pragma(inline, true)
        private T interlockedCASHLE(bool acquire, T)(
            scope shared(T)* address,
            scope T valueToSet,
            return scope T expectedValue
        ) @trusted
        {
            if (__ctfe)
            {
                return interlockedCAS!(MemoryOrder.seq, MemoryOrder.seq, T)(address, valueToSet, expectedValue);
            }
            else
            {
                version (LDC)
                {
                    import core.bitop : bsr;
                    import ldc.llvmasm : __ir_pure;

                    enum size = T.sizeof.bsr;

                    static if (is(T == P*, P))
                    {
                        enum type = llvmIRPtr!"i8";
                    }
                    else
                    {
                        enum type = ["i8", "i16", "i32", "i64"][size];
                    }

                    version (X86)
                    {
                        enum bool canUseCMPXCHG = T.sizeof <= 4;
                    }
                    else version (X86_64)
                    {
                        enum bool canUseCMPXCHG = true;
                    }

                    enum ptr = llvmIRPtr!type;

                    static if (canUseCMPXCHG)
                    {
                        enum a = ["al", "ax", "eax", "rax"][size];

                        return __ir_pure!(
                            `%oldValue = call ` ~ type ~ ` asm sideeffect inteldialect
                                 "` ~ (acquire ? "xacquire" : "xrelease") ~ ` lock cmpxchg $1, $3",
                                 "={` ~ a ~ `},=*m,0,r,~{memory},~{flags}"
                                 (` ~ ptr ~ ` elementtype(` ~ type ~ `)` ~ ` %0, ` ~ type ~ ` %2, ` ~ type ~ ` %1)

                             ret ` ~ type ~ ` %oldValue`,
                            T
                        )(address, valueToSet, expectedValue);
                    }
                    else
                    {
                        uint lo;
                        uint hi;

                        return __ir_pure!(
                            `%oldValue = call {i32, i32} asm sideeffect inteldialect
                                 "` ~ (acquire ? "xacquire" : "xrelease") ~ ` lock cmpxchg8b $2",
                                 "={eax},={edx},=*m,0,1,{ebx},{ecx},~{memory},~{flags}"
                                 (` ~ ptr ~ ` elementtype(i64)` ~ ` %0, i32 %3, i32 %4, i32 %1, i32 %2)

                             %lo32 = extractvalue {i32, i32} %oldValue, 0
                             %hi32 = extractvalue {i32, i32} %oldValue, 1

                             %lo = zext i32 %lo32 to i64
                             %hi = zext i32 %hi32 to i64
                             %hi64 = shl i64 %hi, 32
                             %result = or i64 %hi64, %lo

                             ret i64 %result`,
                            T
                        )(
                            address,
                            cast(uint) valueToSet,
                            cast(uint) (valueToSet >>> 32),
                            cast(uint) expectedValue,
                            cast(uint) (expectedValue >>> 32)
                        );
                    }
                }
                else version (GNU)
                {
                    static if (acquire)
                    {
                        /* This is equivalent to GCC's __ATOMIC_HLE_ACQUIRE. */
                        enum int hleModifier = 1 << 16;
                    }
                    else
                    {
                        /* This is equivalent to GCC's __ATOMIC_HLE_RELEASE. */
                        enum int hleModifier = 1 << 17;
                    }

                    enum int hleOrder = MemoryOrder.seq | hleModifier;
                    enum cas = "__atomic_compare_exchange_" ~ ('0' + T.sizeof);

                    import core.internal.traits : AliasSeq;
                    import core.bitop : bsr;
                    mixin(q{import gcc.builtins : }, cas, q{;});

                    alias Int = AliasSeq!(ubyte, ushort, uint, ulong)[T.sizeof.bsr];

                    cast(void) mixin(cas)(
                        address,
                        cast(Int*) &expectedValue,
                        cast(Int) valueToSet,
                        false,
                        hleOrder,
                        hleOrder
                    );

                    return expectedValue;
                }
                else version (D_InlineAsm_X86_64)
                {
                    import core.bitop : bsr;

                    enum size = T.sizeof.bsr;
                    enum fullA = ["EAX", "EAX", "EAX", "RAX"][size];
                    enum fullR8 = ["R8D", "R8D", "R8D", "R8"][size];
                    enum d = ["DL", "DX", "EDX", "RDX"][size];
                    enum xacquire = "repne";
                    enum xrelease = "rep";

                    mixin(
                        "asm @trusted pure nothrow @nogc
                         {
                             /* RCX is address; RDX is valueToSet; R8 is expectedValue. */
                             naked;
                              mov " ~ fullA ~ ", " ~ fullR8 ~ ";
                             " ~ (acquire ? xacquire : xrelease) ~ "; lock; cmpxchg [RCX], " ~ d ~ ";
                             ret;
                         }"
                    );
                }
                else version (D_InlineAsm_X86)
                {
                    enum xacquire = "repne";
                    enum xrelease = "rep";

                    static if (T.sizeof <= 4)
                    {
                        import core.bitop : bsr;

                        enum size = T.sizeof.bsr;
                        enum d = ["DL", "DX", "EDX"][size];

                        mixin(
                            "asm @trusted pure nothrow @nogc
                             {
                                 naked;
                                 mov ECX, [ESP +  4]; /* address. */
                                 mov EDX, [ESP +  8]; /* valueToSet. */
                                 mov EAX, [ESP + 12]; /* expectedValue. */
                                 " ~ (acquire ? xacquire : xrelease) ~ "; lock; cmpxchg [ECX], " ~ d ~ ";
                                 ret;
                             }"
                        );
                    }
                    else static if (T.sizeof <= 8)
                    {
                        mixin(
                            "asm @trusted pure nothrow @nogc
                             {
                                 naked;
                                 push ESI;
                                 push EBX;
                                 mov ESI, [ESP + 12]; /* address. */
                                 mov ECX, [ESP + 20]; /* High half of valueToSet. */
                                 mov EBX, [ESP + 16]; /* Low half of valueToSet. */
                                 mov EDX, [ESP + 28]; /* High half of expectedValue. */
                                 mov EAX, [ESP + 24]; /* Low half of expectedValue. */
                                 " ~ (acquire ? xacquire : xrelease) ~ "; lock; cmpxchg8b [ESI];
                                 pop EBX;
                                 pop ESI;
                                 ret;
                             }"
                        );
                    }
                }
            }
        }

        extern(C)
        pragma(inline, true)
        private T interlockedExchangeHLE(bool acquire, T)(scope shared(T)* address, scope T value)
        @trusted
        {
            if (__ctfe)
            {
                T oldValue = *cast(T*) address;
                *cast(T*) address = value;
                return oldValue;
            }
            else
            {
                version (LDC)
                {
                    import core.bitop : bsr;
                    import ldc.llvmasm : __ir_pure;

                    enum size = T.sizeof.bsr;

                    static if (is(T == P*, P))
                    {
                        enum type = llvmIRPtr!"i8";
                    }
                    else
                    {
                        enum type = ["i8", "i16", "i32", "i64"][size];
                    }

                    enum ptr = llvmIRPtr!type;

                    return __ir_pure!(
                        `%oldValue = call ` ~ type ~ ` asm sideeffect inteldialect
                             "` ~ (acquire ? "xacquire" : "xrelease") ~ ` xchg $1, $0",
                             "=r,=*m,0,~{memory}"
                             ( ` ~ ptr ~ ` elementtype(` ~ type ~ `)` ~ ` %0, ` ~ type ~ ` %1)

                         ret ` ~ type ~ ` %oldValue`,
                        T
                    )(address, value);
                }
                else version (GNU)
                {
                    static if (acquire)
                    {
                        /* This is equivalent to GCC's __ATOMIC_HLE_ACQUIRE. */
                        enum int hleModifier = 1 << 16;
                    }
                    else
                    {
                        /* This is equivalent to GCC's __ATOMIC_HLE_RELEASE. */
                        enum int hleModifier = 1 << 17;
                    }

                    enum int hleOrder = MemoryOrder.seq | hleModifier;
                    enum exchange = "__atomic_exchange_" ~ ('0' + T.sizeof);

                    import core.internal.traits : AliasSeq;
                    import core.bitop : bsr;
                    mixin(q{import gcc.builtins : }, exchange, q{;});

                    alias Int = AliasSeq!(ubyte, ushort, uint, ulong)[T.sizeof.bsr];

                    return cast(T) mixin(exchange)(address, cast(Int) value, hleOrder);
                }
                else version (InlineAsm_X86_64_Or_X86)
                {
                    import core.bitop : bsr;

                    enum size = T.sizeof.bsr;
                    enum xacquire = "repne";
                    enum xrelease = "rep";

                    version (D_InlineAsm_X86_64)
                    {
                        enum fullA = ["EAX", "EAX", "EAX", "RAX"][size];
                        enum fullD = ["EDX", "EDX", "EDX", "RDX"][size];
                        enum a = ["AL", "AX", "EAX", "RAX"][size];

                        mixin(
                            "asm @trusted pure nothrow @nogc
                             {
                                 /* RCX is address; RDX is value. */
                                 naked;
                                  mov " ~ fullA ~ ", " ~ fullD ~ ";
                                 " ~ (acquire ? xacquire : xrelease) ~ "; xchg [RCX], " ~ a ~ ";
                                 ret;
                             }"
                        );
                    }
                    else version (D_InlineAsm_X86)
                    {
                        enum a = ["AL", "AX", "EAX"][size];

                        mixin(
                            "asm @trusted pure nothrow @nogc
                             {
                                 naked;
                                 mov ECX, [ESP + 4]; /* address. */
                                 mov EAX, [ESP + 8]; /* value. */
                                 " ~ (acquire ? xacquire : xrelease) ~ "; xchg [ECX], " ~ a ~ ";
                                 ret;
                             }"
                        );
                    }
                }
            }
        }
    }

    extern(C)
    pragma(inline, true)
    private T interlockedExchange(MemoryOrder order = MemoryOrder.seq, T)(scope shared(T)* address, scope T value)
    @trusted
    {
        if (__ctfe)
        {
            T oldValue = *cast(T*) address;
            *cast(T*) address = value;
            return oldValue;
        }
        else
        {
            static if (order == MemoryOrder.acq)
            {
                /* atomicExchange rejects acq memory-ordering as invalid, but this is what MSVC does, so: ¯\_(ツ)_/¯ */

                version (LDC)
                {
                    import core.internal.atomic : _ordering;
                    import ldc.intrinsics : llvm_atomic_rmw_xchg;

                    T result = llvm_atomic_rmw_xchg!(T)(address, value, _ordering!order);
                }
                else version (GNU)
                {
                    import core.internal.traits : AliasSeq;
                    import core.bitop : bsr;
                    enum exchange = "__atomic_exchange_" ~ ('0' + T.sizeof);
                    mixin(q{import gcc.builtins : }, exchange, q{;});

                    alias Int = AliasSeq!(ubyte, ushort, uint, ulong)[T.sizeof.bsr];

                    T result = cast(T) mixin(exchange)(address, cast(Int) value, order);
                }
                else
                {
                    static assert(false, "This is instantiated only for ARM/AArch64 targets.");
                }
            }
            else
            {
                import core.internal.atomic : atomicExchange;

                T result = atomicExchange!(order, true, T)(cast(T*) address, value);
            }

            version (AArch64_Or_ARM)
            {
                /* This is what the Interlocked MSVC intrinsics do. */
                static if (order == MemoryOrder.acq)
                {
                    /* dmb ish */
                    __builtin_arm_dmb(11);
                }
            }

            return result;
        }
    }

    extern(C)
    pragma(inline, true)
    private T interlockedCAS(MemoryOrder success = MemoryOrder.seq, MemoryOrder failure = success, T)(
        scope shared(T)* address,
        scope T valueToSet,
        return scope T expectedValue
    ) @trusted pure nothrow @nogc
    {
        if (__ctfe)
        {
            scope a = ((a) @trusted => cast(T*) a)(address);
            T oldValue = *a;

            if (oldValue == expectedValue)
            {
                *a = valueToSet;
            }

            return oldValue;
        }
        else
        {
            import core.internal.atomic : atomicCompareExchangeStrong;

            cast(void) atomicCompareExchangeStrong!(success, failure)(cast(T*) address, &expectedValue, valueToSet);

            version (AArch64_Or_ARM)
            {
                /* This is what the Interlocked MSVC intrinsics do. */
                static if (success == MemoryOrder.acq)
                {
                    /* dmb ish */
                    __builtin_arm_dmb(11);
                }
            }

            return expectedValue;
        }
    }

    extern(C)
    pragma(inline, true)
    private ubyte interlockedCAS128(MemoryOrder success = MemoryOrder.seq, MemoryOrder failure = success)(
        scope shared(long)* address,
        long valueToSetHigh,
        long valueToSetLow,
        scope long* expectedValue
    ) @system pure nothrow @nogc
    {
        import core.internal.atomic : atomicCompareExchangeStrong;

        version (LittleEndian)
        {
            enum size_t lo = 0;
            enum size_t hi = 1;
        }
        else version (BigEndian)
        {
            enum size_t lo = 1;
            enum size_t hi = 0;
        }

        if (__ctfe)
        {
            scope a = ((a) @trusted => cast(long*) a)(address);

            if (a[0] == expectedValue[0] && a[1] == expectedValue[1])
            {
                a[lo] = valueToSetLow;
                a[hi] = valueToSetHigh;

                return 1;
            }

            expectedValue[0] = a[0];
            expectedValue[1] = a[1];

            return 0;
        }
        else
        {
            ulong[2] valueToSet = void;
            valueToSet[lo] = valueToSetLow;
            valueToSet[hi] = valueToSetHigh;

            bool result = atomicCompareExchangeStrong!(success, failure)(
                cast(ulong[2]*) address,
                cast(ulong[2]*) expectedValue,
                valueToSet
            );

            version (AArch64_Or_ARM)
            {
                /* This is what the Interlocked MSVC intrinsics do. */
                static if (success == MemoryOrder.acq)
                {
                    /* dmb ish */
                    __builtin_arm_dmb(11);
                }
            }

            return result;
        }
    }

    extern(C)
    pragma(inline, true)
    private T interlockedOp(
        string ldcName,
        string gdcName,
        string op,
        MemoryOrder order = MemoryOrder.seq,
        bool noPrefetch = false,
        T
    )(
        scope shared(T)* address,
        T operand
    ) @trusted pure nothrow @nogc
    {
        if (__ctfe)
        {
            scope a = ((a) @trusted => cast(T*) a)(address);
            T oldValue = *a;
            mixin(q{*a }, op, q{= operand;});
            return oldValue;
        }
        else
        {
            version (X86_64)
            {
                static if (!noPrefetch)
                {
                    version (GNU)
                    {
                        import gcc.builtins : __builtin_prefetch;
                        __builtin_prefetch(((a) @trusted => cast(const(void)*) a)(address), 1, 3);
                    }
                    else
                    {
                        import core.simd : prefetch;
                        prefetch!(true, 3)(((a) @trusted => cast(const(void)*) a)(address));
                    }
                }
            }

            version (LDC)
            {
                enum string name = "llvm_atomic_" ~ ldcName;

                import core.internal.atomic : _ordering;
                mixin(q{import ldc.intrinsics : }, name, q{;});

                T value = mixin(name)(address, operand, _ordering!order);
            }
            else version (GNU)
            {
                enum string name = "__atomic_fetch_" ~ gdcName;

                mixin(q{import gcc.builtins : }, name, q{;});

                T value = mixin(name)(address, operand, order);
            }
            else
            {
                import core.internal.atomic : atomicCompareExchangeWeak, atomicLoad;

                T value = atomicLoad!(MemoryOrder.raw)(address);

                while (
                    !atomicCompareExchangeWeak!(order, order)(
                        cast(T*) address,
                        &value,
                        mixin(q{value }, op, q{ operand})
                    )
                )
                {}
            }

            version (AArch64_Or_ARM)
            {
                /* This is what the Interlocked MSVC intrinsics do. */
                static if (order == MemoryOrder.acq)
                {
                    /* dmb ish */
                    __builtin_arm_dmb(11);
                }
            }

            return value;
        }
    }

    private void interlockedOpTest(string op, alias symbol, T)()
    {
        enum ulong fullValue = 0x32515ED8453C5664;
        enum ulong fullOperandA = 0x4B71C0BCC5836855;
        enum ulong fullOperandB = 0x2E934F81075982C8;

        shared T value = cast(T) fullValue;
        shared T oldValue = value;
        T operandA = cast(T) fullOperandA;
        T operandB = cast(T) fullOperandB;

        assert(symbol(&value, operandA) == oldValue);
        assert(value == cast(T) (mixin(q{oldValue }, op, q{ operandA})));
        oldValue = value;

        assert(symbol(&value, operandB) == oldValue);
        assert(value == cast(T) (mixin(q{oldValue }, op, q{ operandB})));
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        ubyte __inbyte(ushort Port) @system nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                return x86In!ubyte(Port);
            }
            else
            {
                import core.bitop : inp;
                return inp(Port);
            }
        }

        extern(C)
        pragma(inline, true)
        ushort __inword(ushort Port) @system nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                return x86In!ushort(Port);
            }
            else
            {
                import core.bitop : inpw;
                return inpw(Port);
            }
        }

        extern(C)
        pragma(inline, true)
        uint __indword(ushort Port) @system nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                return x86In!uint(Port);
            }
            else
            {
                import core.bitop : inpl;
                return inpl(Port);
            }
        }

        extern(C)
        pragma(inline, true)
        void __outbyte(ushort Port, ubyte Data) @system nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                x86Out(Port, Data);
            }
            else
            {
                import core.bitop : outp;
                outp(Port, Data);
            }
        }

        extern(C)
        pragma(inline, true)
        void __outword(ushort Port, ushort Data) @system nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                x86Out(Port, Data);
            }
            else
            {
                import core.bitop : outpw;
                outpw(Port, Data);
            }
        }

        extern(C)
        pragma(inline, true)
        void __outdword(ushort Port, uint Data) @system nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                x86Out(Port, Data);
            }
            else
            {
                import core.bitop : outpl;
                outpl(Port, Data);
            }
        }

        version (LDC_Or_GNU)
        {
            extern(C)
            pragma(inline, true)
            private T x86In(T)(ushort port) @system nothrow @nogc
            {
                version (LDC)
                {
                    import core.bitop : bsr;
                    import ldc.llvmasm : __ir;

                    enum size = T.sizeof.bsr;
                    enum type = ["i8", "i16", "i32"][size];
                    enum a = ["al", "ax", "eax"][size];

                    return __ir!(
                        `%value = call ` ~ type ~ ` asm sideeffect inteldialect
                             "in $0, $1",
                             "={` ~ a ~ `},N{dx},~{memory}"
                             (i16 %0)

                         ret ` ~ type ~ ` %value`,
                        T
                    )(port);
                }
                else version (GNU)
                {
                    T result;

                    asm @system nothrow @nogc
                    {
                        "in %w1, %0" : "=a" (result) : "Nd" (port) : "memory";
                    }

                    return result;
                }
            }

            extern(C)
            pragma(inline, true)
            private void x86Out(T)(ushort port, T data) @system nothrow @nogc
            {
                version (LDC)
                {
                    import core.bitop : bsr;
                    import ldc.llvmasm : __ir;

                    enum size = T.sizeof.bsr;
                    enum type = ["i8", "i16", "i32"][size];
                    enum a = ["al", "ax", "eax"][size];

                    __ir!(
                        `call void asm sideeffect inteldialect
                             "out $0, $1",
                             "N{dx},{` ~ a ~ `},~{memory}"
                             (i16 %0, ` ~ type ~ ` %1)`,
                        void
                    )(port, data);
                }
                else version (GNU)
                {
                    asm @system nothrow @nogc
                    {
                        "out %1, %w0" : : "Nd" (port), "a" (data) : "memory";
                    }
                }
            }
        }

        extern(C)
        pragma(inline, true)
        void __inbytestring(ushort Port, scope ubyte* Buffer, uint Count) @system nothrow @nogc
        {
            x86InOutString!'I'(Port, Buffer, Count);
        }

        extern(C)
        pragma(inline, true)
        void __inwordstring(ushort Port, scope ushort* Buffer, uint Count) @system nothrow @nogc
        {
            x86InOutString!'I'(Port, Buffer, Count);
        }

        extern(C)
        pragma(inline, true)
        void __indwordstring(ushort Port, scope uint* Buffer, uint Count) @system nothrow @nogc
        {
            x86InOutString!'I'(Port, Buffer, Count);
        }

        extern(C)
        pragma(inline, true)
        void __outbytestring(ushort Port, scope ubyte* Buffer, uint Count) @system nothrow @nogc
        {
            x86InOutString!'O'(Port, Buffer, Count);
        }

        extern(C)
        pragma(inline, true)
        void __outwordstring(ushort Port, scope ushort* Buffer, uint Count) @system nothrow @nogc
        {
            x86InOutString!'O'(Port, Buffer, Count);
        }

        extern(C)
        pragma(inline, true)
        void __outdwordstring(ushort Port, scope uint* Buffer, uint Count) @system nothrow @nogc
        {
            x86InOutString!'O'(Port, Buffer, Count);
        }

        extern(C)
        pragma(inline, true)
        private void x86InOutString(char io, T)(ushort port, scope T* buffer, uint bufferLength) @system nothrow @nogc
        {
            import core.bitop : bsr;

            enum size = T.sizeof.bsr;

            version (X86)
            {
                enum indexPrefix = 'E';
            }
            else version (X86_64)
            {
                enum indexPrefix = 'R';
            }

            static if (io == 'I')
            {
                enum opCode = "ins";
                enum index = indexPrefix ~ "DI";
            }
            else static if (io == 'O')
            {
                enum opCode = "outs";
                enum index = indexPrefix ~ "SI";
            }

            version (LDC)
            {
                import core.bitop : bsr;
                import ldc.llvmasm : __ir;

                enum char suffix = "bwl"[size];
                enum type = ["i8", "i16", "i32"][size];
                enum ptr = llvmIRPtr!type;

                __ir!(
                    `call {` ~ ptr ~ `, i32} asm
                     "rep ` ~ opCode ~ suffix ~ `",
                     "=&{` ~ index ~ `},=&{ecx},{dx},0,1,~{memory}"
                     (i16 %0, ` ~ ptr ~ ` %1, i32 %2)`,
                    void
                )(port, buffer, bufferLength);
            }
            else version (GNU)
            {
                enum char suffix = "bwl"[size];

                mixin(
                    `asm @system nothrow @nogc
                     {
                           "rep " ~ opCode ~ suffix
                         : "=` ~ index[1] ~ `" (buffer), "=c" (bufferLength)
                         : "0" (buffer), "1" (bufferLength), "d" (port)
                         : "memory";
                     }`
                );
            }
            else version (InlineAsm_X86_64_Or_X86)
            {
                enum char suffix = "bwd"[size];

                version (D_InlineAsm_X86_64)
                {
                    mixin(
                        "asm @trusted pure nothrow @nogc
                         {
                             /* CX is port; RDX is buffer; R8D is bufferLength. */
                             naked;
                             mov R9, " ~ index ~ "; /* R[DS]I is non-volatile, so we save it in R9. */
                             mov " ~ index ~ ", RDX;
                             mov EDX, ECX;
                             mov ECX, R8D;
                             rep; " ~ opCode ~ suffix ~ ";
                             mov " ~ index ~ ", R9;
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
                             mov EAX, " ~ index ~ "; /* E[DS]I is non-volatile, so we save it in EAX. */
                             mov ECX, [ESP + 12]; /* bufferLength. */
                             mov " ~ index ~ ", [ESP +  8]; /* buffer. */
                             mov EDX, [ESP +  4]; /* port. */
                             rep; " ~ opCode ~ suffix ~ ";
                             mov " ~ index ~ ", EAX;
                             ret;
                         }"
                    );
                }
            }
        }

        extern(C)
        pragma(inline, true)
        void __int2c() @safe pure nothrow @nogc
        {
            /+ Theoretically, this could clobber memory and registers, but in practice, on Windows, this just
               causes an assertion failure for debuggers. So, only the flags are clobbered. +/

            version (LDC)
            {
                import ldc.llvmasm : __ir_pure;

                __ir_pure!(`call void asm sideeffect inteldialect "int 0x2c", "~{flags}"()`, void)();
            }
            else version (GNU)
            {
                asm @trusted pure nothrow @nogc
                {
                    "int $0x2c" : : : "cc";
                }
            }
            else version (InlineAsm_X86_64_Or_X86)
            {
                asm @trusted pure nothrow @nogc
                {
                    int 0x2c;
                }
            }
        }

        extern(C)
        pragma(inline, true)
        void __invlpg(scope void* Address) @system nothrow @nogc
        {
            version (LDC)
            {
                import ldc.llvmasm : __ir;

                enum ptr = llvmIRPtr!"i8" ~ " elementtype(i8)";

                __ir!(
                    `call void asm sideeffect inteldialect "invlpg $0", "*m,~{memory}"(` ~ ptr ~ ` %0)`,
                    void
                )(Address);
            }
            else version (GNU)
            {
                asm @system nothrow @nogc
                {
                    "invlpg %0" : : "m" (*cast(const(ubyte)*) Address) : "memory";
                }
            }
            else version (D_InlineAsm_X86_64)
            {
                asm @system pure nothrow @nogc
                {
                    /* RCX is Address. */
                    naked;
                    invlpg [RCX];
                    ret;
                }
            }
            else version (D_InlineAsm_X86)
            {
                asm @system pure nothrow @nogc
                {
                    naked;
                    mov ECX, [ESP + 4]; /* Address. */
                    invlpg [ECX];
                    ret;
                }
            }
        }

        extern(C)
        pragma(inline, true)
        void __lidt(scope void* Source) @system nothrow @nogc
        {
            version (LDC)
            {
                import core.bitop : bsr;
                import ldc.llvmasm : __ir;

                enum type = ["i8", "i16", "i32", "i64"][size_t.sizeof.bsr];
                enum ptr = llvmIRPtr!type ~ " elementtype(" ~ type ~ ")";

                __ir!(
                    `call void asm sideeffect inteldialect "lidt $0", "*m,~{memory}"(` ~ ptr ~ ` %0)`,
                    void
                )(Source);
            }
            else version (GNU)
            {
                asm @system nothrow @nogc
                {
                    "lidt %0" : : "m" (*cast(const(size_t)*) Source) : "memory";
                }
            }
            else version (D_InlineAsm_X86_64)
            {
                asm @system pure nothrow @nogc
                {
                    /* RCX is Source. */
                    naked;
                    lidt [RCX];
                    ret;
                }
            }
            else version (D_InlineAsm_X86)
            {
                asm @system pure nothrow @nogc
                {
                    naked;
                    mov ECX, [ESP + 4]; /* Source. */
                    lidt [ECX];
                    ret;
                }
            }
        }

        extern(C)
        pragma(inline, true)
        ulong __ll_lshift(ulong Mask, int nBit) @safe pure nothrow @nogc
        {
            version (X86_64)
            {
                return Mask << (nBit & 63);
            }
            else version (X86)
            {
                return Mask << (nBit & 31);
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                version (X86_64)
                {
                    assert(
                           __ll_lshift(0b0010000000000000000000000000000000000000000000000000000000000100, 3)
                        == 0b0000000000000000000000000000000000000000000000000000000000100000
                    );
                    assert(
                           __ll_lshift(0b0010000000000000000000000000000000000000000000000000000000000100, 34)
                        == 0b0000000000000000000000000001000000000000000000000000000000000000
                    );
                    assert(
                           __ll_lshift(0b0010000000000000000000000000000000000000000000000000000000000100, 68)
                        == 0b0000000000000000000000000000000000000000000000000000000001000000
                    );
                }
                else version (X86)
                {
                    assert(
                           __ll_lshift(0b0010000000000000000000000000000000000000000000000000000000000100, 3)
                        == 0b0000000000000000000000000000000000000000000000000000000000100000
                    );
                    assert(
                           __ll_lshift(0b0010000000000000000000000000000000000000000000000000000000000100, 34)
                        == 0b1000000000000000000000000000000000000000000000000000000000010000
                    );
                    assert(
                           __ll_lshift(0b0010000000000000000000000000000000000000000000000000000000000100, 68)
                        == 0b0000000000000000000000000000000000000000000000000000000001000000
                    );
                }

                return true;
            }

            assert(test());
            static assert(test());
        }

        extern(C)
        pragma(inline, true)
        long __ll_rshift(long Mask, int nBit) @safe pure nothrow @nogc
        {
            version (X86_64)
            {
                return Mask >> (nBit & 63);
            }
            else version (X86)
            {
                return Mask >> (nBit & 31);
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                version (X86_64)
                {
                    assert(
                           __ll_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 3)
                        == 0b1111110000000000000000000000000000000000000000000000000000000000
                    );
                    assert(
                           __ll_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 34)
                        == 0b1111111111111111111111111111111111111000000000000000000000000000
                    );
                    assert(
                           __ll_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 68)
                        == 0b1111111000000000000000000000000000000000000000000000000000000000
                    );
                }
                else version (X86)
                {
                    assert(
                           __ll_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 3)
                        == 0b1111110000000000000000000000000000000000000000000000000000000000
                    );
                    assert(
                           __ll_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 34)
                        == 0b1111100000000000000000000000000000000000000000000000000000000001
                    );
                    assert(
                           __ll_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 68)
                        == 0b1111111000000000000000000000000000000000000000000000000000000000
                    );
                }

                return true;
            }

            assert(test());
            static assert(test());
        }

        extern(C)
        pragma(inline, true)
        ulong __ull_rshift(ulong Mask, int nBit) @safe pure nothrow @nogc
        {
            version (X86_64)
            {
                return Mask >> (nBit & 63);
            }
            else version (X86)
            {
                return Mask >> (nBit & 31);
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                version (X86_64)
                {
                    assert(
                           __ull_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 3)
                        == 0b0001110000000000000000000000000000000000000000000000000000000000
                    );
                    assert(
                           __ull_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 34)
                        == 0b0000000000000000000000000000000000111000000000000000000000000000
                    );
                    assert(
                           __ull_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 68)
                        == 0b0000111000000000000000000000000000000000000000000000000000000000
                    );
                }
                else version (X86)
                {
                    assert(
                           __ull_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 3)
                        == 0b0001110000000000000000000000000000000000000000000000000000000000
                    );
                    assert(
                           __ull_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 34)
                        == 0b0011100000000000000000000000000000000000000000000000000000000001
                    );
                    assert(
                           __ull_rshift(0b1110000000000000000000000000000000000000000000000000000000000100, 68)
                        == 0b0000111000000000000000000000000000000000000000000000000000000000
                    );
                }

                return true;
            }

            assert(test());
            static assert(test());
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        ushort __lzcnt16(ushort value) @safe pure nothrow @nogc
        {
            return leadingZeroCount(value);
        }

        extern(C)
        pragma(inline, true)
        uint __lzcnt(uint value) @safe pure nothrow @nogc
        {
            return leadingZeroCount(value);
        }

        extern(C)
        pragma(inline, true)
        uint _lzcnt_u32(uint value) @safe pure nothrow @nogc
        {
            return leadingZeroCount(value);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        ulong __lzcnt64(ulong value) @safe pure nothrow @nogc
        {
            return leadingZeroCount(value);
        }

        extern(C)
        pragma(inline, true)
        ulong _lzcnt_u64(ulong value) @safe pure nothrow @nogc
        {
            return leadingZeroCount(value);
        }
    }

    version (X86_64_Or_X86)
    {
        @safe pure nothrow @nogc unittest
        {
            import core.bitop : bsr;
            import core.cpuid : hasLzcnt;

            static bool testLzcnt()
            {
                version (X86_64_Or_X86)
                {
                    assert(__lzcnt16(0) == 16);
                    assert(__lzcnt16(1) == 15);
                    assert(__lzcnt16(ushort.max) == 0);

                    assert(__lzcnt(0) == 32);
                    assert(_lzcnt_u32(0) == 32);
                    assert(__lzcnt(1) == 31);
                    assert(_lzcnt_u32(1) == 31);
                    assert(__lzcnt(uint.max) == 0);
                    assert(_lzcnt_u32(uint.max) == 0);
                }

                version (X86_64)
                {
                    assert(__lzcnt64(0) == 64);
                    assert(_lzcnt_u64(0) == 64);
                    assert(__lzcnt64(1) == 63);
                    assert(_lzcnt_u64(1) == 63);
                    assert(__lzcnt64(ulong.max) == 0);
                    assert(_lzcnt_u64(ulong.max) == 0);
                }

                return true;
            }

            static bool testBsr()
            {
                version (X86_64_Or_X86)
                {
                    assert(__lzcnt16(1) == 0);
                    assert(__lzcnt16(ushort.max) == 15);

                    assert(__lzcnt(1) == 0);
                    assert(_lzcnt_u32(1) == 0);
                    assert(__lzcnt(uint.max) == 31);
                    assert(_lzcnt_u32(uint.max) == 31);
                }

                version (X86_64)
                {
                    assert(__lzcnt64(1) == 0);
                    assert(_lzcnt_u64(1) == 0);
                    assert(__lzcnt64(ulong.max) == 63);
                    assert(_lzcnt_u64(ulong.max) == 63);
                }

                return true;
            }

            if (hasLzcnt)
            {
                assert(testLzcnt());
            }
            else
            {
                assert(testBsr());
            }

            static assert(testLzcnt());
        }

        extern(C)
        pragma(inline, true)
        private T leadingZeroCount(T)(T value) @safe pure nothrow @nogc
        {
            /* We use inline assembly for this, instead of intrinsics or relying on the optimiser,
               so that lzcnt is emitted even for targets that don't support it, just like MSVC does. */

            import core.bitop : bsr;

            if (__ctfe)
            {
                enum T operandSize = cast(T) (T.sizeof << 3);
                enum uint operandSizeLessOne = operandSize - 1;

                return value == 0 ? operandSize : cast(T) (operandSizeLessOne ^ bsr(value));
            }
            else
            {
                version (LDC)
                {
                    import ldc.llvmasm : __ir_pure;

                    enum size = T.sizeof.bsr;
                    enum type = ["i8", "i16", "i32", "i64"][size];

                    return __ir_pure!(
                        `%c = call ` ~ type ~ ` asm inteldialect "lzcnt $0, $1", "=r,r,~{flags}"(` ~ type ~ ` %0)
                         ret ` ~ type ~ ` %c`,
                        T
                    )(value);
                }
                else version (GNU)
                {
                    T result;

                    asm @trusted pure nothrow @nogc
                    {
                        "lzcnt %1, %0" : "=r" (result) : "rm" (value) : "cc";
                    }

                    return result;
                }
                else version (InlineAsm_X86_64_Or_X86)
                {
                    enum size = T.sizeof.bsr;
                    enum a = ["AL", "AX", "EAX", "RAX"][size];

                    version (D_InlineAsm_X86_64)
                    {
                        enum c = ["CL", "CX", "ECX", "RCX"][size];

                        mixin(
                            "asm @trusted pure nothrow @nogc
                             {
                                 /* C is value. */
                                 naked;
                                 lzcnt " ~ a ~ ", " ~ c ~ ";
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
                                 lzcnt " ~ a ~ ", [ESP + 4]; /* [ESP + 4] is value. */
                                 ret;
                             }"
                        );
                    }
                }
            }
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        ushort _tzcnt_u16(ushort value) @safe pure nothrow @nogc
        {
            return trailingZeroCount(value);
        }

        extern(C)
        pragma(inline, true)
        uint _tzcnt_u32(uint value) @safe pure nothrow @nogc
        {
            return trailingZeroCount(value);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        ulong _tzcnt_u64(ulong value) @safe pure nothrow @nogc
        {
            return trailingZeroCount(value);
        }
    }

    version (X86_64_Or_X86)
    {
        @safe pure nothrow @nogc unittest
        {
            import core.bitop : bsr;
            import core.cpuid : hasLzcnt;

            static bool testTzcnt()
            {
                version (X86_64_Or_X86)
                {
                    assert(_tzcnt_u16(0) == 16);
                    assert(_tzcnt_u16(1) == 0);
                    assert(_tzcnt_u16(1 << 15) == 15);
                    assert(_tzcnt_u16(ushort.max) == 0);

                    assert(_tzcnt_u32(0) == 32);
                    assert(_tzcnt_u32(1) == 0);
                    assert(_tzcnt_u32(1 << 31) == 31);
                    assert(_tzcnt_u32(uint.max) == 0);
                }

                version (X86_64)
                {
                    assert(_tzcnt_u64(0) == 64);
                    assert(_tzcnt_u64(1) == 0);
                    assert(_tzcnt_u64(ulong(1) << 63) == 63);
                    assert(_tzcnt_u64(ulong.max) == 0);
                }

                return true;
            }

            static bool testBsf()
            {
                version (X86_64_Or_X86)
                {
                    assert(_tzcnt_u16(1) == 0);
                    assert(_tzcnt_u16(1 << 15) == 15);
                    assert(_tzcnt_u16(ushort.max) == 0);

                    assert(_tzcnt_u32(1) == 0);
                    assert(_tzcnt_u32(1 << 31) == 31);
                    assert(_tzcnt_u32(uint.max) == 0);
                }

                version (X86_64)
                {
                    assert(_tzcnt_u64(1) == 0);
                    assert(_tzcnt_u64(ulong(1) << 63) == 63);
                    assert(_tzcnt_u64(ulong.max) == 0);
                }

                return true;
            }

            if (hasLzcnt)
            {
                assert(testTzcnt());
            }
            else
            {
                assert(testBsf());
            }

            static assert(testTzcnt());
        }

        extern(C)
        pragma(inline, true)
        private T trailingZeroCount(T)(T value) @safe pure nothrow @nogc
        {
            /* We use inline assembly for this, instead of intrinsics or relying on the optimiser,
               so that tzcnt is emitted even for targets that don't support it, just like MSVC does. */

            import core.bitop : bsf, bsr;

            if (__ctfe)
            {
                enum T operandSize = cast(T) (T.sizeof << 3);

                return value == 0 ? operandSize : cast(T) bsf(value);
            }
            else
            {
                version (LDC)
                {
                    import ldc.llvmasm : __ir_pure;

                    enum size = T.sizeof.bsr;
                    enum type = ["i8", "i16", "i32", "i64"][size];

                    return __ir_pure!(
                        `%c = call ` ~ type ~ ` asm inteldialect "tzcnt $0, $1", "=r,r,~{flags}"(` ~ type ~ ` %0)
                         ret ` ~ type ~ ` %c`,
                        T
                    )(value);
                }
                else version (GNU)
                {
                    T result;

                    asm @trusted pure nothrow @nogc
                    {
                        "tzcnt %1, %0" : "=r" (result) : "rm" (value) : "cc";
                    }

                    return result;
                }
                else version (InlineAsm_X86_64_Or_X86)
                {
                    enum size = T.sizeof.bsr;
                    enum a = ["AL", "AX", "EAX", "RAX"][size];

                    version (D_InlineAsm_X86_64)
                    {
                        enum c = ["CL", "CX", "ECX", "RCX"][size];

                        mixin(
                            "asm @trusted pure nothrow @nogc
                             {
                                 /* C is value. */
                                 naked;
                                 tzcnt " ~ a ~ ", " ~ c ~ ";
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
                                 tzcnt " ~ a ~ ", [ESP + 4]; /* [ESP + 4] is value. */
                                 ret;
                             }"
                        );
                    }
                }
            }
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        float4 _mm_cvtsi64x_ss(float4 a, long b) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                a.array[0] = ctfeX86RoundLongToFloat(b);
                return a;
            }
            else
            {
                version (LDC)
                {
                    /* LLVM lacks an intrinsic for the 64-bit version of cvtsi2ss, but this
                       emits said instruction even when optimisations aren't enabled. */
                    a.array[0] = cast(float) b;
                    return a;
                }
                else version (GNU)
                {
                    import gcc.builtins : __builtin_ia32_cvtsi642ss;
                    return __builtin_ia32_cvtsi642ss(a, b);
                }
                else version (D_InlineAsm_X86_64)
                {
                    /* We could use core.simd.__simd_sto for this, but we don't, because doing so causes
                       DMD to miscompile calls to this function when optimisations are enabled. */

                    enum ubyte REX_W = 0b0100_1000;

                    asm @trusted pure nothrow @nogc
                    {
                        /* RCX is a; RDX is b. */
                        naked;
                        movdqa XMM0, [RCX];
                        /* DMD refuses to encode `cvtsi2ss XMM0, RDX`, so we'll encode it by hand. */
                        db 0xF3, REX_W, 0x0F, 0x2A, 0b11_000_010; /* cvtsi2ss XMM0, RDX */
                        ret;
                    }
                }
            }
        }

        @trusted pure nothrow @nogc unittest
        {
            static bool test()
            {
                alias convert = _mm_cvtsi64x_ss;
                float4 floats = 2.0f;

                void check(long value, float result)
                {
                    float4 actual = convert(floats, value);
                    assert(actual.ptr[0] == result);
                    assert(actual.ptr[1] == 2.0f);
                    assert(actual.ptr[2] == 2.0f);
                    assert(actual.ptr[3] == 2.0f);
                }

                check(6, 6.0f);
                check(long.min, -twoExp63Float);
                check(long.max, twoExp63Float);
                check(9223371761976868864, twoExp63Float);
                check(9223371761976868863, justUnderTwoExp63Float);
                check(9223371487098961920, justUnderTwoExp63Float);
                check(-9223371761976868864, -twoExp63Float);
                check(-9223371761976868863, -justUnderTwoExp63Float);
                check(-9223371487098961920, -justUnderTwoExp63Float);
                check(33554434, 33554432.0f);
                check(-33554434, -33554432.0f);
                check(33554438, 33554440.0f);
                check(-33554438, -33554440.0f);

                return true;
            }

            assert(test());
            static assert(test());
        }

        extern(C)
        pragma(inline, true)
        long _mm_cvtss_si64x(float4 value) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                return ctfeX86RoundFloatToLong(value.array[0]);
            }
            else
            {
                version (LDC_Or_GNU)
                {
                    mixin(q{import }, gccBuiltins, q{ : __builtin_ia32_cvtss2si64;});

                    return __builtin_ia32_cvtss2si64(value);
                }
                else version (D_InlineAsm_X86_64)
                {
                    enum ubyte REX_W = 0b0100_1000;

                    asm @trusted pure nothrow @nogc
                    {
                        /* RCX is value. */
                        naked;
                        /* DMD refuses to encode `cvtss2si RAX, [RCX]`, so we'll encode it by hand. */
                        db 0xF3, REX_W, 0x0F, 0x2D, 0b00_000_001; /* cvtss2si RAX, [RCX] */
                        ret;
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_mm_cvtss_si64x([0.0f, 0.0f, 1.0f, 2.0f]) == 0);
                assert(_mm_cvtss_si64x([1.0f, 0.0f, 1.0f, 2.0f]) == 1);
                assert(_mm_cvtss_si64x([1.5f, 0.0f, 1.0f, 2.0f]) == 2);
                assert(_mm_cvtss_si64x([2.5f, 0.0f, 1.0f, 2.0f]) == 2);
                assert(_mm_cvtss_si64x([3.5f, 0.0f, 1.0f, 2.0f]) == 4);
                assert(_mm_cvtss_si64x([4.5f, 0.0f, 1.0f, 2.0f]) == 4);
                assert(_mm_cvtss_si64x([4.51f, 0.0f, 1.0f, 2.0f]) == 5);
                assert(_mm_cvtss_si64x([4.51f, 0.0f, 1.0f, 2.0f]) == 5);
                assert(_mm_cvtss_si64x([5.49f, 0.0f, 1.0f, 2.0f]) == 5);
                assert(_mm_cvtss_si64x([33554432.0f, 0.0f, 1.0f, 2.0f]) == 33554432);
                assert(_mm_cvtss_si64x([-33554432.0f, 0.0f, 1.0f, 2.0f]) == -33554432);
                assert(_mm_cvtss_si64x([justUnderTwoExp63Float, 0.0f, 1.0f, 2.0f]) == 9223371487098961920);
                assert(_mm_cvtss_si64x([-twoExp63Float, 0.0f, 1.0f, 2.0f]) == long.min);
                assert(_mm_cvtss_si64x([twoExp63Float, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);
                assert(_mm_cvtss_si64x([float.nan, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);
                assert(_mm_cvtss_si64x([-float.nan, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);
                assert(_mm_cvtss_si64x([float.infinity, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);
                assert(_mm_cvtss_si64x([-float.infinity, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);

                return true;
            }

            assert(test());
            static assert(test());
        }

        extern(C)
        pragma(inline, true)
        long _mm_cvttss_si64x(float4 value) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                float v = value.array[0];

                if (v < twoExp63Float && v >= -twoExp63Float)
                {
                    return cast(long) v;
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

                    asm @trusted pure nothrow @nogc
                    {
                        /* RCX is value. */
                        naked;
                        /* DMD refuses to encode `cvttss2si RAX, [RCX]`, so we'll encode it by hand. */
                        db 0xF3, REX_W, 0x0F, 0x2C, 0b00_000_001; /* cvttss2si RAX, [RCX] */
                        ret;
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(_mm_cvttss_si64x([0.0f, 0.0f, 1.0f, 2.0f]) == 0);
                assert(_mm_cvttss_si64x([1.0f, 0.0f, 1.0f, 2.0f]) == 1);
                assert(_mm_cvttss_si64x([1.5f, 0.0f, 1.0f, 2.0f]) == 1);
                assert(_mm_cvttss_si64x([2.5f, 0.0f, 1.0f, 2.0f]) == 2);
                assert(_mm_cvttss_si64x([3.5f, 0.0f, 1.0f, 2.0f]) == 3);
                assert(_mm_cvttss_si64x([4.5f, 0.0f, 1.0f, 2.0f]) == 4);
                assert(_mm_cvttss_si64x([4.51f, 0.0f, 1.0f, 2.0f]) == 4);
                assert(_mm_cvttss_si64x([4.51f, 0.0f, 1.0f, 2.0f]) == 4);
                assert(_mm_cvttss_si64x([5.49f, 0.0f, 1.0f, 2.0f]) == 5);
                assert(_mm_cvttss_si64x([33554432.0f, 0.0f, 1.0f, 2.0f]) == 33554432);
                assert(_mm_cvttss_si64x([-33554432.0f, 0.0f, 1.0f, 2.0f]) == -33554432);
                assert(_mm_cvttss_si64x([justUnderTwoExp63Float, 0.0f, 1.0f, 2.0f]) == 9223371487098961920);
                assert(_mm_cvttss_si64x([-twoExp63Float, 0.0f, 1.0f, 2.0f]) == long.min);
                assert(_mm_cvttss_si64x([twoExp63Float, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);
                assert(_mm_cvttss_si64x([float.nan, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);
                assert(_mm_cvttss_si64x([-float.nan, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);
                assert(_mm_cvttss_si64x([float.infinity, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);
                assert(_mm_cvttss_si64x([-float.infinity, 0.0f, 1.0f, 2.0f]) == 0x80000000_00000000);

                return true;
            }

            assert(test());
            static assert(test());
        }
    }

    static if (canPassVectors)
    {
        version (X86_64_Or_X86)
        {
            extern(C)
            pragma(inline, true)
            int4 _mm_extract_si64(int4 Source, int4 Descriptor) @safe pure nothrow @nogc
            {
                if (__ctfe)
                {
                    return ctfeExtrq(Source, Descriptor);
                }
                else
                {
                    version (LDC)
                    {
                        static if (__traits(targetHasFeature, "sse4a"))
                        {
                            import ldc.gccbuiltins_x86 : __builtin_ia32_extrq;
                            return cast(int4) __builtin_ia32_extrq(cast(long2) Source, cast(byte16) Descriptor);
                        }
                        else
                        {
                            int4 result;

                            asm @trusted pure nothrow @nogc
                            {
                                "extrq %2, %1" : "=x" (result) : "0" (Source), "x" (Descriptor);
                            }

                            return result;
                        }
                    }
                    else version (GNU)
                    {
                        static if (__traits(compiles, () {import gcc.builtins : __builtin_ia32_extrq;}))
                        {
                            import gcc.builtins : __builtin_ia32_extrq;
                            return cast(int4) __builtin_ia32_extrq(cast(long2) Source, cast(ubyte16) Descriptor);
                        }
                        else
                        {
                            int4 result;

                            asm @trusted pure nothrow @nogc
                            {
                                "extrq %2, %1" : "=x" (result) : "0" (Source), "x" (Descriptor);
                            }

                            return result;
                        }
                    }
                    else version (D_InlineAsm_X86_64)
                    {
                        /* __simd can't encode extrq properly. :( */
                        asm @trusted pure nothrow @nogc
                        {
                            /* RCX is Source; RDX is Descriptor. */
                            naked;
                            movdqa XMM0, [RCX];
                            movdqa XMM1, [RDX];
                            /* DMD doesn't know the extrq instruction, so we encode it by hand. */
                            db 0x66, 0x0F, 0x79, 0b11_000_001; /* extrq XMM0, XMM1 */
                            ret;
                        }
                    }
                }
            }

            @safe pure nothrow @nogc unittest
            {
                import core.cpuid : sse4a;

                if (!sse4a)
                {
                    return;
                }

                static bool t(int source, int layout, int4 expected)
                {
                    int4 s;
                    s.array[0] = source;
                    int4 l;
                    l.array[0] = layout;

                    return _mm_extract_si64(s, l).array == expected.array;
                }

                static bool test()
                {
                    assert(t(0b00001011_11100101, 4 | (12 << 8), [0, 0, 0, 0]));
                    assert(t(0b00001011_11100101, 0 | (12 << 8), [0, 0, 0, 0]));
                    assert(t(0b00001011_11100101, 8 | (0 << 8), [0b11100101, 0, 0, 0]));
                    assert(t(0b00001011_11100101, 0 | (0 << 8), [0b00001011_11100101, 0, 0, 0]));
                    assert(t(0b00001011_11100101, 0 | (4 << 8), [0b0000_10111110, 0, 0, 0]));

                    return true;
                }

                assert(test());
                static assert(test());
            }

            extern(C)
            pragma(inline, true)
            int4 _mm_extracti_si64(int4 Source, int Length, int Index) @safe pure nothrow @nogc
            {
                int4 layout;
                layout.array[0] = (Length & 0xFF) | ((Index << 8) & 0xFF00);

                return _mm_extract_si64(Source, layout);
            }

            @safe pure nothrow @nogc unittest
            {
                import core.cpuid : sse4a;

                if (!sse4a)
                {
                    return;
                }

                static bool test()
                {
                    alias extrq = _mm_extracti_si64;

                    assert(extrq([0b00001011_11100101, 0, 0, 0], 4, 12).array == [0, 0, 0, 0]);
                    assert(extrq([0b00001011_11100101, 0, 0, 0], 0, 12).array == [0, 0, 0, 0]);
                    assert(extrq([0b00001011_11100101, 0, 0, 0], 8, 0).array == [0b11100101, 0, 0, 0]);
                    assert(extrq([0b00001011_11100101, 0, 0, 0], 0, 0).array == [0b00001011_11100101, 0, 0, 0]);
                    assert(extrq([0b00001011_11100101, 0, 0, 0], 0, 4).array == [0b0000_10111110, 0, 0, 0]);

                    return true;
                }

                assert(test());
                static assert(test());
            }

            pragma(inline, true)
            private int4 ctfeExtrq()(int4 source, int4 bitLayout) @safe pure nothrow @nogc
            {
                ulong lowQuad = ulong(cast(uint) source.array[0]) | (ulong(cast(uint) source.array[1]) << 32);

                uint layout = bitLayout.array[0];
                ubyte bitCount = layout & 63;
                ubyte bitIndex = (layout >>> 8) & 63;
                ulong mask = bitCount == 0 ? ulong.max : (ulong(1) << bitCount) - 1;

                ulong extracted = (lowQuad >>> bitIndex) & (mask);
                int4 result;
                result.array[0] = cast(uint) extracted;
                result.array[1] = cast(uint) (extracted >>> 32);

                return result;
            }

            @safe pure nothrow @nogc unittest
            {
                import core.cpuid : sse4a;

                if (!sse4a)
                {
                    return;
                }

                long2 longParts;
                longParts.array[0] = 0x9ABAFFF1B15C4933;
                longParts.array[1] = 0x2488781C67F75A1C;
                int4 intParts = cast(int4) longParts;

                static int4 layout(ubyte bitCount, ubyte bitIndex)
                {
                    return (uint(bitIndex) << 8) | bitCount;
                }

                foreach (ubyte index; 0 .. (1 << 6))
                {
                    foreach (ubyte count; 0 .. (1 << 6))
                    {
                        int4 bitLayout = layout(count, index);
                        int4 result = _mm_extract_si64(intParts, bitLayout);

                        assert(result.array == _mm_extracti_si64(intParts, count, index).array);
                        assert(result.array == ctfeExtrq(intParts, bitLayout).array);
                    }
                }

                assert(_mm_extract_si64(intParts, layout(64, 64)).array == ctfeExtrq(intParts, layout(64, 64)).array);
                assert(_mm_extract_si64(intParts, layout(65, 65)).array == ctfeExtrq(intParts, layout(65, 65)).array);
            }

            extern(C)
            pragma(inline, true)
            int4 _mm_insert_si64(int4 Source1, int4 Source2) @safe pure nothrow @nogc
            {
                if (__ctfe)
                {
                    return ctfeInsertq(Source1, Source2);
                }
                else
                {
                    version (LDC)
                    {
                        static if (__traits(targetHasFeature, "sse4a"))
                        {
                            import ldc.gccbuiltins_x86 : __builtin_ia32_insertq;
                            return cast(int4) __builtin_ia32_insertq(cast(long2) Source1, cast(long2) Source2);
                        }
                        else
                        {
                            int4 result;

                            asm @trusted pure nothrow @nogc
                            {
                                "insertq %2, %1" : "=x" (result) : "0" (Source1), "x" (Source2);
                            }

                            return result;
                        }
                    }
                    else version (GNU)
                    {
                        static if (__traits(compiles, () {import gcc.builtins : __builtin_ia32_insertq;}))
                        {
                            import gcc.builtins : __builtin_ia32_insertq;
                            return cast(int4) __builtin_ia32_insertq(cast(long2) Source1, cast(long2) Source2);
                        }
                        else
                        {
                            int4 result;

                            asm @trusted pure nothrow @nogc
                            {
                                "insertq %2, %1" : "=x" (result) : "0" (Source1), "x" (Source2);
                            }

                            return result;
                        }
                    }
                    else version (D_InlineAsm_X86_64)
                    {
                        /* __simd can't encode insertq properly. :( */
                        asm @trusted pure nothrow @nogc
                        {
                            /* RCX is Source1; RDX is Source2. */
                            naked;
                            movdqa XMM0, [RCX];
                            movdqa XMM1, [RDX];
                            /* DMD doesn't know the insertq instruction, so we encode it by hand. */
                            db 0xF2, 0x0F, 0x79, 0b11_000_001; /* insertq XMM0, XMM1 */
                            ret;
                        }
                    }
                }
            }

            @safe pure nothrow @nogc unittest
            {
                import core.cpuid : sse4a;

                if (!sse4a)
                {
                    return;
                }

                static bool t(int destination, int source, int layout, int4 expected)
                {
                    int4 d;
                    d.array[0] = destination;
                    int4 s;
                    s.array[0] = source;
                    s.array[2] = layout;

                    return _mm_insert_si64(d, s).array == expected.array;
                }

                static bool test()
                {
                    assert(t(0b0101, 0b11010, 4 | (12 << 8), [0b10100000_00000101, 0, 0, 0]));
                    assert(t(0b0101, 0b11010, 0 | (12 << 8), [0b1_10100000_00000101, 0, 0, 0]));
                    assert(t(0b0101, 0b11010, 2 | (0 << 8), [0b0110, 0, 0, 0]));
                    assert(t(0b0101, 0b11010, 0 | (0 << 8), [0b11010, 0, 0, 0]));
                    assert(t(0b0101, 0b11010, 3 | (2 << 8), [0b01001, 0, 0, 0]));

                    return true;
                }

                assert(test());
                static assert(test());
            }

            extern(C)
            pragma(inline, true)
            int4 _mm_inserti_si64(int4 Source1, int4 Source2, int Length, int Index) @safe pure nothrow @nogc
            {
                int4 layout = Source2;
                layout.array[2] = (Length & 0xFF) | ((Index << 8) & 0xFF00);

                return _mm_insert_si64(Source1, layout);
            }

            @safe pure nothrow @nogc unittest
            {
                import core.cpuid : sse4a;

                if (!sse4a)
                {
                    return;
                }

                static bool test()
                {
                    alias insertq = _mm_inserti_si64;

                    assert(insertq([0b0101, 0, 0, 0], [0b11010], 4, 12).array == [0b10100000_00000101, 0, 0, 0]);
                    assert(insertq([0b0101, 0, 0, 0], [0b11010], 0, 12).array == [0b1_10100000_00000101, 0, 0, 0]);
                    assert(insertq([0b0101, 0, 0, 0], [0b11010], 2, 0).array == [0b0110, 0, 0, 0]);
                    assert(insertq([0b0101, 0, 0, 0], [0b11010], 0, 0).array == [0b11010, 0, 0, 0]);
                    assert(insertq([0b0101, 0, 0, 0], [0b11010], 3, 2).array == [0b01001, 0, 0, 0]);

                    return true;
                }

                assert(test());
                static assert(test());
            }

            pragma(inline, true)
            private int4 ctfeInsertq()(int4 destination, int4 source) @safe pure nothrow @nogc
            {
                uint layout = source.array[2];
                ubyte bitCount = layout & 63;
                ubyte bitIndex = (layout >>> 8) & 63;
                ulong mask = bitCount == 0 ? ulong.max : (ulong(1) << bitCount) - 1;

                ulong destinationLo = cast(uint) destination.array[0] | (ulong(cast(uint) destination.array[1]) << 32);
                ulong sourceLo = cast(uint) source.array[0] | (ulong(cast(uint) source.array[1]) << 32);

                ulong inserted = (destinationLo & ~(mask << bitIndex)) | ((sourceLo & mask) << bitIndex);
                int4 result;
                result.array[0] = cast(uint) inserted;
                result.array[1] = cast(uint) (inserted >>> 32);

                return result;
            }

            @safe pure nothrow @nogc unittest
            {
                import core.cpuid : sse4a;

                if (!sse4a)
                {
                    return;
                }

                long2 longDestination;
                longDestination.array[0] = 0x9ABAFFF1B15C4933;
                longDestination.array[1] = 0x2488781C67F75A1C;
                int4 intDestination = cast(int4) longDestination;

                long2 longSource;
                longSource.array[0] = 0x76D41814E48AE48A;
                longSource.array[1] = 0xC221DB7BB89ACBC2;
                int4 intSource = cast(int4) longSource;

                static uint layout(ubyte bitCount, ubyte bitIndex)
                {
                    return (uint(bitIndex) << 8) | bitCount;
                }

                foreach (ubyte index; 0 .. (1 << 6))
                {
                    foreach (ubyte count; 0 .. (1 << 6))
                    {
                        int4 source = intSource;
                        source.array[2] = layout(count, index);

                        int4 result = _mm_insert_si64(intDestination, source);

                        assert(result.array == _mm_inserti_si64(intDestination, intSource, count, index).array);
                        assert(result.array == ctfeInsertq(intDestination, source).array);
                    }
                }

                int4 source = intSource;

                source.array[2] = layout(64, 64);
                assert(_mm_insert_si64(intDestination, source).array == ctfeInsertq(intDestination, source).array);
                source.array[2] = layout(65, 65);
                assert(_mm_insert_si64(intDestination, source).array == ctfeInsertq(intDestination, source).array);
            }

            extern(C)
            pragma(inline, true)
            void _mm_stream_sd(scope double* Dest, double2 Source) @safe pure nothrow @nogc
            {
                if (__ctfe)
                {
                    *Dest = Source.array[0];
                }
                else
                {
                    version (LDC)
                    {
                        static if (__traits(targetHasFeature, "sse4a"))
                        {
                            import ldc.llvmasm : __irEx_pure;

                            __irEx_pure!(
                                "",
                                `%lowDouble = extractelement <2 x double> %1, i32 0
                                 store double %lowDouble, ` ~ llvmIRPtr!"double" ~ ` %0, !nontemporal !0`,
                                 "!0 = !{i32 1}",
                                void
                            )(Dest, Source);
                        }
                        else
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                "movntsd %1, %0" : "=m" (*Dest) : "x" (Source);
                            }
                        }
                    }
                    else version (GNU)
                    {
                        static if (__traits(compiles, () {import gcc.builtins : __builtin_ia32_movntsd;}))
                        {
                            import gcc.builtins : __builtin_ia32_movntsd;
                            __builtin_ia32_movntsd(Dest, Source);
                        }
                        else
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                "movntsd %1, %0" : "=m" (*Dest) : "x" (Source);
                            }
                        }
                    }
                    else version (D_InlineAsm_X86_64)
                    {
                        asm @trusted pure nothrow @nogc
                        {
                            /* RCX is Dest; RDX is Source. */
                            naked;
                            movaps XMM0, [RDX];
                            /* DMD doesn't know the movntsd instruction, so we encode it by hand. */
                            db 0xF2, 0x0F, 0x2B, 0b00_000_001; /* movntsd [RCX], XMM0 */
                            ret;
                        }
                    }
                }
            }

            /* This is trusted so that it's @safe without DIP1000 enabled. */
            @trusted pure nothrow @nogc unittest
            {
                import core.cpuid : sse4a;

                if (!sse4a)
                {
                    return;
                }

                static bool test()
                {
                    double value = double.nan;

                    _mm_stream_sd(&value, [22.0, 31.0]);
                    assert(value == 22.0);
                    _mm_stream_sd(&value, [0.0, 31.0]);
                    assert(value == 0.0);
                    _mm_stream_sd(&value, [double.nan, 0.0]);
                    assert(value != value);

                    return true;
                }

                assert(test());
                static assert(test());
            }

            extern(C)
            pragma(inline, true)
            void _mm_stream_ss(scope float* Destination, float4 Source) @safe pure nothrow @nogc
            {
                if (__ctfe)
                {
                    *Destination = Source.array[0];
                }
                else
                {
                    version (LDC)
                    {
                        static if (__traits(targetHasFeature, "sse4a"))
                        {
                            import ldc.llvmasm : __irEx_pure;

                            __irEx_pure!(
                                "",
                                `%lowFloat = extractelement <4 x float> %1, i32 0
                                 store float %lowFloat, ` ~ llvmIRPtr!"float" ~ ` %0, !nontemporal !0`,
                                 "!0 = !{i32 1}",
                                void
                            )(Destination, Source);
                        }
                        else
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                "movntss %1, %0" : "=m" (*Destination) : "x" (Source);
                            }
                        }
                    }
                    else version (GNU)
                    {
                        static if (__traits(compiles, () {import gcc.builtins : __builtin_ia32_movntss;}))
                        {
                            import gcc.builtins : __builtin_ia32_movntss;
                            __builtin_ia32_movntss(Destination, Source);
                        }
                        else
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                "movntss %1, %0" : "=m" (*Destination) : "x" (Source);
                            }
                        }
                    }
                    else version (D_InlineAsm_X86_64)
                    {
                        asm @trusted pure nothrow @nogc
                        {
                            /* RCX is Destination; RDX is Source. */
                            naked;
                            movaps XMM0, [RDX];
                            /* DMD doesn't know the movntss instruction, so we encode it by hand. */
                            db 0xF3, 0x0F, 0x2B, 0b00_000_001; /* movntss [RCX], XMM0 */
                            ret;
                        }
                    }
                }
            }

            /* This is trusted so that it's @safe without DIP1000 enabled. */
            @trusted pure nothrow @nogc unittest
            {
                import core.cpuid : sse4a;

                if (!sse4a)
                {
                    return;
                }

                static bool test()
                {
                    float value = float.nan;

                    _mm_stream_ss(&value, [22.0f, 31.0f, 4.0f, 5.0f]);
                    assert(value == 22.0f);
                    _mm_stream_ss(&value, [0.0f, 31.0f, 4.0f, 5.0f]);
                    assert(value == 0.0f);
                    _mm_stream_ss(&value, [float.nan, 0.0f, 4.0f, 5.0f]);
                    assert(value != value);

                    return true;
                }

                assert(test());
                static assert(test());
            }
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        void _mm_stream_si64x(scope long* Destination, long Source) @safe pure nothrow @nogc
        {
            if (__ctfe)
            {
                *Destination = Source;
            }
            else
            {
                version (LDC)
                {
                    import ldc.llvmasm : __irEx_pure;

                    __irEx_pure!(
                        "",
                        `store i64 %1, ` ~ llvmIRPtr!"i64" ~ ` %0, !nontemporal !0`,
                         "!0 = !{i32 1}",
                        void
                    )(Destination, Source);
                }
                else version (GNU)
                {
                    import gcc.builtins : __builtin_ia32_movnti64;
                    __builtin_ia32_movnti64(Destination, Source);
                }
                else version (D_InlineAsm_X86_64)
                {
                    enum ubyte REX_W = 0b0100_1000;

                    asm @trusted pure nothrow @nogc
                    {
                        /* RCX is Destination; RDX is Source. */
                        naked;
                        /* DMD refuses to encode `movnti [RCX], RDX`, so we'll encode it by hand. */
                        db REX_W, 0x0F, 0xC3, 0b00_010_001; /* movnti [RCX], RDX */
                        ret;
                    }
                }
            }
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        @trusted pure nothrow @nogc unittest
        {
            static bool test()
            {
                long value = long.max;

                _mm_stream_si64x(&value, 0);
                assert(value == 0);
                _mm_stream_si64x(&value, 23);
                assert(value == 23);

                return true;
            }

            assert(test());
            static assert(test());
        }
    }

    version (X86_64)
    {
        /* This is trusted so that it's @safe without DIP1000 enabled. */
        private float ctfeX86RoundLongToFloat()(long value) @trusted pure nothrow @nogc
        {
            import core.bitop : bsr;

            if (value == 0)
            {
                return 0.0f;
            }
            else
            {
                long sign = value >> 63;
                /* If the value is negative, we negate it. */
                ulong unsignedValue = (value ^ sign) - sign;
                uint exponent = bsr(unsignedValue);

                if (exponent < 24)
                {
                    /* A float can represent this integer exactly, so we just cast the thing. */
                    return cast(float) value;
                }
                else
                {
                    /* Beyond exponents of 24-and-more, power-of-two-sized gaps begin to form between the integers
                       that a float can represent, and we want to round any integers that fall within those gaps.

                       We'll call `exponent - 23` the excess.
                       The gap between each integer is `1 << excess`, which means that we round the integers
                       based on the value of their least-significant n-bits, where n is excess.
                       When those bits are less-than half of the gap-size, we'll round down to the previous
                       multiple of the gap-size; when those bits are greater-than half of the gap-size, we'll
                       round up to the next multiple of the gap-size; otherwise, if those bits are exactly
                       half of the gap-size, the direction we round in depends on the value of the nth-bit of the
                       integer, where again n is excess: if that bit is 1, we round up, otherwise we round down. */

                    uint excess = exponent - 23;
                    ulong gapBetweenIntegers = ulong(1) << excess;
                    ulong halfwayBetweenGap = ulong(1) << (excess - 1);
                    ulong excessMask = gapBetweenIntegers - 1;
                    ulong excessBits = unsignedValue & excessMask;
                    ulong base = ulong(1) << exponent;

                    bool roundUp = excessBits > (halfwayBetweenGap - ((unsignedValue & gapBetweenIntegers) != 0));

                    ulong rounded = ((unsignedValue - base) + (ulong(1) << (excess * roundUp)) - 1) & ~excessMask;
                    bool shouldGoUpAnExponent = rounded == base;

                    uint asInt = cast(uint) sign << 31;
                    asInt |= (exponent + shouldGoUpAnExponent + 127) << 23;
                    asInt |= (cast(uint) (rounded >>> excess)) * !shouldGoUpAnExponent;

                    return *(cast(const(float)*) &asInt);
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(ctfeX86RoundLongToFloat(0) is 0.0f);
                assert(ctfeX86RoundLongToFloat(1) is 1.0f);
                assert(ctfeX86RoundLongToFloat(2) is 2.0f);
                assert(ctfeX86RoundLongToFloat(-1) is -1.0f);
                assert(ctfeX86RoundLongToFloat(-2) is -2.0f);
                assert(ctfeX86RoundLongToFloat(9223371761976868864) is twoExp63Float);
                assert(ctfeX86RoundLongToFloat(9223371761976868863) is justUnderTwoExp63Float);
                assert(ctfeX86RoundLongToFloat(9223371487098961920) is justUnderTwoExp63Float);
                assert(ctfeX86RoundLongToFloat(-9223371761976868864) is -twoExp63Float);
                assert(ctfeX86RoundLongToFloat(-9223371761976868863) is -justUnderTwoExp63Float);
                assert(ctfeX86RoundLongToFloat(-9223371487098961920) is -justUnderTwoExp63Float);
                assert(ctfeX86RoundLongToFloat(33554434) is 33554432.0f);
                assert(ctfeX86RoundLongToFloat(-33554434) is -33554432.0f);
                assert(ctfeX86RoundLongToFloat(33554438) is 33554440.0f);
                assert(ctfeX86RoundLongToFloat(-33554438) is -33554440.0f);

                return true;
            }

            assert(test());
            static assert(test());
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        private long ctfeX86RoundFloatToLong()(float value) @trusted pure nothrow @nogc
        {
            /* For CTFE, we'll assume that the rounding-mode is the default for x86,
               which is to round half to the nearest even value. */

            if (value < twoExp63Float && value >= -twoExp63Float)
            {
                enum uint implicitBit = 0b0_00000001_00000000000000000000000;
                enum uint significandMask = 0b0_00000001_11111111111111111111111;
                enum uint fractionalHalf = 0b0_00000001_00000000000000000000000;
                enum uint justUnderFractionalHalf = fractionalHalf - 1;

                int asInt = *(cast(const(int)*) &value);

                byte exponent = cast(byte) ((cast(ubyte) (asInt >>> 23)) - 126);

                if (exponent <= -1)
                {
                    return 0;
                }

                uint significand = (asInt & significandMask) | implicitBit;
                ulong unsignedResult;

                if (exponent >= 24)
                {
                    /* The value has no fractional-part, so there's no need to round it. */
                    unsignedResult = ulong(significand) << (exponent - 24);
                }
                else
                {
                    /* The value has a fractional-part, so we need to round it. */
                    uint fraction = (significand << exponent) & significandMask;
                    uint whole = significand >>> (24 - exponent);
                    bool adjustment = fraction > ((whole & 1) ? justUnderFractionalHalf : fractionalHalf);
                    unsignedResult = whole + adjustment;
                }

                long sign = long(asInt >> 31);

                /* If the sign bit is set, we need to negate the result; we can do that branchlessly
                   by taking advantage of the fact that `sign` is either 0 or -1.
                   As `(s ^ 0) - 0 == s`, whereas `(s ^ -1) - -1 == -s`. */
                return (unsignedResult ^ sign) - sign;
            }

            return long.min;
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(ctfeX86RoundFloatToLong(0.0f) == 0);
                assert(ctfeX86RoundFloatToLong(-0.0f) == 0);
                assert(ctfeX86RoundFloatToLong(float.nan) == 0x80000000_00000000);
                assert(ctfeX86RoundFloatToLong(-float.nan) == 0x80000000_00000000);
                assert(ctfeX86RoundFloatToLong(float.infinity) == 0x80000000_00000000);
                assert(ctfeX86RoundFloatToLong(-float.infinity) == 0x80000000_00000000);
                assert(ctfeX86RoundFloatToLong(1.0f) == 1);
                assert(ctfeX86RoundFloatToLong(-1.0f) == -1);
                assert(ctfeX86RoundFloatToLong(2.5f) == 2);
                assert(ctfeX86RoundFloatToLong(-2.5f) == -2);
                assert(ctfeX86RoundFloatToLong(3.5f) == 4);
                assert(ctfeX86RoundFloatToLong(-3.5f) == -4);
                assert(ctfeX86RoundFloatToLong(3.49f) == 3);
                assert(ctfeX86RoundFloatToLong(-3.49f) == -3);
                assert(ctfeX86RoundFloatToLong(twoExp63Float) == 0x80000000_00000000);
                assert(ctfeX86RoundFloatToLong(-twoExp63Float) == long.min);
                assert(ctfeX86RoundFloatToLong(justUnderTwoExp63Float) == 9223371487098961920);
                assert(ctfeX86RoundFloatToLong(33554432.0f) == 33554432);
                assert(ctfeX86RoundFloatToLong(-33554432.0f) == -33554432);
                assert(ctfeX86RoundFloatToLong(33554436.0f) == 33554436);
                assert(ctfeX86RoundFloatToLong(-33554436.0f) == -33554436);

                return true;
            }

            assert(test());
            static assert(test());
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        void __movsb(scope ubyte* Destination, const(ubyte)* Source, size_t Count) @system pure nothrow @nogc
        {
            return repMovs(Destination, Source, Count);
        }

        extern(C)
        pragma(inline, true)
        void __movsw(scope ushort* Destination, const(ushort)* Source, size_t Count) @system pure nothrow @nogc
        {
            return repMovs(Destination, Source, Count);
        }

        extern(C)
        pragma(inline, true)
        void __movsd(scope uint* Destination, const(uint)* Source, size_t Count) @system pure nothrow @nogc
        {
            return repMovs(Destination, Source, Count);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        void __movsq(scope ulong* Destination, const(ulong)* Source, size_t Count) @system pure nothrow @nogc
        {
            return repMovs(Destination, Source, Count);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        private void repMovs(T)(scope T* destination, scope const(T)* source, size_t length) @system pure nothrow @nogc
        {
            import core.bitop : bsr;

            if (__ctfe)
            {
                foreach (index; 0 .. length)
                {
                    destination[index] = source[index];
                }
            }
            else
            {
                enum size = T.sizeof.bsr;

                version (LDC)
                {
                    import core.bitop : bsr;
                    import ldc.llvmasm : __ir_pure;

                    enum char suffix = "bwlq"[size];
                    enum dataType = ["i8", "i16", "i32", "i64"][size];
                    enum ptr = llvmIRPtr!dataType;
                    enum lengthType = ["i8", "i16", "i32", "i64"][size_t.sizeof.bsr];

                    version (X86)
                    {
                        enum indexPrefix = 'e';
                    }
                    else version (X86_64)
                    {
                        enum indexPrefix = 'r';
                    }

                    __ir_pure!(
                        `call {` ~ ptr ~ `, ` ~ ptr ~ `, ` ~ lengthType ~ `} asm
                         "rep movs` ~ suffix ~ `",
                         "=&{` ~ indexPrefix ~ `di},=&{` ~ indexPrefix ~ `si},=&{ecx},0,1,2,~{memory}"
                         (` ~ ptr ~ ` %0, ` ~ ptr ~ ` %1, ` ~ lengthType ~ ` %2)`,
                        void
                    )(destination, source, length);
                }
                else version (GNU)
                {
                    enum char suffix = "bwlq"[size];

                    asm @system pure nothrow @nogc
                     {
                           "rep movs" ~ suffix
                         : "=D" (destination), "=S" (source), "=c" (length)
                         : "0" (destination), "1" (source), "2" (length)
                         : "memory";
                     }
                }
                else version (InlineAsm_X86_64_Or_X86)
                {
                    enum char suffix = "bwdq"[size];

                    version (D_InlineAsm_X86_64)
                    {
                        mixin(
                            "asm @system pure nothrow @nogc
                             {
                                 /* RCX is destination; RDX is source; R8 is length. */
                                 naked;
                                 mov R9, RDI; /* RDI is non-volatile, so we save it in R9. */
                                 mov RAX, RSI; /* RSI is non-volatile, so we save it in RAX. */
                                 mov RDI, RCX;
                                 mov RCX, R8;
                                 mov RSI, RDX;
                                 rep; movs" ~ suffix ~ ";
                                 mov RSI, RAX;
                                 mov RDI, R9;
                                 ret;
                             }"
                        );
                    }
                    else version (D_InlineAsm_X86)
                    {
                        mixin(
                            "asm @system pure nothrow @nogc
                             {
                                 naked;
                                 mov EAX, EDI; /* EDI is non-volatile, so we save it in EAX. */
                                 mov EDX, ESI; /* ESI is non-volatile, so we save it in EDX. */
                                 mov EDI, [ESP +  4]; /* destination. */
                                 mov ESI, [ESP +  8]; /* source. */
                                 mov ECX, [ESP + 12]; /* length. */
                                 rep; movs" ~ suffix ~ ";
                                 mov ESI, EDX;
                                 mov EDI, EAX;
                                 ret;
                             }"
                        );
                    }
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test(alias I, alias movs)()
            {
                I[8] memory = [I.max, I.max - 1, 2, 3, 4, 5, 6, 7];

                ((d, s) @trusted => movs(d, s, 4))(&memory[3], &memory[2]);
                assert(memory == [I.max, I.max - 1, 2, 2, 2, 2, 2, 7]);

                ((d, s) @trusted => movs(d, s, 2))(&memory[0], &memory[6]);
                assert(memory == [2, 7, 2, 2, 2, 2, 2, 7]);

                return true;
            }

            assert(test!(ubyte, __movsb));
            static assert(test!(ubyte, __movsb));
            assert(test!(ushort, __movsw));
            static assert(test!(ushort, __movsw));
            assert(test!(uint, __movsd));
            static assert(test!(uint, __movsd));

            version (X86_64)
            {
                assert(test!(ulong, __movsq));
                static assert(test!(ulong, __movsq));
            }
        }
    }

    pragma(inline, true)
    byte __noop(Args...)(lazy scope Args args) @safe pure nothrow @nogc
    {
        return 0;
    }

    @safe pure nothrow @nogc unittest
    {
        static bool test()
        {
            uint counter = 0;

            uint evaluatesWithSideEffect()
            {
                ++counter;

                return 7;
            }

            assert(__noop(evaluatesWithSideEffect()) == 0);
            assert(counter == 0);

            return true;
        }

        assert(test());
        static assert(test());
    }

    extern(C)
    pragma(inline, true)
    void __nop() @safe pure nothrow @nogc
    {
        /* Why does this exist? */

        if (__ctfe)
        {}
        else
        {
            version (LDC)
            {
                import ldc.llvmasm : __ir_pure;

                __ir_pure!(`call void asm "nop", ""()`, void)();
            }
            else version (GNU)
            {
                asm @trusted pure nothrow @nogc
                {
                    "nop";
                }
            }
            else version (InlineAsm_X86_64_Or_X86)
            {
                asm @trusted pure nothrow @nogc
                {
                    nop;
                }
            }
        }
    }

    @safe pure nothrow @nogc unittest
    {
        static bool test()
        {
            __nop();

            return true;
        }

        assert(test());
        static assert(test());
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        ushort __popcnt16(ushort value) @safe pure nothrow @nogc
        {
            return populationCount(value);
        }

        extern(C)
        pragma(inline, true)
        uint __popcnt(uint value) @safe pure nothrow @nogc
        {
            return populationCount(value);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        ulong __popcnt64(ulong value) @safe pure nothrow @nogc
        {
            return populationCount(value);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        private T populationCount(T)(T value) @safe pure nothrow @nogc
        {
            /* The MSVC intrinsics for popcnt always emit the actual popcnt instruction,
               whereas the LLVM and GCC instrinsics emit the actual instruction only when the target supports it.
               So, for LDC and GDC, to benefit from constant-folding where possible we check to see
               if the target supports popcnt before falling back to inline assembly. */

            import core.bitop : popcnt;

            if (__ctfe)
            {
                return cast(T) popcnt(value);
            }
            else
            {
                version (LDC)
                {
                    static if (__traits(targetHasFeature, "popcnt"))
                    {
                        import ldc.intrinsics : llvm_ctpop;
                        return llvm_ctpop(value);
                    }
                    else
                    {
                        import core.bitop : bsr;
                        import ldc.llvmasm : __ir_pure;

                        enum size = T.sizeof.bsr;
                        enum type = ["i8", "i16", "i32", "i64"][size];

                        return __ir_pure!(
                            `%count = call ` ~ type ~ ` asm inteldialect
                                 "popcnt $0, $1",
                                 "=r,r,~{flags}"
                                 (` ~ type ~ ` %0)
                             ret ` ~ type ~ ` %count`,
                            T
                        )(value);
                    }
                }
                else version (GNU)
                {
                    /* If we have __builtin_ia32_crc32si, the target has SSE4.2 and thus, almost certainly, popcnt. */
                    static if (__traits(compiles, () {import gcc.builtins : __builtin_ia32_crc32si;}))
                    {
                        static if (T.sizeof <= 4)
                        {
                            import gcc.builtins : __builtin_popcount;
                            return cast(T) __builtin_popcount(value);
                        }
                        else
                        {
                            import gcc.builtins : __builtin_popcountll;
                            return __builtin_popcountll(value);
                        }
                    }
                    else
                    {
                        T result;

                        asm @trusted pure nothrow @nogc
                        {
                            "popcnt %1, %0" : "=r" (result) : "rm" (value) : "cc";
                        }

                        return result;
                    }
                }
                else
                {
                    import core.bitop : _popcnt;
                    return _popcnt(value);
                }
            }
        }

        @safe pure nothrow @nogc unittest
        {
            import core.cpuid : hasPopcnt;

            if (!hasPopcnt)
            {
                return;
            }

            static bool test()
            {
                assert(__popcnt16(0b00000000_00000000) == 0);
                assert(__popcnt16(0b10000000_00000000) == 1);
                assert(__popcnt16(0b10000000_00000010) == 2);
                assert(__popcnt16(0b11111111_11111111) == 16);

                assert(__popcnt(0b00000000_00000000_00000000_00000000) == 0);
                assert(__popcnt(0b10000000_00000000_00000000_00000000) == 1);
                assert(__popcnt(0b10000000_00000000_00000000_00000010) == 2);
                assert(__popcnt(0b11111111_11111111_11111111_11111111) == 32);

                version (X86_64)
                {
                    alias popcnt = __popcnt64;
                    assert(popcnt(0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000) == 0);
                    assert(popcnt(0b10000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000) == 1);
                    assert(popcnt(0b10000000_00000000_00000000_00000000_00000000_00000000_00000000_00000010) == 2);
                    assert(popcnt(0b11111111_11111111_11111111_11111111_11111111_11111111_11111111_11111111) == 64);
                }

                return true;
            }

            assert(test());
            static assert(test());
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        ulong __rdtsc() @safe nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                return __builtin_ia32_rdtsc();
            }
            else version (D_InlineAsm_X86_64)
            {
                asm @trusted nothrow @nogc
                {
                    naked;
                    rdtsc;
                    shl RDX, 32;
                    or RAX, RDX;
                    ret;
                }
            }
            else version (D_InlineAsm_X86)
            {
                asm @trusted nothrow @nogc
                {
                    naked;
                    rdtsc;
                    ret;
                }
            }
        }

        @safe nothrow @nogc unittest
        {
            foreach (iteration; 0 .. 10_000)
            {
                ulong before = __rdtsc();
                ulong after = __rdtsc();

                if (after != before)
                {
                    return;
                }
            }

            assert(false);
        }

        extern(C)
        pragma(inline, true)
        ulong __rdtscp(scope uint* AUX) @trusted nothrow @nogc
        {
            version (LDC)
            {
                import ldc.llvmasm : __irEx;

                return __irEx!(
                    "declare {i64, i32} @llvm.x86.rdtscp()",
                    `%result = call {i64, i32} @llvm.x86.rdtscp()

                     %time = extractvalue {i64, i32} %result, 0
                     %aux = extractvalue {i64, i32} %result, 1

                     store i32 %aux, ` ~ llvmIRPtr!"i32" ~ ` %0

                     ret i64 %time`,
                     "",
                    ulong
                )(AUX);
            }
            else version (GNU)
            {
                import gcc.builtins : __builtin_ia32_rdtsc, __builtin_ia32_rdtscp;
                return __builtin_ia32_rdtscp(AUX);
            }
            else version (D_InlineAsm_X86_64)
            {
                asm @trusted nothrow @nogc
                {
                    /* RCX is AUX. */
                    naked;
                    mov R8, RCX; /* We save RCX in R8 before rdtscp clobbers ECX. */
                    rdtscp;
                    mov [R8], ECX;
                    shl RDX, 32;
                    or RAX, RDX;
                    ret;
                }
            }
            else version (D_InlineAsm_X86)
            {
                asm @trusted nothrow @nogc
                {
                    naked;
                    push EBX;
                    mov EBX, [ESP + 8]; /* AUX. */
                    rdtscp;
                    mov [EBX], ECX;
                    pop EBX;
                    ret;
                }
            }
        }

        /* This is trusted so that it's @safe without DIP1000 enabled. */
        @trusted nothrow @nogc unittest
        {
            uint aux = 0;

            foreach (iteration; 0 .. 10_000)
            {
                ulong before = __rdtscp(&aux);
                ulong after = __rdtscp(&aux);

                if (after != before)
                {
                    if (aux == 0)
                    {
                        /* Is aux not being written to? Or, is it just zero by happenstance? */
                        aux = 0xFFFFFFFF;
                        cast(void) __rdtscp(&aux);
                        assert(aux != 0xFFFFFFFF);
                    }

                    return;
                }
            }

            assert(false);
        }

        extern(C)
        pragma(inline, true)
        auto __readcr0() @safe nothrow @nogc
        {
            return readNumberedRegister!('R', "CR", 0)();
        }

        extern(C)
        pragma(inline, true)
        auto __readcr2() @safe nothrow @nogc
        {
            return readNumberedRegister!('R', "CR", 2)();
        }

        extern(C)
        pragma(inline, true)
        auto __readcr3() @safe nothrow @nogc
        {
            return readNumberedRegister!('R', "CR", 3)();
        }

        extern(C)
        pragma(inline, true)
        auto __readcr4() @safe nothrow @nogc
        {
            return readNumberedRegister!('R', "CR", 4)();
        }

        extern(C)
        pragma(inline, true)
        auto __readcr8() @safe nothrow @nogc
        {
            version (X86_64)
            {
                return readNumberedRegister!('R', "CR", 8)();
            }
            else version (X86)
            {
                /* __readcr8 is available on x86, for some reason, and this is what it does. */
                return readNumberedRegister!('R', "CR", 0, true)();
            }
        }

        /* Ideally, we'd define __readdr as a macro that instantiated a template with the register number,
           but ImportC can't explicitly instantiate templates, so this'll have to do. :\ */
        extern(C)
        pragma(inline, true)
        auto __readdr(uint DebugRegister) @safe nothrow @nogc
        {
            /* Dear optimiser, please optimise this. */
            switch (DebugRegister)
            {
                static foreach (number; 0 .. 8)
                {
                case number:
                    return readNumberedRegister!('E', "DR", number);
                }
            default:
                assert(false, "Invalid DebugRegister supplied to __readdr.");
            }
        }

        extern(C)
        pragma(inline, true)
        private auto readNumberedRegister(char x64Size, string prefix, uint number, bool lock = false)()
        @safe nothrow @nogc
        {
            enum char digit = '0' + number;

            version (LDC)
            {
                import ldc.llvmasm : __ir;

                version (X86_64)
                {
                    alias T = ulong;
                    enum type = "i64";
                }
                else version (X86)
                {
                    alias T = uint;
                    enum type = "i32";
                }

                return __ir!(
                    `%result = call ` ~ type ~ ` asm sideeffect inteldialect
                         "` ~ (lock ? "lock " : "") ~ `mov $0, ` ~ prefix ~ digit ~ `",
                         "=r"
                         ()
                     ret ` ~ type ~ ` %result`,
                    T
                )();
            }
            else version (GNU)
            {
                version (X86_64)
                {
                    ulong result;
                }
                else version (X86)
                {
                    uint result;
                }

                asm @trusted nothrow @nogc
                {
                    "" ~ (lock ? "lock " : "") ~ "mov %%" ~ prefix ~ digit ~ ", %0" : "=r" (result);
                }

                return result;
            }
            else version (D_InlineAsm_X86_64)
            {
                mixin(
                    "asm @trusted nothrow @nogc
                     {
                         naked;
                         " ~ (lock ? "lock; " : "") ~ "mov " ~ x64Size ~ "AX, " ~ prefix ~ digit ~ ";
                         ret;
                     }"
                );
            }
            else version (D_InlineAsm_X86)
            {
                mixin(
                    "asm @trusted nothrow @nogc
                     {
                         naked;
                         " ~ (lock ? "lock; " : "") ~ "mov EAX, " ~ prefix ~ digit ~ ";
                         ret;
                     }"
                );
            }
        }

        version (LDC)
        {
            version (X86_64)
            {
                pragma(LDC_intrinsic, "llvm.x86.flags.read.u64")
                private ulong readEFLAGS() @safe nothrow @nogc;
            }
            else version (X86)
            {
                pragma(LDC_intrinsic, "llvm.x86.flags.read.u32")
                private uint readEFLAGS() @safe nothrow @nogc;
            }

            extern(C)
            pragma(inline, true)
            auto __readeflags() @safe nothrow @nogc
            {
                return readEFLAGS();
            }
        }
        else
        {
            extern(C)
            pragma(inline, true)
            RegisterSized __readeflags() @safe nothrow @nogc
            {
                version (GNU)
                {
                    version (X86_64)
                    {
                        import gcc.builtins : __builtin_ia32_readeflags_u64;
                        return __builtin_ia32_readeflags_u64();
                    }
                    else version (X86)
                    {
                        import gcc.builtins : __builtin_ia32_readeflags_u32;
                        return __builtin_ia32_readeflags_u32();
                    }
                }
                else version (D_InlineAsm_X86_64)
                {
                    asm @trusted nothrow @nogc
                    {
                        naked;
                        pushfq;
                        pop RAX;
                        ret;
                    }
                }
                else version (D_InlineAsm_X86)
                {
                    asm @trusted nothrow @nogc
                    {
                        naked;
                        pushfd;
                        pop EAX;
                        ret;
                    }
                }
            }
        }

        extern(C)
        pragma(inline, true)
        long __readmsr(int register) @safe nothrow @nogc
        {
            version (LDC)
            {
                import ldc.llvmasm : __ir;

                return __ir!(
                    `%halves = call {i32, i32} asm sideeffect inteldialect "rdmsr", "={eax},={edx},{ecx}"(i32 %0)

                     %lo32 = extractvalue {i32, i32} %halves, 0
                     %hi32 = extractvalue {i32, i32} %halves, 1

                     %lo = zext i32 %lo32 to i64
                     %hi = zext i32 %hi32 to i64
                     %hi64 = shl i64 %hi, 32
                     %result = or i64 %hi64, %lo

                     ret i64 %result`,
                    long
                )(register);
            }
            else version (GNU)
            {
                uint lo;
                uint hi;

                asm @trusted nothrow @nogc
                {
                    "rdmsr" : "=a" (lo), "=d" (hi) : "c" (register);
                }

                return (ulong(hi) << 32) | lo;
            }
            else version (D_InlineAsm_X86_64)
            {
                asm @trusted nothrow @nogc
                {
                    /* ECX is register. */
                    naked;
                    rdmsr;
                    shl RDX, 32;
                    or RAX, RDX;
                    ret;
                }
            }
            else version (D_InlineAsm_X86)
            {
                asm @trusted nothrow @nogc
                {
                    naked;
                    mov ECX, [ESP + 4]; /* register. */
                    rdmsr;
                    ret;
                }
            }
        }

        extern(C)
        pragma(inline, true)
        ulong __readpmc(uint counter) @safe nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                return __builtin_ia32_rdpmc(counter);
            }
            else version (D_InlineAsm_X86_64)
            {
                asm @trusted nothrow @nogc
                {
                    /* ECX is counter. */
                    naked;
                    rdpmc;
                    shl RDX, 32;
                    or RAX, RDX;
                    ret;
                }
            }
            else version (D_InlineAsm_X86)
            {
                asm @trusted nothrow @nogc
                {
                    naked;
                    mov ECX, [ESP + 8]; /* counter. */
                    rdpmc;
                    ret;
                }
            }
        }

        extern(C)
        pragma(inline, true)
        uint __segmentlimit(uint a) @safe nothrow @nogc
        {
            version (LDC)
            {
                import ldc.llvmasm : __ir;

                return __ir!(
                    `%result = call i32 asm sideeffect inteldialect "lsl $0, $1", "=r,r,~{flags}"(i32 %0)
                     ret i32 %result`,
                    uint
                )(a);
            }
            else version (GNU)
            {
                uint result;

                asm @trusted nothrow @nogc
                {
                    "lsl %1, %0" : "=r" (result) : "rm" (a) : "cc";
                }

                return result;
            }
            else version (D_InlineAsm_X86_64)
            {
                asm @trusted nothrow @nogc
                {
                    /* ECX is a. */
                    naked;
                    lsl EAX, ECX;
                    ret;
                }
            }
            else version (D_InlineAsm_X86)
            {
                asm @trusted nothrow @nogc
                {
                    naked;
                    lsl EAX, [ESP + 4]; /* [ESP + 4] is a. */
                    ret;
                }
            }
        }

        @safe nothrow @nogc unittest
        {
            cast(void) __segmentlimit(0);
        }
    }

    version (X86_64)
    {
        extern(C)
        pragma(inline, true)
        ulong __shiftleft128(ulong LowPart, ulong HighPart, ubyte Shift) @safe pure nothrow @nogc
        {
            return funnelShiftLeft(LowPart, HighPart, Shift);
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(__shiftleft128(0x00FEED00DA00CA70, 0xCAFE00BEEF001230, 24) == 0xBEEF00123000FEED);
                assert(__shiftleft128(0x00FEED00DA00CA70, 0xCAFE00BEEF001230, 24 + 64) == 0xBEEF00123000FEED);

                return true;
            }

            assert(test);
            static assert(test);
        }

        extern(C)
        pragma(inline, true)
        ulong __shiftright128(ulong LowPart, ulong HighPart, ubyte Shift) @safe pure nothrow @nogc
        {
            return funnelShiftRight(LowPart, HighPart, Shift);
        }

        @safe pure nothrow @nogc unittest
        {
            static bool test()
            {
                assert(__shiftright128(0x00FEED00DA00CA70, 0xCAFE00BEEF001230, 24) == 0x00123000FEED00DA);
                assert(__shiftright128(0x00FEED00DA00CA70, 0xCAFE00BEEF001230, 24 + 64) == 0x00123000FEED00DA);

                return true;
            }

            assert(test);
            static assert(test);
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        private I funnelShiftLeft(I)(I low, I high, ubyte shiftCount) @safe pure nothrow @nogc
        if (__traits(isIntegral, I) && (I.sizeof == 8 || I.sizeof == 4))
        {
            enum uint operandBitWidth = I.sizeof << 3;
            enum uint shiftMask = operandBitWidth - 1;

            static I shiftViaSoftware(I low, I high, ubyte bitsToShift)
            {
                alias shift = bitsToShift;
                return (high << (shift & shiftMask)) | ((low >> 1) >>> (~shift & shiftMask));
            }

            if (__ctfe)
            {
                return shiftViaSoftware(low, high, shiftCount);
            }
            else
            {
                version (LDC)
                {
                    import ldc.intrinsics : llvm_fshl;

                    /* The fshl intrinsic will truncate the shift amount for us,
                       as per https://llvm.org/docs/LangRef.html#llvm-fshl-intrinsic. */
                    return llvm_fshl(high, low, I(shiftCount));
                }
                else version (GNU)
                {
                    return shiftViaSoftware(low, high, shiftCount);
                }
                else
                {
                    static if (I.sizeof == 8)
                    {
                        version (D_InlineAsm_X86_64)
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                /* RCX is low; RDX is high; R8B is shiftCount. */
                                naked;
                                mov RAX, RDX;
                                mov R9, RCX;
                                mov RCX, R8;
                                shld RAX, R9, CL;
                                ret;
                            }
                        }
                        else
                        {
                            return shiftViaSoftware(low, high, shiftCount);
                        }
                    }
                    else static if (I.sizeof == 4)
                    {
                        version (D_InlineAsm_X86)
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                naked;
                                mov EDX, [ESP +  4]; /* low. */
                                mov EAX, [ESP +  8]; /* high. */
                                mov ECX, [ESP + 12]; /* shiftCount. */
                                shld EAX, EDX, CL;
                                ret;
                            }
                        }
                        else
                        {
                            return shiftViaSoftware(low, high, shiftCount);
                        }
                    }
                }
            }
        }

        extern(C)
        pragma(inline, true)
        private I funnelShiftRight(I)(I low, I high, ubyte shiftCount) @safe pure nothrow @nogc
        if (__traits(isIntegral, I) && (I.sizeof == 8 || I.sizeof == 4))
        {
            enum uint operandBitWidth = I.sizeof << 3;
            enum uint shiftMask = operandBitWidth - 1;

            static I shiftViaSoftware(I low, I high, ubyte shift)
            {
                return (low >>> (shift & shiftMask)) | ((high << 1) << (~shift & shiftMask));
            }

            if (__ctfe)
            {
                return shiftViaSoftware(low, high, shiftCount);
            }
            else
            {
                version (LDC)
                {
                    import ldc.intrinsics : llvm_fshr;

                    /* The fshr intrinsic will truncate the shift amount for us,
                       as per https://llvm.org/docs/LangRef.html#llvm-fshr-intrinsic. */
                    return llvm_fshr(high, low, I(shiftCount));
                }
                else version (GNU)
                {
                    return shiftViaSoftware(low, high, shiftCount);
                }
                else
                {
                    static if (I.sizeof == 8)
                    {
                        version (D_InlineAsm_X86_64)
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                /* RCX is low; RDX is high; R8B is shiftCount. */
                                naked;
                                mov R9, RDX;
                                mov RAX, RCX;
                                mov RCX, R8;
                                shrd RAX, R9, CL;
                                ret;
                            }
                        }
                        else
                        {
                            return shiftViaSoftware(low, high, shiftCount);
                        }
                    }
                    else static if (I.sizeof == 4)
                    {
                        version (D_InlineAsm_X86)
                        {
                            asm @trusted pure nothrow @nogc
                            {
                                naked;
                                mov EDX, [ESP +  4]; /* low. */
                                mov EAX, [ESP +  8]; /* high. */
                                mov ECX, [ESP + 12]; /* shiftCount. */
                                shrd EAX, EDX, CL;
                                ret;
                            }
                        }
                        else
                        {
                            return shiftViaSoftware(low, high, shiftCount);
                        }
                    }
                }
            }
        }
    }

    version (X86_64_Or_X86)
    {
        extern(C)
        pragma(inline, true)
        void __sidt(scope void* Destination) @system nothrow @nogc
        {
            version (LDC_Or_GNU)
            {
                version (X86_64)
                {
                    alias Pointee = ubyte[10];
                }
                else version (X86)
                {
                    alias Pointee = ubyte[6];
                }
            }

            version (LDC)
            {
                import ldc.llvmasm : __ir;

                version (X86_64)
                {
                    enum type = "[10 x i8]";
                }
                else version (X86)
                {
                    enum type = "[6 x i8]";
                }

                enum ptr = llvmIRPtr!type ~ " elementtype(" ~ type ~ ")";

                __ir!(
                    `call void asm sideeffect inteldialect "sidt $0", "=*m"(` ~ ptr ~ ` %0)`,
                    void
                )(cast(Pointee*) Destination);
            }
            else version (GNU)
            {
                asm @system nothrow @nogc
                {
                    "sidt %0" : "=m" (*cast(Pointee*) Destination);
                }
            }
            else version (D_InlineAsm_X86_64)
            {
                asm @system nothrow @nogc
                {
                    /* RCX is Destination. */
                    naked;
                    sidt [RCX];
                    ret;
                }
            }
            else version (D_InlineAsm_X86)
            {
                asm @system nothrow @nogc
                {
                    naked;
                    mov EAX, [ESP + 4]; /* [ESP + 4] is Destination. */
                    sidt [EAX];
                    ret;
                }
            }
        }

        @safe nothrow @nogc unittest
        {
            version (X86_64)
            {
                alias Storage = ubyte[10];
            }
            else version (X86)
            {
                alias Storage = ubyte[6];
            }

            scope Storage destination = 0;

            ((scope ref d) @trusted => __sidt(&d[0]))(destination);

            foreach (value; destination)
            {
                if (value != 0)
                {
                    return;
                }
            }

            assert(false);
        }
    }
}
