module inline_asm.test_phase4_logical;

/**
 * Integration test for AArch64 inline assembler Phase 4.2
 * Tests logical instructions: BIC, TST
 */

void testBIC()
{
    version(AArch64)
    {
        asm
        {
            // Basic bit clear: x0 = x1 & ~x2
            bic x0, x1, x2;

            // With different registers
            bic x3, x4, x5;             // x3 = x4 & ~x5
            bic x6, x7, x8;             // x6 = x7 & ~x8
            bic x9, x10, x11;           // x9 = x10 & ~x11

            // 32-bit variant
            bic w12, w13, w14;          // w12 = w13 & ~w14
            bic w15, w16, w17;          // w15 = w16 & ~w17
            bic w18, w19, w20;          // w18 = w19 & ~w20

            // Using same register as source and destination
            bic x21, x21, x22;          // x21 = x21 & ~x22
            bic x23, x24, x23;          // x23 = x24 & ~x23

            // All different registers
            bic x25, x26, x27;          // x25 = x26 & ~x27
            bic x28, x29, x30;          // x28 = x29 & ~x30
        }
    }
}

void testBICWithShift()
{
    version(AArch64)
    {
        asm
        {
            // BIC with LSL (logical shift left)
            bic x0, x1, x2, lsl 1;      // x0 = x1 & ~(x2 << 1)
            bic x3, x4, x5, lsl 2;      // x3 = x4 & ~(x5 << 2)
            bic x6, x7, x8, lsl 3;      // x6 = x7 & ~(x8 << 3)
            bic x9, x10, x11, lsl 16;   // x9 = x10 & ~(x11 << 16)

            // BIC with LSR (logical shift right)
            bic x12, x13, x14, lsr 1;   // x12 = x13 & ~(x14 >> 1)
            bic x15, x16, x17, lsr 4;   // x15 = x16 & ~(x17 >> 4)
            bic x18, x19, x20, lsr 32;  // x18 = x19 & ~(x20 >> 32)

            // BIC with ASR (arithmetic shift right)
            bic x21, x22, x23, asr 1;   // x21 = x22 & ~(x23 >>> 1)
            bic x24, x25, x26, asr 8;   // x24 = x25 & ~(x26 >>> 8)
            bic x27, x28, x29, asr 31;  // x27 = x28 & ~(x29 >>> 31)

            // BIC with ROR (rotate right)
            bic x0, x1, x2, ror 1;      // x0 = x1 & ~(x2 ROR 1)
            bic x3, x4, x5, ror 8;      // x3 = x4 & ~(x5 ROR 8)
            bic x6, x7, x8, ror 16;     // x6 = x7 & ~(x8 ROR 16)

            // 32-bit with shifts
            bic w9, w10, w11, lsl 2;    // w9 = w10 & ~(w11 << 2)
            bic w12, w13, w14, lsr 3;   // w12 = w13 & ~(w14 >> 3)
            bic w15, w16, w17, asr 4;   // w15 = w16 & ~(w17 >>> 4)
        }
    }
}

void testTST()
{
    version(AArch64)
    {
        asm
        {
            // Basic test: flags = x1 & x2
            tst x1, x2;

            // With different registers
            tst x3, x4;                 // flags = x3 & x4
            tst x5, x6;                 // flags = x5 & x6
            tst x7, x8;                 // flags = x7 & x8

            // 32-bit variant
            tst w9, w10;                // flags = w9 & w10
            tst w11, w12;               // flags = w11 & w12
            tst w13, w14;               // flags = w13 & w14

            // Test same register against itself
            tst x15, x15;               // flags = x15 & x15
            tst w16, w16;               // flags = w16 & w16

            // Test with various registers
            tst x17, x18;               // flags = x17 & x18
            tst x19, x20;               // flags = x19 & x20
            tst x21, x22;               // flags = x21 & x22
        }
    }
}

void testTSTWithShift()
{
    version(AArch64)
    {
        asm
        {
            // TST with LSL (logical shift left)
            tst x1, x2, lsl 1;          // flags = x1 & (x2 << 1)
            tst x3, x4, lsl 2;          // flags = x3 & (x4 << 2)
            tst x5, x6, lsl 3;          // flags = x5 & (x6 << 3)
            tst x7, x8, lsl 16;         // flags = x7 & (x8 << 16)

            // TST with LSR (logical shift right)
            tst x9, x10, lsr 1;         // flags = x9 & (x10 >> 1)
            tst x11, x12, lsr 4;        // flags = x11 & (x12 >> 4)
            tst x13, x14, lsr 32;       // flags = x13 & (x14 >> 32)

            // TST with ASR (arithmetic shift right)
            tst x15, x16, asr 1;        // flags = x15 & (x16 >>> 1)
            tst x17, x18, asr 8;        // flags = x17 & (x18 >>> 8)
            tst x19, x20, asr 31;       // flags = x19 & (x20 >>> 31)

            // TST with ROR (rotate right)
            tst x21, x22, ror 1;        // flags = x21 & (x22 ROR 1)
            tst x23, x24, ror 8;        // flags = x23 & (x24 ROR 8)
            tst x25, x26, ror 16;       // flags = x25 & (x26 ROR 16)

            // 32-bit with shifts
            tst w27, w28, lsl 2;        // flags = w27 & (w28 << 2)
            tst w29, w0, lsr 3;         // flags = w29 & (w0 >> 3)
            tst w1, w2, asr 4;          // flags = w1 & (w2 >>> 4)
        }
    }
}

void testMaskOperations()
{
    version(AArch64)
    {
        asm
        {
            // Clear specific bits using BIC
            // Example: clear lower 8 bits
            mov x1, 0xFF;               // Mask for lower 8 bits
            bic x0, x0, x1;             // x0 = x0 & ~0xFF

            // Clear bits 16-23
            mov x2, 0xFF0000;           // Mask for bits 16-23
            bic x3, x3, x2;             // x3 = x3 & ~(mask)

            // Clear high bits using shift
            mov x4, 0xFFFF;
            bic x5, x5, x4, lsl 32;     // Clear high 16 bits

            // Test if specific bits are set
            mov x6, 0x8000;             // Bit 15
            tst x7, x6;                 // Test if bit 15 is set
            // Branch based on flags set by TST
        }
    }
}

void testBitFieldOperations()
{
    version(AArch64)
    {
        asm
        {
            // Extract and clear bit fields
            // Clear bits [7:0]
            mov x1, 0xFF;
            bic x0, x0, x1;

            // Clear bits [15:8]
            mov x2, 0xFF;
            bic x3, x3, x2, lsl 8;

            // Clear bits [23:16]
            mov x4, 0xFF;
            bic x5, x5, x4, lsl 16;

            // Test bit patterns
            mov x6, 0x5555;             // Alternating bits
            tst x7, x6;                 // Test pattern

            mov x8, 0xAAAA;             // Opposite pattern
            tst x9, x8;                 // Test opposite pattern
        }
    }
}

void testConditionalWithTST()
{
    version(AArch64)
    {
        asm
        {
            // Test bit and branch conditionally
            mov x1, 1;                  // Bit 0 mask
            tst x0, x1;                 // Test bit 0
            b.eq bitClear;              // Branch if bit clear (Z flag set)

            // Bit was set
            add x2, x2, 1;
            b done;

        bitClear:
            // Bit was clear
            sub x2, x2, 1;

        done:
            nop;
        }
    }
}

void testTSTWithMasks()
{
    version(AArch64)
    {
        asm
        {
            // Test for zero
            tst x0, x0;                 // Test if x0 == 0

            // Test specific bit
            mov x1, 1;
            tst x2, x1, lsl 7;          // Test bit 7 of x2

            // Test multiple bits
            mov x3, 0x7;                // Bits 0, 1, 2
            tst x4, x3;                 // Test if any of bits 0-2 are set

            // Test high bits
            mov x5, 1;
            tst x6, x5, lsl 63;         // Test sign bit (bit 63)

            // Test 32-bit sign
            mov w7, 1;
            tst w8, w7, lsl 31;         // Test sign bit (bit 31) of 32-bit value
        }
    }
}

void testBICPatterns()
{
    version(AArch64)
    {
        asm
        {
            // Clear flags pattern
            mov x1, 0x3;                // Bits 0 and 1
            bic x0, x0, x1;             // Clear flags

            // Clear status bits
            mov x2, 0xF0;               // Bits 4-7
            bic x3, x3, x2;             // Clear status

            // Mask off unwanted bits
            mov x4, 0xFFFF;
            bic x5, x5, x4, lsl 48;     // Keep only lower 48 bits

            // Clear error bits
            mov x6, 0xFF00;
            bic x7, x7, x6;             // Clear error field

            // Clear multiple fields
            mov x8, 0xFF;
            bic x9, x9, x8;             // Clear field 1
            bic x9, x9, x8, lsl 8;      // Clear field 2
            bic x9, x9, x8, lsl 16;     // Clear field 3
        }
    }
}

void testCombinedOperations()
{
    version(AArch64)
    {
        asm
        {
            // Load value
            ldr x0, [x10];

            // Test if certain bits are set
            mov x1, 0x100;              // Bit 8
            tst x0, x1;
            b.eq skipClear;

            // Clear those bits if they were set
            bic x0, x0, x1;

        skipClear:
            // Store result
            str x0, [x10];

            // Another pattern: test and clear
            ldr x2, [x11];
            mov x3, 0xFF;
            tst x2, x3;                 // Test lower byte
            bic x2, x2, x3;             // Clear lower byte
            str x2, [x11];
        }
    }
}

void testEdgeCases()
{
    version(AArch64)
    {
        asm
        {
            // BIC with same source and destination
            bic x0, x0, x1;             // x0 = x0 & ~x1

            // BIC with all same registers
            bic x2, x2, x2;             // x2 = x2 & ~x2 = 0

            // TST with same registers
            tst x3, x3;                 // Test register against itself

            // BIC with maximum shift
            bic x4, x5, x6, lsl 63;     // x4 = x5 & ~(x6 << 63)
            bic w7, w8, w9, lsl 31;     // w7 = w8 & ~(w9 << 31)

            // TST with maximum shift
            tst x10, x11, lsl 63;       // Test with max shift
            tst w12, w13, lsl 31;       // Test 32-bit with max shift

            // BIC/TST with zero shift (same as no shift)
            bic x14, x15, x16, lsl 0;
            tst x17, x18, lsr 0;
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
            bic w0, w1, w2;
            tst w3, w4;
            bic w5, w6, w7, lsl 8;
            tst w8, w9, lsr 4;

            // 64-bit operations
            bic x10, x11, x12;
            tst x13, x14;
            bic x15, x16, x17, asr 16;
            tst x18, x19, ror 8;

            // Mixed in same function (but separate instructions)
            bic w20, w21, w22;
            bic x23, x24, x25;
            tst w26, w27;
            tst x28, x29;
        }
    }
}

unittest
{
    version(AArch64)
    {
        testBIC();
        testBICWithShift();
        testTST();
        testTSTWithShift();
        testMaskOperations();
        testBitFieldOperations();
        testConditionalWithTST();
        testTSTWithMasks();
        testBICPatterns();
        testCombinedOperations();
        testEdgeCases();
        testMixedSizeOperations();
    }
}
