module inline_asm.test_phase4_arithmetic;

/**
 * Integration test for AArch64 inline assembler Phase 4.1
 * Tests arithmetic instructions: MADD, MSUB, SDIV, UDIV, NEG
 */

void testMADD()
{
    version(AArch64)
    {
        asm
        {
            // Basic multiply-add: x0 = x3 + x1 * x2
            madd x0, x1, x2, x3;

            // With different registers
            madd x4, x5, x6, x7;         // x4 = x7 + x5 * x6
            madd x8, x9, x10, x11;       // x8 = x11 + x9 * x10

            // 32-bit variant
            madd w12, w13, w14, w15;     // w12 = w15 + w13 * w14
            madd w16, w17, w18, w19;     // w16 = w19 + w17 * w18

            // Using zero register (same as MUL)
            madd x20, x21, x22, xzr;     // x20 = 0 + x21 * x22
            madd w23, w24, w25, wzr;     // w23 = 0 + w24 * w25

            // Using same register multiple times
            madd x26, x26, x27, x28;     // x26 = x28 + x26 * x27
            madd x29, x1, x29, x29;      // x29 = x29 + x1 * x29
        }
    }
}

void testMSUB()
{
    version(AArch64)
    {
        asm
        {
            // Basic multiply-subtract: x0 = x3 - x1 * x2
            msub x0, x1, x2, x3;

            // With different registers
            msub x4, x5, x6, x7;         // x4 = x7 - x5 * x6
            msub x8, x9, x10, x11;       // x8 = x11 - x9 * x10

            // 32-bit variant
            msub w12, w13, w14, w15;     // w12 = w15 - w13 * w14
            msub w16, w17, w18, w19;     // w16 = w19 - w17 * w18

            // Using zero register (negate product)
            msub x20, x21, x22, xzr;     // x20 = 0 - x21 * x22
            msub w23, w24, w25, wzr;     // w23 = 0 - w24 * w25

            // Using same register multiple times
            msub x26, x26, x27, x28;     // x26 = x28 - x26 * x27
            msub x29, x1, x29, x29;      // x29 = x29 - x1 * x29
        }
    }
}

void testSDIV()
{
    version(AArch64)
    {
        asm
        {
            // Basic signed division: x0 = x1 / x2
            sdiv x0, x1, x2;

            // With different registers
            sdiv x3, x4, x5;             // x3 = x4 / x5
            sdiv x6, x7, x8;             // x6 = x7 / x8
            sdiv x9, x10, x11;           // x9 = x10 / x11

            // 32-bit variant
            sdiv w12, w13, w14;          // w12 = w13 / w14
            sdiv w15, w16, w17;          // w15 = w16 / w17
            sdiv w18, w19, w20;          // w18 = w19 / w20

            // Using same register as source and destination
            sdiv x21, x21, x22;          // x21 = x21 / x22
            sdiv x23, x24, x23;          // x23 = x24 / x23

            // All different registers
            sdiv x25, x26, x27;          // x25 = x26 / x27
            sdiv x28, x29, x30;          // x28 = x29 / x30
        }
    }
}

void testUDIV()
{
    version(AArch64)
    {
        asm
        {
            // Basic unsigned division: x0 = x1 / x2
            udiv x0, x1, x2;

            // With different registers
            udiv x3, x4, x5;             // x3 = x4 / x5
            udiv x6, x7, x8;             // x6 = x7 / x8
            udiv x9, x10, x11;           // x9 = x10 / x11

            // 32-bit variant
            udiv w12, w13, w14;          // w12 = w13 / w14
            udiv w15, w16, w17;          // w15 = w16 / w17
            udiv w18, w19, w20;          // w18 = w19 / w20

            // Using same register as source and destination
            udiv x21, x21, x22;          // x21 = x21 / x22
            udiv x23, x24, x23;          // x23 = x24 / x23

            // All different registers
            udiv x25, x26, x27;          // x25 = x26 / x27
            udiv x28, x29, x30;          // x28 = x29 / x30
        }
    }
}

void testNEG()
{
    version(AArch64)
    {
        asm
        {
            // Basic negate: x0 = 0 - x1
            neg x0, x1;

            // With different registers
            neg x2, x3;                  // x2 = -x3
            neg x4, x5;                  // x4 = -x5
            neg x6, x7;                  // x6 = -x7

            // 32-bit variant
            neg w8, w9;                  // w8 = -w9
            neg w10, w11;                // w10 = -w11
            neg w12, w13;                // w12 = -w13

            // Using same register as source and destination
            neg x14, x14;                // x14 = -x14
            neg w15, w15;                // w15 = -w15

            // With shifts
            neg x16, x17, lsl 1;         // x16 = -(x17 << 1)
            neg x18, x19, lsl 2;         // x18 = -(x19 << 2)
            neg x20, x21, lsl 3;         // x20 = -(x21 << 3)

            neg x22, x23, lsr 1;         // x22 = -(x23 >> 1)
            neg x24, x25, lsr 4;         // x24 = -(x25 >> 4)

            neg x26, x27, asr 1;         // x26 = -(x27 >>> 1)
            neg x28, x29, asr 8;         // x28 = -(x29 >>> 8)

            neg x0, x1, ror 1;           // x0 = -(x1 ROR 1)
            neg x2, x3, ror 16;          // x2 = -(x3 ROR 16)

            // 32-bit with shifts
            neg w4, w5, lsl 2;           // w4 = -(w5 << 2)
            neg w6, w7, lsr 3;           // w6 = -(w7 >> 3)
            neg w8, w9, asr 4;           // w8 = -(w9 >>> 4)
        }
    }
}

void testCombinedArithmetic()
{
    version(AArch64)
    {
        asm
        {
            // Polynomial evaluation: y = a + bx + cx^2
            // Assume: x0=a, x1=b, x2=c, x3=x
            mul x4, x3, x3;              // x4 = x^2
            madd x5, x2, x4, x0;         // x5 = a + c*x^2
            madd x6, x1, x3, x5;         // x6 = (a + c*x^2) + b*x

            // Division with remainder check
            // Assume: x7=dividend, x8=divisor
            sdiv x9, x7, x8;             // x9 = quotient
            msub x10, x9, x8, x7;        // x10 = dividend - quotient*divisor (remainder)

            // Negate and add
            neg x11, x12;                // x11 = -x12
            add x13, x11, x14;           // x13 = (-x12) + x14 = x14 - x12
        }
    }
}

void testDivisionPatterns()
{
    version(AArch64)
    {
        asm
        {
            // Divide and compute remainder
            // For: x0 = dividend, x1 = divisor
            sdiv x2, x0, x1;             // x2 = quotient (signed)
            msub x3, x2, x1, x0;         // x3 = remainder (dividend - quotient*divisor)

            // Unsigned divide and compute remainder
            udiv x4, x0, x1;             // x4 = quotient (unsigned)
            msub x5, x4, x1, x0;         // x5 = remainder

            // Check if divisible (remainder == 0)
            sdiv x6, x7, x8;             // x6 = quotient
            msub x9, x6, x8, x7;         // x9 = remainder
            cmp x9, 0;                   // Check if remainder is zero
        }
    }
}

void testMultiplyAddPatterns()
{
    version(AArch64)
    {
        asm
        {
            // Dot product accumulation: result += a[i] * b[i]
            ldr x0, [x10];               // Load a[i]
            ldr x1, [x11];               // Load b[i]
            madd x2, x0, x1, x2;         // x2 += x0 * x1

            // Matrix multiply-accumulate pattern
            ldr x3, [x12];               // Load matrix element
            ldr x4, [x13];               // Load vector element
            madd x5, x3, x4, x5;         // Accumulate: x5 += x3 * x4

            // Polynomial term accumulation
            ldr x6, [x14];               // Load coefficient
            madd x7, x6, x8, x7;         // x7 += coefficient * power
        }
    }
}

void testNegatePatterns()
{
    version(AArch64)
    {
        asm
        {
            // Two's complement
            neg x0, x1;                  // x0 = -x1

            // Negate shifted value (useful for bit manipulation)
            neg x2, x3, lsl 1;           // x2 = -(x3 * 2)
            neg x4, x5, lsl 2;           // x4 = -(x5 * 4)
            neg x6, x7, lsl 3;           // x6 = -(x7 * 8)

            // Sign extension and negate
            neg w8, w9;                  // w8 = -w9 (32-bit)
            sxtw x10, w8;                // Sign-extend to 64-bit

            // Absolute value computation (requires conditional)
            cmp x11, 0;                  // Check sign
            neg x12, x11;                // x12 = -x11
            // Would use CSEL to select between x11 and x12
        }
    }
}

void testEdgeCases()
{
    version(AArch64)
    {
        asm
        {
            // MADD/MSUB with all same registers (pathological but legal)
            madd x0, x0, x0, x0;         // x0 = x0 + x0 * x0
            msub x1, x1, x1, x1;         // x1 = x1 - x1 * x1

            // Division by same register (result = 1 if x2 != 0)
            sdiv x2, x2, x2;             // x2 = x2 / x2
            udiv x3, x3, x3;             // x3 = x3 / x3

            // Negate twice (should give original value)
            neg x4, x5;                  // x4 = -x5
            neg x6, x4;                  // x6 = -(-x5) = x5

            // Large shifts on negate
            neg x7, x8, lsl 31;          // x7 = -(x8 << 31) for 32-bit
            neg x9, x10, lsl 63;         // x9 = -(x10 << 63) for 64-bit
            neg x11, x12, asr 31;        // x11 = -(x12 >>> 31)
        }
    }
}

void testMixedSizeOperations()
{
    version(AArch64)
    {
        asm
        {
            // 32-bit operations
            madd w0, w1, w2, w3;
            msub w4, w5, w6, w7;
            sdiv w8, w9, w10;
            udiv w11, w12, w13;
            neg w14, w15;

            // 64-bit operations
            madd x16, x17, x18, x19;
            msub x20, x21, x22, x23;
            sdiv x24, x25, x26;
            udiv x27, x28, x29;
            neg x0, x1;

            // Mixed operations (separate instructions)
            madd w2, w3, w4, w5;
            madd x6, x7, x8, x9;

            sdiv w10, w11, w12;
            sdiv x13, x14, x15;
        }
    }
}

unittest
{
    version(AArch64)
    {
        testMADD();
        testMSUB();
        testSDIV();
        testUDIV();
        testNEG();
        testCombinedArithmetic();
        testDivisionPatterns();
        testMultiplyAddPatterns();
        testNegatePatterns();
        testEdgeCases();
        testMixedSizeOperations();
    }
}
