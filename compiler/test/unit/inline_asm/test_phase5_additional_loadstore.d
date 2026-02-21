module inline_asm.test_phase5_additional_loadstore;

/**
 * Integration test for AArch64 inline assembler Phase 5
 * Tests additional load/store instructions: LDP, STP, byte/halfword ops, signed loads
 */

void testLDP()
{
    version(AArch64)
    {
        asm
        {
            // Load pair with different addressing modes
            ldp x0, x1, [x2];           // Offset mode (base address)
            ldp x3, x4, [x5, 16];       // Offset mode with immediate
            ldp x6, x7, [x8, 32];       // Offset mode with larger immediate
            ldp x9, x10, [x11, -16];    // Offset mode with negative immediate

            // Pre-indexed mode (update base before load)
            ldp x12, x13, [x14, 16]!;   // Load and increment base
            ldp x15, x16, [x17, -16]!;  // Load and decrement base

            // Post-indexed mode (update base after load)
            ldp x18, x19, [x20], 16;    // Load then increment base
            ldp x21, x22, [x23], -16;   // Load then decrement base

            // 32-bit variant
            ldp w24, w25, [x26];        // Load pair of 32-bit registers
            ldp w27, w28, [x29, 8];     // Load pair with offset
        }
    }
}

void testSTP()
{
    version(AArch64)
    {
        asm
        {
            // Store pair with different addressing modes
            stp x0, x1, [x2];           // Offset mode (base address)
            stp x3, x4, [x5, 16];       // Offset mode with immediate
            stp x6, x7, [x8, 32];       // Offset mode with larger immediate
            stp x9, x10, [x11, -16];    // Offset mode with negative immediate

            // Pre-indexed mode (update base before store)
            stp x12, x13, [x14, 16]!;   // Store and increment base
            stp x15, x16, [x17, -16]!;  // Store and decrement base

            // Post-indexed mode (update base after store)
            stp x18, x19, [x20], 16;    // Store then increment base
            stp x21, x22, [x23], -16;   // Store then decrement base

            // 32-bit variant
            stp w24, w25, [x26];        // Store pair of 32-bit registers
            stp w27, w28, [x29, 8];     // Store pair with offset
        }
    }
}

void testLDRB_STRB()
{
    version(AArch64)
    {
        asm
        {
            // Load byte (unsigned, zero-extend to 32-bit)
            ldrb w0, [x1];              // Load from base address
            ldrb w2, [x3, 4];           // Load with immediate offset
            ldrb w4, [x5, 255];         // Load with maximum offset
            ldrb w6, [x7, x8];          // Load with register offset

            // Store byte
            strb w9, [x10];             // Store to base address
            strb w11, [x12, 4];         // Store with immediate offset
            strb w13, [x14, 255];       // Store with maximum offset
            strb w15, [x16, x17];       // Store with register offset
        }
    }
}

void testLDRH_STRH()
{
    version(AArch64)
    {
        asm
        {
            // Load halfword (unsigned, zero-extend to 32-bit)
            ldrh w0, [x1];              // Load from base address
            ldrh w2, [x3, 8];           // Load with immediate offset
            ldrh w4, [x5, 510];         // Load with large offset (must be multiple of 2)
            ldrh w6, [x7, x8, lsl 1];   // Load with scaled register offset

            // Store halfword
            strh w9, [x10];             // Store to base address
            strh w11, [x12, 8];         // Store with immediate offset
            strh w13, [x14, 510];       // Store with large offset
            strh w15, [x16, x17, lsl 1]; // Store with scaled register offset
        }
    }
}

void testLDRSB()
{
    version(AArch64)
    {
        asm
        {
            // Load signed byte, sign-extend to 32-bit
            ldrsb w0, [x1];             // Load to W register
            ldrsb w2, [x3, 4];          // Load with immediate offset
            ldrsb w4, [x5, 255];        // Load with maximum offset
            ldrsb w6, [x7, x8];         // Load with register offset

            // Load signed byte, sign-extend to 64-bit
            ldrsb x9, [x10];            // Load to X register
            ldrsb x11, [x12, 4];        // Load with immediate offset
            ldrsb x13, [x14, 255];      // Load with maximum offset
            ldrsb x15, [x16, x17];      // Load with register offset
        }
    }
}

void testLDRSH()
{
    version(AArch64)
    {
        asm
        {
            // Load signed halfword, sign-extend to 32-bit
            ldrsh w0, [x1];             // Load to W register
            ldrsh w2, [x3, 8];          // Load with immediate offset
            ldrsh w4, [x5, 510];        // Load with large offset
            ldrsh w6, [x7, x8, lsl 1];  // Load with scaled register offset

            // Load signed halfword, sign-extend to 64-bit
            ldrsh x9, [x10];            // Load to X register
            ldrsh x11, [x12, 8];        // Load with immediate offset
            ldrsh x13, [x14, 510];      // Load with large offset
            ldrsh x15, [x16, x17, lsl 1]; // Load with scaled register offset
        }
    }
}

void testLDRSW()
{
    version(AArch64)
    {
        asm
        {
            // Load signed word, sign-extend to 64-bit
            // (Only X register destination is valid)
            ldrsw x0, [x1];             // Load from base address
            ldrsw x2, [x3, 8];          // Load with immediate offset
            ldrsw x4, [x5, 1020];       // Load with large offset (multiple of 4)
            ldrsw x6, [x7, x8, lsl 2];  // Load with scaled register offset
        }
    }
}

void testStackOperationsWithPairs()
{
    version(AArch64)
    {
        asm
        {
            // Common stack frame setup using STP
            stp x29, x30, [sp, -16]!;   // Push frame pointer and link register
            stp x19, x20, [sp, -16]!;   // Push callee-saved registers

            // Function body would go here

            // Common stack frame teardown using LDP
            ldp x19, x20, [sp], 16;     // Pop callee-saved registers
            ldp x29, x30, [sp], 16;     // Pop frame pointer and link register
        }
    }
}

void testByteArrayOperations()
{
    version(AArch64)
    {
        asm
        {
            // Process byte array
            ldrb w0, [x1];              // Load first byte
            ldrb w2, [x1, 1];           // Load second byte
            ldrb w3, [x1, 2];           // Load third byte
            ldrb w4, [x1, 3];           // Load fourth byte

            // Store processed bytes
            strb w5, [x6];              // Store first byte
            strb w7, [x6, 1];           // Store second byte
            strb w8, [x6, 2];           // Store third byte
            strb w9, [x6, 3];           // Store fourth byte
        }
    }
}

void testHalfwordArrayOperations()
{
    version(AArch64)
    {
        asm
        {
            // Process halfword array (16-bit values)
            ldrh w0, [x1];              // Load first halfword
            ldrh w2, [x1, 2];           // Load second halfword (offset in bytes)
            ldrh w3, [x1, 4];           // Load third halfword
            ldrh w4, [x1, 6];           // Load fourth halfword

            // Store processed halfwords
            strh w5, [x6];              // Store first halfword
            strh w7, [x6, 2];           // Store second halfword
            strh w8, [x6, 4];           // Store third halfword
            strh w9, [x6, 6];           // Store fourth halfword
        }
    }
}

void testSignedDataProcessing()
{
    version(AArch64)
    {
        asm
        {
            // Load signed bytes and process
            ldrsb w0, [x1];             // Load signed byte
            ldrsb w2, [x1, 1];          // Load another signed byte
            add w3, w0, w2;             // Add (sign-extended values)

            // Load signed halfwords and process
            ldrsh w4, [x5];             // Load signed halfword
            ldrsh w6, [x5, 2];          // Load another signed halfword
            sub w7, w4, w6;             // Subtract

            // Load signed word to 64-bit and process
            ldrsw x8, [x9];             // Load signed word (32->64 bit)
            ldrsw x10, [x9, 4];         // Load another signed word
            mul x11, x8, x10;           // Multiply (64-bit operation)
        }
    }
}

void testMixedSizeAccess()
{
    version(AArch64)
    {
        asm
        {
            // Access same memory location with different sizes
            ldr x0, [x1];               // Load 64-bit (8 bytes)
            ldrb w2, [x1];              // Load first byte
            ldrh w3, [x1];              // Load first halfword (2 bytes)
            ldr w4, [x1];               // Load first word (4 bytes)
            ldrsw x5, [x1];             // Load first word, sign-extend to 64-bit
        }
    }
}

void testStructAccess()
{
    version(AArch64)
    {
        asm
        {
            // Example: struct { byte a; byte b; short c; int d; long e, f; }
            // x0 = base pointer to struct

            ldrb w1, [x0, 0];           // Load field a (byte at offset 0)
            ldrb w2, [x0, 1];           // Load field b (byte at offset 1)
            ldrsh w3, [x0, 2];          // Load field c (signed short at offset 2)
            ldr w4, [x0, 4];            // Load field d (int at offset 4)
            ldp x5, x6, [x0, 8];        // Load fields e and f (two longs at offset 8)
        }
    }
}

void testBulkDataCopy()
{
    version(AArch64)
    {
        asm
        {
            // Copy 64 bytes (8 pairs of 8-byte values) from x0 to x1
            ldp x2, x3, [x0], 16;       // Load pair and advance
            stp x2, x3, [x1], 16;       // Store pair and advance

            ldp x4, x5, [x0], 16;       // Load next pair
            stp x4, x5, [x1], 16;       // Store next pair

            ldp x6, x7, [x0], 16;       // Load third pair
            stp x6, x7, [x1], 16;       // Store third pair

            ldp x8, x9, [x0], 16;       // Load fourth pair
            stp x8, x9, [x1], 16;       // Store fourth pair
        }
    }
}

void testPackedDataOperations()
{
    version(AArch64)
    {
        asm
        {
            // Load 4 bytes individually
            ldrb w0, [x10, 0];          // Byte 0
            ldrb w1, [x10, 1];          // Byte 1
            ldrb w2, [x10, 2];          // Byte 2
            ldrb w3, [x10, 3];          // Byte 3

            // Process bytes (example: increment each)
            add w0, w0, 1;
            add w1, w1, 1;
            add w2, w2, 1;
            add w3, w3, 1;

            // Store bytes back
            strb w0, [x11, 0];          // Byte 0
            strb w1, [x11, 1];          // Byte 1
            strb w2, [x11, 2];          // Byte 2
            strb w3, [x11, 3];          // Byte 3
        }
    }
}

unittest
{
    version(AArch64)
    {
        testLDP();
        testSTP();
        testLDRB_STRB();
        testLDRH_STRH();
        testLDRSB();
        testLDRSH();
        testLDRSW();
        testStackOperationsWithPairs();
        testByteArrayOperations();
        testHalfwordArrayOperations();
        testSignedDataProcessing();
        testMixedSizeAccess();
        testStructAccess();
        testBulkDataCopy();
        testPackedDataOperations();
    }
}
