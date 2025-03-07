/**
 * Support code for RISC-V fibers.
 *
 * Copyright: Copyright Denis Feklushkin 2025.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Denis Feklushkin
 */

#if defined(__riscv)

// For save/load a register in memory, regardless of the size of machine register bit size
#if(__riscv_xlen == 32)
    #define save sw
    #define load lw
#elif(__riscv_xlen == 64)
    #define save sd
    #define load ld
#else
    #error Unsupported integer register bit size
#endif

// Integer register size, bytes
reg_s = __riscv_xlen / 8

#if defined(__riscv_flen)

    #if(__riscv_flen == 32)
        #define fsave fsw
        #define fload flw
    #elif(__riscv_flen == 64)
        #define fsave fsd
        #define fload fld
    #elif(__riscv_flen == 128)
        #define fsave fsq
        #define fload flq
    #else
        #error Unsupported float register bit size
    #endif

    // Floating register size, bytes
    freg_s = __riscv_flen / 8
#else
    freg_s = 0 // hard float is not supported
#endif

ints_storage_size = reg_s * 12 // all callee-saved integer registers (embedded ABI isn't supported for now)
floats_storage_size = freg_s * 12 // all callee-saved float registers

/**
 * Parameters:
 * a0 - void* - pointer to a new stack
 * a1 - void* - pointer to the entry point
 *
 * Returns:
 * a0 - void* - modified new stack pointer
 */
.text
.globl fiber_initStack
.type  fiber_initStack, @function
fiber_initStack:
    // At this point assumed that memory for the stack is already allocated (but not zeroed)

    // adjust stack pointer
    addi a0, a0, -ints_storage_size

    // store entry point start address as saved ra register below stack pointer
    save a1, -reg_s(a0)

    ret

.text
.globl fiber_trampoline
.type  fiber_trampoline, @function
fiber_trampoline:
.cfi_startproc // necessary for .eh_frame
    // discard ra value - fiber_entryPoint never returns
    .cfi_undefined ra

    // non-returnable jump (i.e., a non-unwinding tail-call) to fiber_entryPoint
    tail fiber_entryPoint
.cfi_endproc

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
 * (floating registers omitted)
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
    // the stack border to avoid GC scan them in the stack frame
    addi sp, sp, reg_s /*excluded ra*/ + floats_storage_size

    // ra stored above of the current stack
    save ra, -(1 * reg_s)(sp)

#if defined(__riscv_flen)
    // Floats also stored above of the current stack.
    //
    // For the convenience of manual verification counting is shifted so
    // that in most cases register names match the offsets (except the last one).
    //
    // Shift (by ra register size) is added in addition to multiplication due
    // to the fact that the sizes of integer and float registers can differ.
    fsave fs1, -(1 * freg_s + reg_s)(sp)
    fsave fs2, -(2 * freg_s + reg_s)(sp)
    fsave fs3, -(3 * freg_s + reg_s)(sp)
    fsave fs4, -(4 * freg_s + reg_s)(sp)
    fsave fs5, -(5 * freg_s + reg_s)(sp)
    fsave fs6, -(6 * freg_s + reg_s)(sp)
    fsave fs7, -(7 * freg_s + reg_s)(sp)
    fsave fs8, -(8 * freg_s + reg_s)(sp)
    fsave fs9, -(9 * freg_s + reg_s)(sp)
    fsave fs10, -(10 * freg_s + reg_s)(sp)
    fsave fs11, -(11 * freg_s + reg_s)(sp)
    fsave fs0, -(12 * freg_s + reg_s)(sp)
#endif

    // Integer register data stored on the stack in the usual way
    save s0, (0 * reg_s)(sp)
    save s1, (1 * reg_s)(sp)
    save s2, (2 * reg_s)(sp)
    save s3, (3 * reg_s)(sp)
    save s4, (4 * reg_s)(sp)
    save s5, (5 * reg_s)(sp)
    save s6, (6 * reg_s)(sp)
    save s7, (7 * reg_s)(sp)
    save s8, (8 * reg_s)(sp)
    save s9, (9 * reg_s)(sp)
    save s10, (10 * reg_s)(sp)
    save s11, (11 * reg_s)(sp)

    // Save current sp to oldp
    save sp, (a0)

    // Load sp from newp
    addi sp, a1, 0

    // Load ra from above of the stack border
    load ra, -(1 * reg_s)(sp)

#if defined(__riscv_flen)
    // Loading floats
    fload fs1, -(1 * freg_s + reg_s)(sp)
    fload fs2, -(2 * freg_s + reg_s)(sp)
    fload fs3, -(3 * freg_s + reg_s)(sp)
    fload fs4, -(4 * freg_s + reg_s)(sp)
    fload fs5, -(5 * freg_s + reg_s)(sp)
    fload fs6, -(6 * freg_s + reg_s)(sp)
    fload fs7, -(7 * freg_s + reg_s)(sp)
    fload fs8, -(8 * freg_s + reg_s)(sp)
    fload fs9, -(9 * freg_s + reg_s)(sp)
    fload fs10, -(10 * freg_s + reg_s)(sp)
    fload fs11, -(11 * freg_s + reg_s)(sp)
    fload fs0, -(12 * freg_s + reg_s)(sp)
#endif

    // Load registers from obtained stack
    load s0, (0 * reg_s)(sp)
    load s1, (1 * reg_s)(sp)
    load s2, (2 * reg_s)(sp)
    load s3, (3 * reg_s)(sp)
    load s4, (4 * reg_s)(sp)
    load s5, (5 * reg_s)(sp)
    load s6, (6 * reg_s)(sp)
    load s7, (7 * reg_s)(sp)
    load s8, (8 * reg_s)(sp)
    load s9, (9 * reg_s)(sp)
    load s10, (10 * reg_s)(sp)
    load s11, (11 * reg_s)(sp)

    // Freeing stack
    // (Floats storage was "freed" before floats was actually stored)
    addi sp, sp, ints_storage_size

    // Return
    jr ra

#endif
