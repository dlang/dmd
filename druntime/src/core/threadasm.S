/**
 * Support code for mutithreading.
 *
 * Copyright: Copyright Mikola Lysenko 2005 - 2012.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Mikola Lysenko, Martin Nowak, Kai Nacke
 */

/*
 *          Copyright Mikola Lysenko 2005 - 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

#if (__linux__ || __FreeBSD__ || __NetBSD__ || __OpenBSD__ || __DragonFly__) && __ELF__
/*
 * Mark the resulting object file as not requiring execution permissions on
 * stack memory. The absence of this section would mark the whole resulting
 * library as requiring an executable stack, making it impossible to
 * dynamically load druntime on several Linux platforms where this is
 * forbidden due to security policies.
 */
.section .note.GNU-stack,"",%progbits
#endif

/************************************************************************************
 * POWER PC ASM BITS
 ************************************************************************************/
#if defined( __PPC64__ )

/* TODO: Implement fiber_switchContext. */

#elif defined( __ppc__ ) || defined( __PPC__ ) || defined( __powerpc__ )


/**
 * Performs a context switch.
 *
 * r3 - old context pointer
 * r4 - new context pointer
 *
 */
.text
.align 2
.globl _fiber_switchContext
_fiber_switchContext:

    /* Save linkage area */
    mflr        0
    mfcr        5
    stw     0, 8(1)
    stw     5, 4(1)

    /* Save GPRs */
    stw     11, (-1 * 4)(1)
    stw     13, (-2 * 4)(1)
    stw     14, (-3 * 4)(1)
    stw     15, (-4 * 4)(1)
    stw     16, (-5 * 4)(1)
    stw     17, (-6 * 4)(1)
    stw     18, (-7 * 4)(1)
    stw     19, (-8 * 4)(1)
    stw     20, (-9 * 4)(1)
    stw     21, (-10 * 4)(1)
    stw     22, (-11 * 4)(1)
    stw     23, (-12 * 4)(1)
    stw     24, (-13 * 4)(1)
    stw     25, (-14 * 4)(1)
    stw     26, (-15 * 4)(1)
    stw     27, (-16 * 4)(1)
    stw     28, (-17 * 4)(1)
    stw     29, (-18 * 4)(1)
    stw     30, (-19 * 4)(1)
    stwu    31, (-20 * 4)(1)

    /* We update the stack pointer here, since we do not want the GC to
       scan the floating point registers. */

    /* Save FPRs */
    stfd    14, (-1 * 8)(1)
    stfd    15, (-2 * 8)(1)
    stfd    16, (-3 * 8)(1)
    stfd    17, (-4 * 8)(1)
    stfd    18, (-5 * 8)(1)
    stfd    19, (-6 * 8)(1)
    stfd    20, (-7 * 8)(1)
    stfd    21, (-8 * 8)(1)
    stfd    22, (-9 * 8)(1)
    stfd    23, (-10 * 8)(1)
    stfd    24, (-11 * 8)(1)
    stfd    25, (-12 * 8)(1)
    stfd    26, (-13 * 8)(1)
    stfd    27, (-14 * 8)(1)
    stfd    28, (-15 * 8)(1)
    stfd    29, (-16 * 8)(1)
    stfd    30, (-17 * 8)(1)
    stfd    31, (-18 * 8)(1)

    /* Update the old stack pointer */
    stw     1, 0(3)

    /* Set new stack pointer */
    addi        1, 4, 20 * 4

    /* Restore linkage area */
    lwz     0, 8(1)
    lwz     5, 4(1)

    /* Restore GPRs */
    lwz     11, (-1 * 4)(1)
    lwz     13, (-2 * 4)(1)
    lwz     14, (-3 * 4)(1)
    lwz     15, (-4 * 4)(1)
    lwz     16, (-5 * 4)(1)
    lwz     17, (-6 * 4)(1)
    lwz     18, (-7 * 4)(1)
    lwz     19, (-8 * 4)(1)
    lwz     20, (-9 * 4)(1)
    lwz     21, (-10 * 4)(1)
    lwz     22, (-11 * 4)(1)
    lwz     23, (-12 * 4)(1)
    lwz     24, (-13 * 4)(1)
    lwz     25, (-14 * 4)(1)
    lwz     26, (-15 * 4)(1)
    lwz     27, (-16 * 4)(1)
    lwz     28, (-17 * 4)(1)
    lwz     29, (-18 * 4)(1)
    lwz     30, (-19 * 4)(1)
    lwz     31, (-20 * 4)(1)


    /* Restore FPRs */
    lfd     14, (-1 * 8)(4)
    lfd     15, (-2 * 8)(4)
    lfd     16, (-3 * 8)(4)
    lfd     17, (-4 * 8)(4)
    lfd     18, (-5 * 8)(4)
    lfd     19, (-6 * 8)(4)
    lfd     20, (-7 * 8)(4)
    lfd     21, (-8 * 8)(4)
    lfd     22, (-9 * 8)(4)
    lfd     23, (-10 * 8)(4)
    lfd     24, (-11 * 8)(4)
    lfd     25, (-12 * 8)(4)
    lfd     26, (-13 * 8)(4)
    lfd     27, (-14 * 8)(4)
    lfd     28, (-15 * 8)(4)
    lfd     29, (-16 * 8)(4)
    lfd     30, (-17 * 8)(4)
    lfd     31, (-18 * 8)(4)

    /* Set condition and link register */
    mtcr        5
    mtlr        0

    /* Return and switch context */
    blr

#elif defined(__mips__) && _MIPS_SIM == _ABIO32
/************************************************************************************
 * MIPS ASM BITS
 ************************************************************************************/

/**
 * Performs a context switch.
 *
 * $a0 - void** - ptr to old stack pointer
 * $a1 - void*  - new stack pointer
 *
 */
.text
.globl fiber_switchContext
fiber_switchContext:
    addiu $sp, $sp, -(10 * 4)

    // fp regs and return address are stored below the stack
    // because we don't want the GC to scan them.

#ifdef __mips_hard_float
#define ALIGN8(val) (val + (-val & 7))
#define BELOW (ALIGN8(6 * 8 + 4))
    s.d $f20, (0 * 8 - BELOW)($sp)
    s.d $f22, (1 * 8 - BELOW)($sp)
    s.d $f24, (2 * 8 - BELOW)($sp)
    s.d $f26, (3 * 8 - BELOW)($sp)
    s.d $f28, (4 * 8 - BELOW)($sp)
    s.d $f30, (5 * 8 - BELOW)($sp)
#endif
    sw $ra, -4($sp)

    sw $s0, (0 * 4)($sp)
    sw $s1, (1 * 4)($sp)
    sw $s2, (2 * 4)($sp)
    sw $s3, (3 * 4)($sp)
    sw $s4, (4 * 4)($sp)
    sw $s5, (5 * 4)($sp)
    sw $s6, (6 * 4)($sp)
    sw $s7, (7 * 4)($sp)
    sw $s8, (8 * 4)($sp)
    sw $gp, (9 * 4)($sp)

    // swap stack pointer
    sw $sp, 0($a0)
    move $sp, $a1

#ifdef __mips_hard_float
    l.d $f20, (0 * 8 - BELOW)($sp)
    l.d $f22, (1 * 8 - BELOW)($sp)
    l.d $f24, (2 * 8 - BELOW)($sp)
    l.d $f26, (3 * 8 - BELOW)($sp)
    l.d $f28, (4 * 8 - BELOW)($sp)
    l.d $f30, (5 * 8 - BELOW)($sp)
#endif
    lw $ra, -4($sp)

    lw $s0, (0 * 4)($sp)
    lw $s1, (1 * 4)($sp)
    lw $s2, (2 * 4)($sp)
    lw $s3, (3 * 4)($sp)
    lw $s4, (4 * 4)($sp)
    lw $s5, (5 * 4)($sp)
    lw $s6, (6 * 4)($sp)
    lw $s7, (7 * 4)($sp)
    lw $s8, (8 * 4)($sp)
    lw $gp, (9 * 4)($sp)

    addiu $sp, $sp, (10 * 4)

    jr $ra // return

#elif defined(__arm__) && (defined(__ARM_EABI__) || defined(__APPLE__))
/************************************************************************************
 * ARM ASM BITS
 ************************************************************************************/

/**
 * Performs a context switch.
 *
 * Parameters:
 * r0 - void** - ptr to old stack pointer
 * r1 - void*  - new stack pointer
 *
 * ARM EABI registers:
 * r0-r3   : argument/scratch registers
 * r4-r10  : callee-save registers
 * r11     : frame pointer (or a callee save register if fp isn't needed)
 * r12 =ip : inter procedure register. We can treat it like any other scratch register
 * r13 =sp : stack pointer
 * r14 =lr : link register, it contains the return address (belonging to the function which called us)
 * r15 =pc : program counter
 *
 * For floating point registers:
 * According to AAPCS (version 2.09, section 5.1.2) only the d8-d15 registers need to be preserved
 * across method calls. This applies to all ARM FPU variants, whether they have 16 or 32 double registers
 * NEON support or not, half-float support or not and so on does not matter.
 *
 * Note: If this file was compiled with -mfloat-abi=soft but the code runs on a softfp system with fpu the d8-d15
 * registers won't be saved (we do not know that the system has got a fpu in that case) but the registers might actually
 * be used by other code if it was compiled with -mfloat-abi=softfp.
 *
 * Interworking is only supported on ARMv5+, not on ARM v4T as ARM v4t requires special stubs when changing
 * from thumb to arm mode or the other way round.
 */

#if defined(__ARM_PCS_VFP) || ((defined(__ARM_PCS) || defined(__VFP_FP__)) && !defined(__SOFTFP__))
  // This is equivalent to `version (ARM) version (D_HardFloat)`, i.e.,
  // defined if hardware FP instructions are enabled (incl. SoftFP ABI).
  #define ARM_NonSoftFloat
#endif

.text
.align  2
.global CSYM(fiber_switchContext)
#ifndef __APPLE__
#ifdef ARM_NonSoftFloat
  .fpu vfp
#endif
.type   fiber_switchContext, %function
#endif
CSYM(fiber_switchContext):
#ifndef __APPLE__
    .fnstart
#endif
    push {r4-r11}
    // update the oldp pointer. Link register and floating point registers stored later to prevent the GC from
    // scanning them.
    str sp, [r0]
    // push r0 (or any other register) as well to keep stack 8byte aligned
    push {r0, lr}

    #ifdef ARM_NonSoftFloat
      vpush {d8-d15}
      // now switch over to the new stack. Need to subtract (8*8[d8-d15]+2*4[r0, lr]) to position stack pointer
      // below the last saved register. Remember we saved the SP before pushing [r0, lr, d8-d15]
      sub sp, r1, #72
      vpop {d8-d15}
    #else
        #ifdef __thumb__
            sub r1, #8
            mov sp, r1
        #else
            sub sp, r1, #8
        #endif
    #endif

    // we don't really care about r0, we only used that for padding.
    // r1 is now what used to be in the link register when saving.
    pop {r0, r1, r4-r11}
    /**
     * The link register for the initial jump to fiber_entryPoint must be zero: The jump actually
     * looks like a normal method call as we jump to the start of the fiber_entryPoint function.
     * Although fiber_entryPoint never returns and therefore never accesses lr, it saves lr to the stack.
     * ARM unwinding will then look at the stack, find lr and think that fiber_entryPoint was called by
     * the function in lr! So if we have some address in lr the unwinder will try to continue stack unwinding,
     * although it's already at the stack base and crash.
     * In all other cases the content of lr doesn't matter.
     * Note: If we simply loaded into lr above and then moved lr into pc, the initial method call
     * to fiber_entryPoint would look as if it was called from fiber_entryPoint itself, as the fiber_entryPoint
     * address is in lr on the initial context switch.
     */
    mov lr, #0
    // return by writing lr into pc
    mov pc, r1
#ifndef __APPLE__
    .fnend
#endif

#elif defined(__aarch64__)
/************************************************************************************
 * AArch64 (arm64) ASM BITS
 ************************************************************************************/
/**
 * preserve/restore AAPCS64 registers
 *   x19-x28 5.1.1 64-bit callee saved
 *   x29 fp, or possibly callee saved reg - depends on platform choice 5.2.3)
 *   x30 lr
 *   d8-d15  5.1.2 says callee only must save bottom 64-bits (the "d" regs)
 *
 * saved regs on stack will look like:
 *   19: x19
 *   18: x20
 *   ...
 *   10: x28
 *    9: x29 (fp)  <-- oldp / *newp save stack top
 *    8: x30 (lr)
 *    7: d8
 *   ...
 *    0: d15       <-- sp
 */
        .text
        .global CSYM(fiber_switchContext)
        .p2align  2
#ifndef __APPLE__
        .type   fiber_switchContext, %function
#endif
CSYM(fiber_switchContext):
        stp     d15, d14, [sp, #-20*8]!
        stp     d13, d12, [sp, #2*8]
        stp     d11, d10, [sp, #4*8]
        stp     d9, d8,   [sp, #6*8]
        stp     x30, x29, [sp, #8*8] // lr, fp
        stp     x28, x27, [sp, #10*8]
        stp     x26, x25, [sp, #12*8]
        stp     x24, x23, [sp, #14*8]
        stp     x22, x21, [sp, #16*8]
        stp     x20, x19, [sp, #18*8]

        // oldp is set above saved lr (x30) to hide it and float regs
        // from GC
        add     x19, sp, #9*8
        str     x19, [x0]       // *oldp tstack
        sub     sp, x1, #9*8    // switch to newp sp

        ldp     x20, x19, [sp, #18*8]
        ldp     x22, x21, [sp, #16*8]
        ldp     x24, x23, [sp, #14*8]
        ldp     x26, x25, [sp, #12*8]
        ldp     x28, x27, [sp, #10*8]
        ldp     x30, x29, [sp, #8*8] // lr, fp
        ldp     d9, d8,   [sp, #6*8]
        ldp     d11, d10, [sp, #4*8]
        ldp     d13, d12, [sp, #2*8]
        ldp     d15, d14, [sp], #20*8
        ret

/**
 * When generating any kind of backtrace (gdb, exception handling) for
 * a function called in a Fiber, we need to tell the unwinder to stop
 * at our Fiber main entry point, i.e. we need to mark the bottom of
 * the call stack. This can be done by clearing the link register lr
 * prior to calling fiber_entryPoint (i.e. in fiber_switchContext) or
 * using a .cfi_undefined directive for the link register in the
 * Fiber entry point. cfi_undefined seems to yield better results in gdb.
 * Unfortunately we can't place it into fiber_entryPoint using inline
 * asm, so we use this trampoline instead.
 */
        .text
        .global CSYM(fiber_trampoline)
        .p2align  2
#ifndef __APPLE__
        .type   fiber_trampoline, %function
#endif
CSYM(fiber_trampoline):
        .cfi_startproc
        .cfi_undefined x30
        // fiber_entryPoint never returns
        bl CSYM(fiber_entryPoint)
        .cfi_endproc
#endif
