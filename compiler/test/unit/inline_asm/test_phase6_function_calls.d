module inline_asm.test_phase6_function_calls;

/**
 * Integration test for AArch64 inline assembler Phase 6
 * Tests function call instructions: BL, BLR, BR, RET
 */

void testBL()
{
    version(AArch64)
    {
        asm
        {
            // Branch with link (function call with immediate offset)
            bl func1;    // Call function at label
            bl func2;    // Call another function
        }
    }
}

void testBLR()
{
    version(AArch64)
    {
        asm
        {
            // Branch with link to register (indirect function call)
            blr x0;      // Call function at address in x0
            blr x1;      // Call function at address in x1
            blr x15;     // Call function at address in x15
            blr x30;     // Call function at address in x30 (unusual but valid)
        }
    }
}

void testBR()
{
    version(AArch64)
    {
        asm
        {
            // Branch to register (tail call / indirect jump)
            br x0;       // Jump to address in x0
            br x1;       // Jump to address in x1
            br x15;      // Jump to address in x15
            br x30;      // Jump to address in x30
        }
    }
}

void testRET()
{
    version(AArch64)
    {
        asm
        {
            // Return from subroutine
            ret;         // Return using x30 (default link register)
            ret x30;     // Explicit return using x30
            ret x0;      // Return using x0 (unusual but valid)
            ret x15;     // Return using x15
        }
    }
}

void testFunctionPrologue()
{
    version(AArch64)
    {
        asm
        {
            // Standard function prologue
            str x29, [sp, -16]!;    // Save frame pointer (pre-decrement)
            str x30, [sp, -16]!;    // Save link register (pre-decrement)
            mov x29, sp;            // Set up frame pointer

            // Function body would go here

            // Standard function epilogue
            ldr x30, [sp], 16;      // Restore link register (post-increment)
            ldr x29, [sp], 16;      // Restore frame pointer (post-increment)
            ret;                     // Return
        }
    }
}

void testFunctionCallSequence()
{
    version(AArch64)
    {
        asm
        {
            // Prepare arguments
            mov x0, x1;              // First argument
            mov x1, x2;              // Second argument
            mov x2, x3;              // Third argument

            // Call function
            bl someFunction;         // Branch with link

            // Use return value (in x0)
            mov x4, x0;              // Save return value
        }
    }
}

void testIndirectCall()
{
    version(AArch64)
    {
        asm
        {
            // Load function pointer
            ldr x9, [x10];           // Load function address

            // Prepare arguments
            mov x0, x1;              // First argument

            // Make indirect call
            blr x9;                  // Branch with link to register

            // Process return value
            mov x2, x0;              // Use return value
        }
    }
}

void testTailCall()
{
    version(AArch64)
    {
        asm
        {
            // Restore stack (if needed)
            ldr x29, [sp], 16;       // Restore frame pointer

            // Prepare arguments for tail-called function
            mov x0, x1;              // Forward argument

            // Tail call (jump without link)
            br x2;                   // Jump to function in x2
        }
    }
}

void testNestedFunctionCalls()
{
    version(AArch64)
    {
        asm
        {
            // Function A prologue
            str x30, [sp, -16]!;     // Save return address

            // Call function B
            bl funcB;

            // Use result from B
            mov x1, x0;

            // Call function C
            bl funcC;

            // Epilogue
            ldr x30, [sp], 16;       // Restore return address
            ret;                      // Return to caller
        }
    }
}

void testFunctionPointerTable()
{
    version(AArch64)
    {
        asm
        {
            // Load base address of function pointer table
            ldr x9, [x10];           // Base address

            // Calculate offset (index * 8)
            ldr x11, [x9, x12, lsl 3]; // Load function pointer

            // Prepare arguments
            mov x0, x1;

            // Call via pointer
            blr x11;                 // Indirect call

            // Continue with result
            mov x2, x0;
        }
    }
}

void testConditionalReturn()
{
    version(AArch64)
    {
        asm
        {
            // Compare
            cmp x0, 0;

            // Conditional return
            b.eq earlyReturn;

            // Normal processing
            add x0, x0, 1;

        earlyReturn:
            ret;                     // Return
        }
    }
}

void testLeafFunction()
{
    version(AArch64)
    {
        asm
        {
            // Leaf function (no function calls, no stack frame)
            add x0, x0, 1;           // Do some work
            mul x0, x0, x1;          // More work
            ret;                      // Return (x30 not modified)
        }
    }
}

void testNonLeafFunction()
{
    version(AArch64)
    {
        asm
        {
            // Non-leaf function (makes calls, needs to save x30)
            str x30, [sp, -16]!;     // Save link register

            // Make a call
            bl helper;                // This overwrites x30

            // Process result
            add x0, x0, 1;

            // Return
            ldr x30, [sp], 16;       // Restore link register
            ret;                      // Return to original caller
        }
    }
}

unittest
{
    version(AArch64)
    {
        testBL();
        testBLR();
        testBR();
        testRET();
        testFunctionPrologue();
        testFunctionCallSequence();
        testIndirectCall();
        testTailCall();
        testNestedFunctionCalls();
        testFunctionPointerTable();
        testConditionalReturn();
        testLeafFunction();
        testNonLeafFunction();
    }
}
