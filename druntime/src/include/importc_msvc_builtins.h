/* This file contains reimplementations of some of the intrinsics recognized
   by the MSVC compiler, for ImportC.
   To use it, put `#include <importc_msvc_builtins.h>` in the C source-code that intends to use it.

   This header emits its declarations only when `__IMPORTC_MSVC_BUILTINS__` is not defined.
   This header defines `__IMPORTC_MSVC_BUILTINS__` when it is included.

   Copyright: Copyright D Language Foundation 2024-2024
   License: $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
   Authors: Harry Gillanders
   Source: $(DRUNTIMESRC importc_msvc_builtins.h) */

#ifndef __IMPORTC_MSVC_BUILTINS__
#define __IMPORTC_MSVC_BUILTINS__ 1

__import __builtins_msvc;

#if defined(_M_ARM64) || defined(_M_ARM)
#define __dmb __builtin_arm_dmb
#define __dsb __builtin_arm_dsb
#define __isb __builtin_arm_isb
#endif
#endif
