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
}
