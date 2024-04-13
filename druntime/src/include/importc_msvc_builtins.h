/* This file contains reimplementations of some of the intrinsics recognized
   by the MSVC compiler, for ImportC.
   To use it, put `#include <importc_msvc_builtins.h>` in the C source-code that intends to use it.

   This header emits its declarations only when `__IMPORTC_MSVC_BUILTINS__` is not defined.
   This header defines `__IMPORTC_MSVC_BUILTINS__` when it is included.

   Copyright: Copyright D Language Foundation 2024-2026
   License: $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
   Authors: Harry Gillanders
   Source: $(DRUNTIMESRC importc_msvc_builtins.h) */

#ifndef __IMPORTC_MSVC_BUILTINS__
#define __IMPORTC_MSVC_BUILTINS__ 1

__import __builtins_msvc;

/* Refer to https://learn.microsoft.com/cpp/intrinsics/assume.
   MSVC's `__assume` plays double duty as an optimisation-hint
   and a way to denote unreachable code.
   Denoting unreachable code is the more important duty,
   hence these definitions of `__assume`. */
#if defined(__IMPORTC_DMD__)
#define __assume(expression) __check(!!(expression))
#elif defined(__IMPORTC_LDC__)
#define __assume(expression) llvm_assume(!!(expression))
#else
#define __assume(expression) do {if (!(expression)) {__builtin_unreachable();}} while (0)
#endif

#if defined(_M_ARM64) || defined(_M_ARM)
#define __dmb __builtin_arm_dmb
#define __dsb __builtin_arm_dsb
#define __isb __builtin_arm_isb
#endif
#endif
