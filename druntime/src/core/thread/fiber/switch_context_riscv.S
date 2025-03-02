/**
 * Support code for RISC-V fibers.
 *
 * Copyright: Copyright Denis Feklushkin 2025.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Denis Feklushkin
 */

#if defined(__riscv)

// Integer register size, bytes
reg_s = __riscv_xlen / 8

// Floating register size, bytes
#if defined(__riscv_flen)
    freg_s = __riscv_flen / 8
#else
    freg_s = 0 // hard float is not supported
#endif

ints_storage_size = reg_s * 12 // all callee-saved integer registers
floats_storage_size = freg_s * 12 // all callee-saved float registers

/**
 * Parameters:
 * a0 - void** - ptr to old stack pointer
 * a1 - void*  - new stack pointer
 *
 * RISCV ABI registers:
 * x0       zero    : hardwired to zero
 * x1       ra      : return address
 * x2       sp      : stack pointer
 * x3       gp      : global pointer (variables are ‘relaxed’ and accessed via a relative imm offset from the gp)
 * x4       tp      : thread pointer
 * x5-x7    t0-t2   : temporary/scratch registers
 * x8       s0/fp   : callee-saved register 0 AKA frame pointer
 * x9       s1      : callee-saved register 1
 * x10-x17  a0-a7   : function arguments
 * x18-x27  s2-s11  : callee-saved registers
 * x28-x31  t3-t6   : temporary/scratch registers
 *
 * (floats registers omitted)
 */
.text
.globl fiber_switchContext
.type  fiber_switchContext, @function
fiber_switchContext:

    // Reserve space on the stack to store registers
    // Moving stack pointer so hardware stack size checker can make sure
    // that stack boundary are not violated
    addi sp, sp, -(ints_storage_size + floats_storage_size + reg_s /*additional space for ra register*/)

    // Move stack pointer back a little and store ra and floats above of
    // the stack border to avoid GC scan they in the stack frame
    addi sp, sp, reg_s /*excluded ra*/ + floats_storage_size

    // ra stored above of the current stack
    sw ra, -(1 * reg_s)(sp)

#if defined(__riscv_flen)
    // Floats also stored above of the current stack.
    //
    // For the convenience of manual verification counting is shifted so
    // that in most cases register names match the offsets (except the last one).
    //
    // Shift (by ra register size) is added in addition to multiplication due
    // to the fact that the sizes of the integer and float registers can differ.
    fsw fs1, -(1 * freg_s + reg_s)(sp)
    fsw fs2, -(2 * freg_s + reg_s)(sp)
    fsw fs3, -(3 * freg_s + reg_s)(sp)
    fsw fs4, -(4 * freg_s + reg_s)(sp)
    fsw fs5, -(5 * freg_s + reg_s)(sp)
    fsw fs6, -(6 * freg_s + reg_s)(sp)
    fsw fs7, -(7 * freg_s + reg_s)(sp)
    fsw fs8, -(8 * freg_s + reg_s)(sp)
    fsw fs9, -(9 * freg_s + reg_s)(sp)
    fsw fs10, -(10 * freg_s + reg_s)(sp)
    fsw fs11, -(11 * freg_s + reg_s)(sp)
    fsw fs0, -(12 * freg_s + reg_s)(sp)
#endif

    // Integer register data stored on the stack in the usual way
    sw s0, (0 * reg_s)(sp)
    sw s1, (1 * reg_s)(sp)
    sw s2, (2 * reg_s)(sp)
    sw s3, (3 * reg_s)(sp)
    sw s4, (4 * reg_s)(sp)
    sw s5, (5 * reg_s)(sp)
    sw s6, (6 * reg_s)(sp)
    sw s7, (7 * reg_s)(sp)
    sw s8, (8 * reg_s)(sp)
    sw s9, (9 * reg_s)(sp)
    sw s10, (10 * reg_s)(sp)
    sw s11, (11 * reg_s)(sp)

    // Save current sp to oldp
    sw sp, (a0)

    // Load sp from newp (with keep in mind about sp adjustment)
    addi sp, a1, 0;

    // Load ra from above of the stack border
    lw ra, -(1 * reg_s)(sp)

#if defined(__riscv_flen)
    // Loading floats
    flw fs1, -(1 * freg_s + reg_s)(sp)
    flw fs2, -(2 * freg_s + reg_s)(sp)
    flw fs3, -(3 * freg_s + reg_s)(sp)
    flw fs4, -(4 * freg_s + reg_s)(sp)
    flw fs5, -(5 * freg_s + reg_s)(sp)
    flw fs6, -(6 * freg_s + reg_s)(sp)
    flw fs7, -(7 * freg_s + reg_s)(sp)
    flw fs8, -(8 * freg_s + reg_s)(sp)
    flw fs9, -(9 * freg_s + reg_s)(sp)
    flw fs10, -(10 * freg_s + reg_s)(sp)
    flw fs11, -(11 * freg_s + reg_s)(sp)
    flw fs0, -(12 * freg_s + reg_s)(sp)
#endif

    // Load registers from obtained stack
    lw s0, (0 * reg_s)(sp)
    lw s1, (1 * reg_s)(sp)
    lw s2, (2 * reg_s)(sp)
    lw s3, (3 * reg_s)(sp)
    lw s4, (4 * reg_s)(sp)
    lw s5, (5 * reg_s)(sp)
    lw s6, (6 * reg_s)(sp)
    lw s7, (7 * reg_s)(sp)
    lw s8, (8 * reg_s)(sp)
    lw s9, (9 * reg_s)(sp)
    lw s10, (10 * reg_s)(sp)
    lw s11, (11 * reg_s)(sp)

    // Freeing stack
    // (Floats storage was "freed" before floats was actually stored)
    addi sp, sp, ints_storage_size

    // Return
    jr ra

#endif
