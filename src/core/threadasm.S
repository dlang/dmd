/**
 * Support code for mutithreading.
 *
 * Copyright: Copyright Mikola Lysenko 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Mikola Lysenko
 */

/*
 *          Copyright Mikola Lysenko 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

/************************************************************************************
 * POWER PC ASM BITS
 ************************************************************************************/
#if defined( __ppc__ ) || defined( __PPC__ ) || defined( __powerpc__ )


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
    mflr        r0
    mfcr        r5
    stw     r0, 8(r1)
    stw     r5, 4(r1)

    /* Save GPRs */
    stw     r11, (-1 * 4)(r1)
    stw     r13, (-2 * 4)(r1)
    stw     r14, (-3 * 4)(r1)
    stw     r15, (-4 * 4)(r1)
    stw     r16, (-5 * 4)(r1)
    stw     r17, (-6 * 4)(r1)
    stw     r18, (-7 * 4)(r1)
    stw     r19, (-8 * 4)(r1)
    stw     r20, (-9 * 4)(r1)
    stw     r21, (-10 * 4)(r1)
    stw     r22, (-11 * 4)(r1)
    stw     r23, (-12 * 4)(r1)
    stw     r24, (-13 * 4)(r1)
    stw     r25, (-14 * 4)(r1)
    stw     r26, (-15 * 4)(r1)
    stw     r27, (-16 * 4)(r1)
    stw     r28, (-17 * 4)(r1)
    stw     r29, (-18 * 4)(r1)
    stw     r30, (-19 * 4)(r1)
    stwu    r31, (-20 * 4)(r1)

    /* We update the stack pointer here, since we do not want the GC to
       scan the floating point registers. */

    /* Save FPRs */
    stfd    f14, (-1 * 8)(r1)
    stfd    f15, (-2 * 8)(r1)
    stfd    f16, (-3 * 8)(r1)
    stfd    f17, (-4 * 8)(r1)
    stfd    f18, (-5 * 8)(r1)
    stfd    f19, (-6 * 8)(r1)
    stfd    f20, (-7 * 8)(r1)
    stfd    f21, (-8 * 8)(r1)
    stfd    f22, (-9 * 8)(r1)
    stfd    f23, (-10 * 8)(r1)
    stfd    f24, (-11 * 8)(r1)
    stfd    f25, (-12 * 8)(r1)
    stfd    f26, (-13 * 8)(r1)
    stfd    f27, (-14 * 8)(r1)
    stfd    f28, (-15 * 8)(r1)
    stfd    f29, (-16 * 8)(r1)
    stfd    f30, (-17 * 8)(r1)
    stfd    f31, (-18 * 8)(r1)

    /* Update the old stack pointer */
    stw     r1, 0(r3)

    /* Set new stack pointer */
    addi        r1, r4, 20 * 4

    /* Restore linkage area */
    lwz     r0, 8(r1)
    lwz     r5, 4(r1)

    /* Restore GPRs */
    lwz     r11, (-1 * 4)(r1)
    lwz     r13, (-2 * 4)(r1)
    lwz     r14, (-3 * 4)(r1)
    lwz     r15, (-4 * 4)(r1)
    lwz     r16, (-5 * 4)(r1)
    lwz     r17, (-6 * 4)(r1)
    lwz     r18, (-7 * 4)(r1)
    lwz     r19, (-8 * 4)(r1)
    lwz     r20, (-9 * 4)(r1)
    lwz     r21, (-10 * 4)(r1)
    lwz     r22, (-11 * 4)(r1)
    lwz     r23, (-12 * 4)(r1)
    lwz     r24, (-13 * 4)(r1)
    lwz     r25, (-14 * 4)(r1)
    lwz     r26, (-15 * 4)(r1)
    lwz     r27, (-16 * 4)(r1)
    lwz     r28, (-17 * 4)(r1)
    lwz     r29, (-18 * 4)(r1)
    lwz     r30, (-19 * 4)(r1)
    lwz     r31, (-20 * 4)(r1)


    /* Restore FPRs */
    lfd     f14, (-1 * 8)(r4)
    lfd     f15, (-2 * 8)(r4)
    lfd     f16, (-3 * 8)(r4)
    lfd     f17, (-4 * 8)(r4)
    lfd     f18, (-5 * 8)(r4)
    lfd     f19, (-6 * 8)(r4)
    lfd     f20, (-7 * 8)(r4)
    lfd     f21, (-8 * 8)(r4)
    lfd     f22, (-9 * 8)(r4)
    lfd     f23, (-10 * 8)(r4)
    lfd     f24, (-11 * 8)(r4)
    lfd     f25, (-12 * 8)(r4)
    lfd     f26, (-13 * 8)(r4)
    lfd     f27, (-14 * 8)(r4)
    lfd     f28, (-15 * 8)(r4)
    lfd     f29, (-16 * 8)(r4)
    lfd     f30, (-17 * 8)(r4)
    lfd     f31, (-18 * 8)(r4)

    /* Set condition and link register */
    mtcr        r5
    mtlr        r0

    /* Return and switch context */
    blr

#endif
