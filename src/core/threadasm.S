/**
 * Support code for mutithreading.
 *
 * Copyright: Copyright Mikola Lysenko 2005 - 2012.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Mikola Lysenko, Martin Nowak, Kai Nacke
 */

/*
 *          Copyright Mikola Lysenko 2005 - 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

/************************************************************************************
 * POWER PC ASM BITS
 ************************************************************************************/
#if defined( __PPC64__ )


    .text
    .globl  _D4core6thread18callWithStackShellFMDFPvZvZv
    .align  2
    .type _D4core6thread18callWithStackShellFMDFPvZvZv,@function
    .section  .opd,"aw",@progbits
_D4core6thread18callWithStackShellFMDFPvZvZv:
    .align  3
    .quad .L._D4core6thread18callWithStackShellFMDFPvZvZv
    .quad .TOC.@tocbase
    .quad 0
    .text
/*
 * Called with:
 * r3: pointer context
 * r4: pointer to function
 */
.L._D4core6thread18callWithStackShellFMDFPvZvZv:
    .cfi_startproc
    mflr    0
    std     0, 16(1)                    // save LR
    stdu    1, -256(1)                  // stack size: 18*8 + 112 = 256
    .cfi_def_cfa_offset 256
    .cfi_offset lr, 16

    /* Save r14-r31 in general register save area */
    std     14, (112 + 0 * 8)(1)
    std     15, (112 + 1 * 8)(1)
    std     16, (112 + 2 * 8)(1)
    std     17, (112 + 3 * 8)(1)
    std     18, (112 + 4 * 8)(1)
    std     19, (112 + 5 * 8)(1)
    std     20, (112 + 6 * 8)(1)
    std     21, (112 + 7 * 8)(1)
    std     22, (112 + 8 * 8)(1)
    std     23, (112 + 9 * 8)(1)
    std     24, (112 + 10 * 8)(1)
    std     25, (112 + 11 * 8)(1)
    std     26, (112 + 12 * 8)(1)
    std     27, (112 + 13 * 8)(1)
    std     28, (112 + 14 * 8)(1)
    std     29, (112 + 15 * 8)(1)
    std     30, (112 + 16 * 8)(1)
    std     31, (112 + 17 * 8)(1)

    /* Save r3-r10 in parameter save area of caller */
    std     3, (256 + 48 + 0 * 8)(1)
    std     4, (256 + 48 + 1 * 8)(1)
    std     5, (256 + 48 + 2 * 8)(1)
    std     6, (256 + 48 + 3 * 8)(1)
    std     7, (256 + 48 + 4 * 8)(1)
    std     8, (256 + 48 + 5 * 8)(1)
    std     9, (256 + 48 + 6 * 8)(1)
    std     10, (256 + 48 + 7 * 8)(1)

    /* Save r2 in TOC save area */
    std     2, 40(1)

    /* Do not save r11, r12 and r13. */

    /* Call delegate:
     * r3: pointer to context
     * r4: pointer to stack
     */
    mr      5, 4
    mr      4, 1
    ld      6, 0(5)
    ld      11, 16(5)
    ld      2, 8(5)
    mtctr   6
    bctrl
    nop

    /* Restore r2 from TOC save area */
    ld      2, 40(1)

    /* Restore r3-r10 from local variable space */
    ld      3, (256 + 48 + 0 * 8)(1)
    ld      4, (256 + 48 + 1 * 8)(1)
    ld      5, (256 + 48 + 2 * 8)(1)
    ld      6, (256 + 48 + 3 * 8)(1)
    ld      7, (256 + 48 + 4 * 8)(1)
    ld      8, (256 + 48 + 5 * 8)(1)
    ld      9, (256 + 48 + 6 * 8)(1)
    ld      10, (256 + 48 + 7 * 8)(1)

    /* Restore r14-r31 from general register save area */
    ld      14, (112 + 0 * 8)(1)
    ld      15, (112 + 1 * 8)(1)
    ld      16, (112 + 2 * 8)(1)
    ld      17, (112 + 3 * 8)(1)
    ld      18, (112 + 4 * 8)(1)
    ld      19, (112 + 5 * 8)(1)
    ld      20, (112 + 6 * 8)(1)
    ld      21, (112 + 7 * 8)(1)
    ld      22, (112 + 8 * 8)(1)
    ld      23, (112 + 9 * 8)(1)
    ld      24, (112 + 10 * 8)(1)
    ld      25, (112 + 11 * 8)(1)
    ld      26, (112 + 12 * 8)(1)
    ld      27, (112 + 13 * 8)(1)
    ld      28, (112 + 14 * 8)(1)
    ld      29, (112 + 15 * 8)(1)
    ld      30, (112 + 16 * 8)(1)
    ld      31, (112 + 17 * 8)(1)

    addi    1, 1, 256
    ld      0, 16(1)
    mtlr    0
    blr
    .long 0
    .quad 0
.Lend:
    .size _D4core6thread18callWithStackShellFMDFPvZvZv, .Lend-.L._D4core6thread18callWithStackShellFMDFPvZvZv
    .cfi_endproc

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
    sdcl $f20, (0 * 8 - BELOW)($sp)
    sdcl $f22, (1 * 8 - BELOW)($sp)
    sdcl $f24, (2 * 8 - BELOW)($sp)
    sdcl $f26, (3 * 8 - BELOW)($sp)
    sdcl $f28, (4 * 8 - BELOW)($sp)
    sdcl $f30, (5 * 8 - BELOW)($sp)
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
    ldcl $f20, (0 * 8 - BELOW)($sp)
    ldcl $f22, (1 * 8 - BELOW)($sp)
    ldcl $f24, (2 * 8 - BELOW)($sp)
    ldcl $f26, (3 * 8 - BELOW)($sp)
    ldcl $f28, (4 * 8 - BELOW)($sp)
    ldcl $f30, (5 * 8 - BELOW)($sp)
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

#endif
