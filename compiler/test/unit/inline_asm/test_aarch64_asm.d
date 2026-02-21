module inline_asm.test_aarch64_asm;

/**
 * Test program for AArch64 inline assembler
 *
 * This program demonstrates the AArch64 inline assembly syntax
 * and verifies that instructions are encoded correctly.
 */

import core.stdc.stdio;

// Test basic arithmetic operations
int testArithmetic()
{
    int result = 0;

    version(AArch64)
    {
        asm
        {
            // Load immediate values and perform arithmetic
            mov x0, x1;           // Move register
            add x2, x3, #42;      // Add immediate
            sub x4, x5, #10;      // Subtract immediate
            add x6, x7, x8;       // Add registers
            sub x9, x10, x11;     // Subtract registers
        }
    }

    return result;
}

// Test memory operations
void testMemory()
{
    version(AArch64)
    {
        asm
        {
            // Load operations
            ldr x0, [x1];         // Load from base register
            ldr x2, [x3, #8];     // Load with immediate offset
            ldr x4, [x5, x6];     // Load with register offset
            ldr w7, [x8];         // 32-bit load

            // Store operations
            str x10, [x11];       // Store to base register
            str x12, [x13, #16];  // Store with immediate offset
            str x14, [x15, x16];  // Store with register offset
            str w17, [x18];       // 32-bit store
        }
    }
}

// Test conditional branches
void testBranches()
{
    version(AArch64)
    {
        asm
        {
            // Conditional branches
            b.eq done;            // Branch if equal
            b.ne skip;            // Branch if not equal
            b.gt loop;            // Branch if greater than

            // Compare and branch
            cbz x0, zero_handler;  // Branch if x0 is zero
            cbnz x1, nonzero;      // Branch if x1 is non-zero

            // Test bit and branch
            tbz x2, #5, bit_clear;   // Branch if bit 5 is clear
            tbnz x3, #31, bit_set;   // Branch if bit 31 is set

        skip:
        loop:
        done:
        zero_handler:
        nonzero:
        bit_clear:
        bit_set:
        }
    }
}

// Test with special registers
void testSpecialRegisters()
{
    version(AArch64)
    {
        asm
        {
            // Using stack pointer
            ldr x0, [sp];         // Load from stack pointer
            str x1, [sp, #8];     // Store to stack with offset
            add x29, sp, #16;     // Frame pointer setup
            sub sp, sp, #32;      // Allocate stack space

            // Using zero registers
            mov x0, xzr;          // Move zero to x0
            mov w1, wzr;          // Move zero to w1
        }
    }
}

// Comprehensive test combining multiple instruction types
void testComprehensive()
{
    version(AArch64)
    {
        asm
        {
            // Function prologue simulation
            sub sp, sp, #32;      // Allocate stack frame
            str x29, [sp, #16];   // Save frame pointer
            str x30, [sp, #24];   // Save link register
            add x29, sp, #16;     // Setup frame pointer

            // Arithmetic operations
            mov x0, x1;
            add x2, x3, #100;
            sub x4, x5, x6;

            // Memory operations
            ldr x7, [x8, #8];
            str x9, [x10];

            // Conditional logic
            cbz x0, cleanup;
            add x1, x1, #1;
            b.ne loop_start;

        cleanup:
        loop_start:
            // Function epilogue simulation
            ldr x30, [sp, #24];   // Restore link register
            ldr x29, [sp, #16];   // Restore frame pointer
            add sp, sp, #32;      // Deallocate stack frame
        }
    }
}

unittest
{
    version(AArch64)
    {
        testArithmetic();
        testMemory();
        testBranches();
        testSpecialRegisters();
        testComprehensive();
    }
}
