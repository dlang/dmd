module inline_asm.test_phase2_addressing;

/**
 * Integration test for AArch64 inline assembler Phase 2
 * Tests extended addressing modes: pre-indexed, post-indexed, and scaled register offsets
 */

void testPreIndexed()
{
    version(AArch64)
    {
        asm
        {
            // Pre-indexed mode: [Xn, #imm]!
            // These should update the base register
            ldr x0, [x1, 8]!;      // Load and increment x1 by 8
            ldr w2, [x3, 4]!;      // Load and increment x3 by 4
            str x4, [x5, 16]!;     // Store and increment x5 by 16
            str w6, [x7, -8]!;     // Store and decrement x7 by 8

            // With sp as base register
            ldr x8, [sp, 32]!;     // Load and increment sp by 32
            str x9, [sp, -16]!;    // Store and decrement sp by 16
        }
    }
}

void testPostIndexed()
{
    version(AArch64)
    {
        asm
        {
            // Post-indexed mode: [Xn], #imm
            // These should use current value then update the base register
            ldr x0, [x1], 8;       // Load from x1, then increment x1 by 8
            ldr w2, [x3], 4;       // Load from x3, then increment x3 by 4
            str x4, [x5], 16;      // Store to x5, then increment x5 by 16
            str w6, [x7], -8;      // Store to x7, then decrement x7 by 8

            // With sp as base register
            ldr x8, [sp], 32;      // Load from sp, then increment sp by 32
            str x9, [sp], -16;     // Store to sp, then decrement sp by 16
        }
    }
}

void testExtendedRegisterOffset()
{
    version(AArch64)
    {
        asm
        {
            // Register offset with LSL (logical shift left)
            ldr x0, [x1, x2, lsl 3];     // Load from x1 + (x2 << 3)
            str x3, [x4, x5, lsl 3];     // Store to x4 + (x5 << 3)
            ldr w6, [x7, x8, lsl 2];     // Load word from x7 + (x8 << 2)
            str w9, [x10, x11, lsl 2];   // Store word to x10 + (x11 << 2)

            // Register offset with UXTW (zero-extend 32-bit)
            ldr x12, [x13, x14, uxtw 3]; // Load from x13 + zero_extend(w14) << 3
            str x15, [x16, x17, uxtw 3]; // Store to x16 + zero_extend(w17) << 3

            // Register offset with SXTW (sign-extend 32-bit)
            ldr x18, [x19, x20, sxtw 3]; // Load from x19 + sign_extend(w20) << 3
            str x21, [x22, x23, sxtw 3]; // Store to x22 + sign_extend(w23) << 3

            // Register offset with SXTX (sign-extend 64-bit, rarely used)
            ldr x24, [x25, x26, sxtx 0]; // Load from x25 + sign_extend(x26)
            str x27, [x28, x29, sxtx 0]; // Store to x28 + sign_extend(x29)
        }
    }
}

void testCombinedPatterns()
{
    version(AArch64)
    {
        asm
        {
            // Common pattern: array traversal with pre-increment
            ldr x0, [x1, 8]!;
            ldr x2, [x1, 8]!;
            ldr x3, [x1, 8]!;

            // Common pattern: array traversal with post-increment
            str x4, [x5], 8;
            str x6, [x5], 8;
            str x7, [x5], 8;

            // Common pattern: indexed array access
            ldr x8, [x9, x10, lsl 3];    // x9[x10] for 8-byte elements
            ldr w11, [x12, x13, lsl 2];  // x12[x13] for 4-byte elements

            // Stack frame setup/teardown patterns
            str x29, [sp, -16]!;         // Push frame pointer (pre-decrement)
            ldr x29, [sp], 16;           // Pop frame pointer (post-increment)
        }
    }
}

void testMixedSizesAndModes()
{
    version(AArch64)
    {
        asm
        {
            // 64-bit operations
            ldr x0, [x1, 8]!;
            str x2, [x3], 16;
            ldr x4, [x5, x6, lsl 3];

            // 32-bit operations
            ldr w7, [x8, 4]!;
            str w9, [x10], 8;
            ldr w11, [x12, x13, lsl 2];

            // Negative offsets
            ldr x14, [x15, -8]!;
            str x16, [x17], -16;

            // Zero offsets (edge case)
            ldr x18, [x19, 0]!;
            str x20, [x21], 0;
        }
    }
}

void testStackOperations()
{
    version(AArch64)
    {
        asm
        {
            // Common stack operations using sp
            str x0, [sp, -16]!;    // Push x0 onto stack
            str x1, [sp, -16]!;    // Push x1 onto stack
            ldr x1, [sp], 16;      // Pop into x1
            ldr x0, [sp], 16;      // Pop into x0

            // Frame pointer operations
            str x29, [sp, -32]!;   // Save frame pointer with space
            ldr x29, [sp], 32;     // Restore frame pointer

            // Access stack variables with offset
            ldr x2, [sp, 16]!;     // Load from stack and adjust
            str x3, [sp], 8;       // Store to stack and adjust
        }
    }
}

unittest
{
    version(AArch64)
    {
        testPreIndexed();
        testPostIndexed();
        testExtendedRegisterOffset();
        testCombinedPatterns();
        testMixedSizesAndModes();
        testStackOperations();
    }
}
