/* Register-parking helpers for the fiber_fpreg_gc_scan test.
 *
 * Kept in a separate assembly file because no source-level construct
 * can force a compiler's register allocator to place a pointer in a
 * callee-saved FP register, and inline asm would tie the test to one
 * compiler's dialect.  Only meaningful on architectures with
 * callee-saved FP registers covered by the test (AArch64,
 * LoongArch64); compiles to an empty object elsewhere.
 *
 * hold_in_fpreg_and_yield is ABI-conformant: like any function using
 * a callee-saved register, it saves the caller's copy in its prologue
 * and restores it in its epilogue, keeping its own value in the
 * register across the call to the callback - exactly the code shape a
 * compiler emits when it allocates a value to a callee-saved FP
 * register across a call.
 */

#if (__linux__ || __FreeBSD__ || __NetBSD__ || __OpenBSD__ || __DragonFly__) && __ELF__
.section .note.GNU-stack,"",%progbits
#endif

#ifdef __USER_LABEL_PREFIX__
#define GLUE2(a, b) a ## b
#define GLUE(a, b) GLUE2(a, b)
#define CSYM(name) GLUE(__USER_LABEL_PREFIX__, name)
#else
#define CSYM(name) name
#endif

#if defined(__aarch64__)

/* size_t hold_in_fpreg_and_yield(size_t obf, size_t key, void (*yield)(void))
 *
 * Deobfuscates obf ^ key into the callee-saved d8, calls yield() with
 * the resulting pointer's only copy held there, and returns it after
 * yield comes back.
 */
        .text
        .global CSYM(hold_in_fpreg_and_yield)
        .p2align 2
#ifndef __APPLE__
        .type   hold_in_fpreg_and_yield, %function
#endif
CSYM(hold_in_fpreg_and_yield):
        stp     x29, x30, [sp, #-32]!
        mov     x29, sp
        str     d8, [sp, #16]   // save the caller's d8 (callee saved)

        eor     x9, x0, x1
        fmov    d8, x9          // the pointer's only copy lives in d8
        mov     x9, xzr
        blr     x2              // yield(): suspends the fiber

        fmov    x0, d8          // read it back after resume

        ldr     d8, [sp, #16]   // restore the caller's d8
        ldp     x29, x30, [sp], #32
        ret

/* void scrub_regs(void)
 *
 * Clear scratch registers that might still hold a stale copy of the
 * canary pointer.
 */
        .text
        .global CSYM(scrub_regs)
        .p2align 2
#ifndef __APPLE__
        .type   scrub_regs, %function
#endif
CSYM(scrub_regs):
        mov     x9, xzr
        mov     x10, xzr
        mov     x11, xzr
        mov     x12, xzr
        mov     x13, xzr
        mov     x14, xzr
        mov     x15, xzr
        ret

/* void compiler_barrier(void *p)
 *
 * Opaque sink: keeps the pointed-to memory alive and ordered as far as
 * the calling compiler can tell.
 */
        .text
        .global CSYM(compiler_barrier)
        .p2align 2
#ifndef __APPLE__
        .type   compiler_barrier, %function
#endif
CSYM(compiler_barrier):
        ret

#elif defined(__loongarch64)

/* size_t hold_in_fpreg_and_yield(size_t obf, size_t key, void (*yield)(void))
 *
 * Deobfuscates obf ^ key into the callee-saved fs0, calls yield() with
 * the resulting pointer's only copy held there, and returns it after
 * yield comes back.
 */
        .text
        .globl  CSYM(hold_in_fpreg_and_yield)
        .p2align 2
        .type   hold_in_fpreg_and_yield, %function
CSYM(hold_in_fpreg_and_yield):
        addi.d      $sp, $sp, -32
        st.d        $ra, $sp, 24
        fst.d       $fs0, $sp, 16   # save the caller's fs0 (callee saved)

        xor         $t0, $a0, $a1
        movgr2fr.d  $fs0, $t0       # the pointer's only copy lives in fs0
        move        $t0, $zero
        jirl        $ra, $a2, 0     # yield(): suspends the fiber

        movfr2gr.d  $a0, $fs0       # read it back after resume

        fld.d       $fs0, $sp, 16   # restore the caller's fs0
        ld.d        $ra, $sp, 24
        addi.d      $sp, $sp, 32
        jr          $ra

/* void scrub_regs(void)
 *
 * Clear scratch registers that might still hold a stale copy of the
 * canary pointer.
 */
        .text
        .globl  CSYM(scrub_regs)
        .p2align 2
        .type   scrub_regs, %function
CSYM(scrub_regs):
        move    $t0, $zero
        move    $t1, $zero
        move    $t2, $zero
        move    $t3, $zero
        move    $t4, $zero
        move    $t5, $zero
        move    $t6, $zero
        move    $t7, $zero
        move    $t8, $zero
        jr      $ra

/* void compiler_barrier(void *p)
 *
 * Opaque sink: keeps the pointed-to memory alive and ordered as far as
 * the calling compiler can tell.
 */
        .text
        .globl  CSYM(compiler_barrier)
        .p2align 2
        .type   compiler_barrier, %function
CSYM(compiler_barrier):
        jr      $ra

#endif /* __aarch64__ / __loongarch64 */
