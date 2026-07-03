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

/* It is common in the Windows SDK's headers for an MSVC intrinsic to be declared like so:
       UCHAR __readfsbyte(ULONG Offset);
       #pragma intrinsic(__readfsbyte)

   Wherein the intrinsic is first declared to be an externally-defined function,
   and then the MSVC-specific `#pragma intrinsic` is used to inform the compiler
   that it can actually use a compiler-intrinsic for references to functions of that name.

   ImportC ignores `#pragma intrinsic` and so, unless action is taken,
   those externally-defined function declarations will cause linker errors
   as those compiler-intrinsics don't have any external definition.

   To remedy this issue in ImportC, ImportC's Construct Consideration pragmas can be used;
   namely, `#pragma function_decl(ignore)` has the same effect as `#pragma intrinsic`.

   For every MSVC intrinsic that is declared with `#pragma intrinsic` in the Windows SDK's headers,
   that is reimplemented in the `__builtins_msvc` module, we apply `#pragma function_decl(ignore)`.
   This allows for those intrinsics to be inlined, and obviates the need to unconditionally
   perform codegen for every intrinsic in the `__builtins_msvc` module to avoid linker errors. */

/* Intrinsics for x86-64, x86, AArch64, or ARM. */
#if defined(_M_AMD64) || defined(_M_IX86) || defined(_M_ARM64) || defined(_M_ARM)
#pragma function_decl(ignore, __iso_volatile_load8, __iso_volatile_load16, __iso_volatile_load32, __iso_volatile_load64, __iso_volatile_store8, __iso_volatile_store16, __iso_volatile_store32, __iso_volatile_store64)
#pragma function_decl(ignore, __debugbreak, __fastfail)
#pragma function_decl(ignore, _disable, _enable)
#pragma function_decl(ignore, _interlockedadd, _interlockedadd64, _InterlockedAnd, _InterlockedAnd8, _InterlockedAnd16, _interlockedand64)
#pragma function_decl(ignore, _interlockedbittestandreset, _interlockedbittestandset, _InterlockedCompareExchange, _InterlockedCompareExchange8, _InterlockedCompareExchange16, _InterlockedCompareExchange64, _InterlockedCompareExchangePointer)
#pragma function_decl(ignore, _InterlockedDecrement, _InterlockedDecrement16, _interlockeddecrement64)
#pragma function_decl(ignore, _InterlockedExchange, _InterlockedExchange8, _InterlockedExchange16, _interlockedexchange64, _InterlockedExchangeAdd, _InterlockedExchangeAdd8, _InterlockedExchangeAdd16, _interlockedexchangeadd64, _InterlockedExchangePointer)
#pragma function_decl(ignore, _InterlockedIncrement, _InterlockedIncrement16, _interlockedincrement64)
#pragma function_decl(ignore, _InterlockedOr, _InterlockedOr8, _InterlockedOr16, _interlockedor64)
#pragma function_decl(ignore, _InterlockedXor, _InterlockedXor8, _InterlockedXor16, _interlockedxor64)
#pragma function_decl(ignore, __noop, __nop)
#pragma function_decl(ignore, _ReadBarrier, _WriteBarrier, _ReadWriteBarrier)
#pragma function_decl(ignore, _BitScanForward, _BitScanReverse)
#pragma function_decl(ignore, _bittest, _bittestandcomplement, _bittestandreset, _bittestandset)
#pragma function_decl(ignore, _byteswap_uint64, _byteswap_ulong, _byteswap_ushort)
#pragma function_decl(ignore, _lrotr, _lrotl, _rotr, _rotl, _rotr64, _rotl64, _rotr16, _rotl16, _rotr8, _rotl8)
#endif

/* Intrinsics for x86-64, AArch64, or ARM.  `X86_64_Or_AArch64_Or_ARM` in `__builtins_msvc.d`. */
#if defined(_M_AMD64) || defined(_M_ARM64) || defined(_M_ARM)
#pragma function_decl(ignore, _InterlockedAnd64, _InterlockedDecrement64, _InterlockedExchange64, _InterlockedExchangeAdd64, _InterlockedIncrement64, _InterlockedOr64, _InterlockedXor64)
#endif

/* Intrinsics for x86-64, or AArch64.       `X86_64_Or_AArch64` in `__builtins_msvc.d`. */
#if defined(_M_AMD64) || defined(_M_ARM64)
#pragma function_decl(ignore, __umulh, __mulh)
#pragma function_decl(ignore, _interlockedbittestandreset64, _interlockedbittestandset64, _InterlockedCompareExchange128)
#pragma function_decl(ignore, _BitScanForward64, _BitScanReverse64)
#pragma function_decl(ignore, _bittest64, _bittestandcomplement64, _bittestandreset64, _bittestandset64)
#endif

/* Intrinsics for x86-64, or x86.           `X86_64_Or_X86` in `__builtins_msvc.d`. */
#if defined(_M_AMD64) || defined(_M_IX86)
#pragma function_decl(ignore, __emul, __emulu, _div64, _udiv64)
#pragma function_decl(ignore, _mm_pause)
#pragma function_decl(ignore, _m_prefetchw, _mm_prefetch)
#pragma function_decl(ignore, _mm_clflush)
#pragma function_decl(ignore, _mm_getcsr, _mm_setcsr)
#pragma function_decl(ignore, _mm_lfence, _mm_mfence, _mm_sfence)
#pragma function_decl(ignore, __cpuid, __cpuidex)
#pragma function_decl(ignore, _cvt_ftoi_fast, _cvt_ftoll_fast, _cvt_ftoui_fast, _cvt_ftoull_fast, _cvt_dtoi_fast, _cvt_dtoll_fast, _cvt_dtoui_fast, _cvt_dtoull_fast, _cvt_ftoi_sat, _cvt_ftoll_sat, _cvt_ftoui_sat, _cvt_ftoull_sat)
#pragma function_decl(ignore, _cvt_dtoi_sat, _cvt_dtoll_sat, _cvt_dtoui_sat, _cvt_dtoull_sat, _cvt_ftoi_sent, _cvt_ftoll_sent, _cvt_ftoui_sent, _cvt_ftoull_sent, _cvt_dtoi_sent, _cvt_dtoui_sent, _cvt_dtoll_sent, _cvt_dtoull_sent)
#pragma function_decl(ignore, __halt)
#pragma function_decl(ignore, _InterlockedAnd_HLEAcquire, _InterlockedAnd_HLERelease)
#pragma function_decl(ignore, _interlockedbittestandreset_HLEAcquire, _interlockedbittestandreset_HLERelease, _interlockedbittestandset_HLEAcquire, _interlockedbittestandset_HLERelease)
#pragma function_decl(ignore, _InterlockedCompareExchange_HLEAcquire, _InterlockedCompareExchange_HLERelease, _InterlockedCompareExchange64_HLEAcquire, _InterlockedCompareExchange64_HLERelease, _InterlockedCompareExchangePointer_HLEAcquire, _InterlockedCompareExchangePointer_HLERelease)
#pragma function_decl(ignore, _InterlockedExchange_HLEAcquire, _InterlockedExchange_HLERelease, _InterlockedExchangeAdd_HLEAcquire, _InterlockedExchangeAdd_HLERelease, _InterlockedExchangePointer_HLEAcquire, _InterlockedExchangePointer_HLERelease)
#pragma function_decl(ignore, _InterlockedOr_HLEAcquire, _InterlockedOr_HLERelease, _InterlockedXor_HLEAcquire, _InterlockedXor_HLERelease)
#pragma function_decl(ignore, __inbyte, __inword, __indword, __outbyte, __outword, __outdword, __inbytestring, __inwordstring, __indwordstring, __outbytestring, __outwordstring, __outdwordstring)
#pragma function_decl(ignore, __int2c)
#pragma function_decl(ignore, __invlpg)
#pragma function_decl(ignore, __lidt)
#pragma function_decl(ignore, __ll_lshift, __ll_rshift, __ull_rshift)
#pragma function_decl(ignore, __lzcnt16, __lzcnt, _lzcnt_u32, _tzcnt_u16, _tzcnt_u32)
#pragma function_decl(ignore, _mm_extract_si64, _mm_extracti_si64, _mm_insert_si64, _mm_inserti_si64)
#pragma function_decl(ignore, _mm_stream_sd, _mm_stream_ss)
#pragma function_decl(ignore, __movsb, __movsw, __movsd)
#pragma function_decl(ignore, __popcnt16, __popcnt)
#pragma function_decl(ignore, __rdtsc, __rdtscp)
#pragma function_decl(ignore, __readcr0, __readcr2, __readcr3, __readcr4, __readcr8, __readdr, __readeflags, __readmsr, __readpmc)
#pragma function_decl(ignore, __segmentlimit)
#pragma function_decl(ignore, __sidt)
#pragma function_decl(ignore, __stosb, __stosw, __stosd)
#pragma function_decl(ignore, __svm_clgi, __svm_invlpga, __svm_skinit, __svm_stgi, __svm_vmload, __svm_vmrun, __svm_vmsave)
#pragma function_decl(ignore, __ud2)
#pragma function_decl(ignore, __vmx_off, __vmx_vmptrst)
#pragma function_decl(ignore, __wbinvd)
#pragma function_decl(ignore, __writecr0, __writecr2, __writecr3, __writecr4, __writecr8, __writedr, __writeeflags, __writemsr)
#endif

/* Intrinsics for x86-64.                   `X86_64` in `__builtins_msvc.d`. */
#if defined(_M_AMD64)
#pragma function_decl(ignore, _umul128, _mul128, _div128, _udiv128)
#pragma function_decl(ignore, __readgsbyte, __readgsword, __readgsdword, __readgsqword, __writegsbyte, __writegsword, __writegsdword, __writegsqword, __addgsbyte, __addgsword, __addgsdword, __addgsqword, __incgsbyte, __incgsword, __incgsdword, __incgsqword)
#pragma function_decl(ignore, __faststorefence)
#pragma function_decl(ignore, _InterlockedAnd_np, _InterlockedAnd8_np, _InterlockedAnd16_np, _InterlockedAnd64_np, _InterlockedAnd64_HLEAcquire, _InterlockedAnd64_HLERelease)
#pragma function_decl(ignore, _interlockedbittestandreset64_HLEAcquire, _interlockedbittestandreset64_HLERelease, _interlockedbittestandset64_HLEAcquire, _interlockedbittestandset64_HLERelease)
#pragma function_decl(ignore, _InterlockedCompareExchange_np, _InterlockedCompareExchange16_np, _InterlockedCompareExchange64_np, _InterlockedCompareExchange128_np, _InterlockedCompareExchangePointer_np)
#pragma function_decl(ignore, _InterlockedExchange64_HLEAcquire, _InterlockedExchange64_HLERelease, _InterlockedExchangeAdd64_HLEAcquire, _InterlockedExchangeAdd64_HLERelease)
#pragma function_decl(ignore, _InterlockedOr_np, _InterlockedOr8_np, _InterlockedOr16_np, _InterlockedOr64_np, _InterlockedOr64_HLEAcquire, _InterlockedOr64_HLERelease)
#pragma function_decl(ignore, _InterlockedXor_np, _InterlockedXor8_np, _InterlockedXor16_np, _InterlockedXor64_np, _InterlockedXor64_HLEAcquire, _InterlockedXor64_HLERelease)
#pragma function_decl(ignore, __lzcnt64, _lzcnt_u64, _tzcnt_u64)
#pragma function_decl(ignore, _mm_cvtsi64x_ss, _mm_cvtss_si64x, _mm_cvttss_si64x, _mm_stream_si64x)
#pragma function_decl(ignore, __movsq)
#pragma function_decl(ignore, __popcnt64)
#pragma function_decl(ignore, __shiftleft128, __shiftright128)
#pragma function_decl(ignore, __stosq)
#pragma function_decl(ignore, __vmx_on, __vmx_vmclear, __vmx_vmlaunch, __vmx_vmptrld, __vmx_vmread, __vmx_vmresume, __vmx_vmwrite)
#endif

/* Intrinsics for x86.                      `X86` in `__builtins_msvc.d`. */
#if defined(_M_IX86)
#pragma function_decl(ignore, __readfsbyte, __readfsword, __readfsdword, __readfsqword, __writefsbyte, __writefsword, __writefsdword, __writefsqword, __addfsbyte, __addfsword, __addfsdword, __incfsbyte, __incfsword, __incfsdword)
#pragma function_decl(ignore, _InterlockedAddLargeStatistic)
#endif

/* Intrinsics for AArch64, or ARM.          `AArch64_Or_ARM` in `__builtins_msvc.d`. */
#if defined(_M_ARM64) || defined(_M_ARM)
#pragma function_decl(ignore, __prefetch)
#pragma function_decl(ignore, __dmb, __dsb, __isb)
#pragma function_decl(ignore, _InterlockedAdd, _InterlockedAdd_acq, _InterlockedAdd_rel, _InterlockedAdd_nf, _InterlockedAdd64, _InterlockedAdd64_acq, _InterlockedAdd64_rel, _InterlockedAdd64_nf)
#pragma function_decl(ignore, _InterlockedAnd_acq, _InterlockedAnd_rel, _InterlockedAnd_nf, _InterlockedAnd8_acq, _InterlockedAnd8_rel, _InterlockedAnd8_nf, _InterlockedAnd16_acq, _InterlockedAnd16_rel, _InterlockedAnd16_nf, _InterlockedAnd64_acq, _InterlockedAnd64_rel, _InterlockedAnd64_nf)
#pragma function_decl(ignore, _interlockedbittestandreset_acq, _interlockedbittestandreset_rel, _interlockedbittestandreset_nf, _interlockedbittestandset_acq, _interlockedbittestandset_rel, _interlockedbittestandset_nf)
#pragma function_decl(ignore, _InterlockedCompareExchange_acq, _InterlockedCompareExchange_rel, _InterlockedCompareExchange_nf, _InterlockedCompareExchange8_acq, _InterlockedCompareExchange8_rel, _InterlockedCompareExchange8_nf, _InterlockedCompareExchange16_acq, _InterlockedCompareExchange16_rel, _InterlockedCompareExchange16_nf, _InterlockedCompareExchange64_acq, _InterlockedCompareExchange64_rel, _InterlockedCompareExchange64_nf)
#pragma function_decl(ignore, _InterlockedCompareExchangePointer_acq, _InterlockedCompareExchangePointer_rel, _InterlockedCompareExchangePointer_nf)
#pragma function_decl(ignore, _InterlockedDecrement_acq, _InterlockedDecrement_rel, _InterlockedDecrement_nf, _InterlockedDecrement16_acq, _InterlockedDecrement16_rel, _InterlockedDecrement16_nf, _InterlockedDecrement64_acq, _InterlockedDecrement64_rel, _InterlockedDecrement64_nf)
#pragma function_decl(ignore, _InterlockedExchange_acq, _InterlockedExchange_rel, _InterlockedExchange_nf, _InterlockedExchange8_acq, _InterlockedExchange8_rel, _InterlockedExchange8_nf, _InterlockedExchange16_acq, _InterlockedExchange16_rel, _InterlockedExchange16_nf, _InterlockedExchange64_acq, _InterlockedExchange64_rel, _InterlockedExchange64_nf)
#pragma function_decl(ignore, _InterlockedExchangeAdd_acq, _InterlockedExchangeAdd_rel, _InterlockedExchangeAdd_nf, _InterlockedExchangeAdd8_acq, _InterlockedExchangeAdd8_rel, _InterlockedExchangeAdd8_nf, _InterlockedExchangeAdd16_acq, _InterlockedExchangeAdd16_rel, _InterlockedExchangeAdd16_nf, _InterlockedExchangeAdd64_acq, _InterlockedExchangeAdd64_rel, _InterlockedExchangeAdd64_nf)
#pragma function_decl(ignore, _InterlockedExchangePointer_acq, _InterlockedExchangePointer_rel, _InterlockedExchangePointer_nf)
#pragma function_decl(ignore, _InterlockedIncrement_acq, _InterlockedIncrement_rel, _InterlockedIncrement_nf, _InterlockedIncrement16_acq, _InterlockedIncrement16_rel, _InterlockedIncrement16_nf, _InterlockedIncrement64_acq, _InterlockedIncrement64_rel, _InterlockedIncrement64_nf)
#pragma function_decl(ignore, _InterlockedOr_acq, _InterlockedOr_rel, _InterlockedOr_nf, _InterlockedOr8_acq, _InterlockedOr8_rel, _InterlockedOr8_nf, _InterlockedOr16_acq, _InterlockedOr16_rel, _InterlockedOr16_nf, _InterlockedOr64_acq, _InterlockedOr64_rel, _InterlockedOr64_nf)
#pragma function_decl(ignore, _InterlockedXor_acq, _InterlockedXor_rel, _InterlockedXor_nf, _InterlockedXor8_acq, _InterlockedXor8_rel, _InterlockedXor8_nf, _InterlockedXor16_acq, _InterlockedXor16_rel, _InterlockedXor16_nf, _InterlockedXor64_acq, _InterlockedXor64_rel, _InterlockedXor64_nf)
#pragma function_decl(ignore, __yield)
#endif

/* Intrinsics for AArch64.                  `AArch64` in `__builtins_msvc.d`. */
#if defined(_M_ARM64)
#pragma function_decl(ignore, __readx18byte, __readx18word, __readx18dword, __readx18qword, __writex18byte, __writex18word, __writex18dword, __writex18qword, __addx18byte, __addx18word, __addx18dword, __addx18qword, __incx18byte, __incx18word, __incx18dword, __incx18qword)
#pragma function_decl(ignore, _interlockedbittestandreset64_acq, _interlockedbittestandreset64_rel, _interlockedbittestandreset64_nf, _interlockedbittestandset64_acq, _interlockedbittestandset64_rel, _interlockedbittestandset64_nf)
#pragma function_decl(ignore, _InterlockedCompareExchange128_acq, _InterlockedCompareExchange128_rel, _InterlockedCompareExchange128_nf)
#pragma function_decl(ignore, __ldar8, __ldar16, __ldar32, __ldar64, __load_acquire8, __load_acquire16, __load_acquire32, __load_acquire64, __stlr8, __stlr16, __stlr32, __stlr64)
#endif

/* Intrinsics for ARM.                      `ARM` in `__builtins_msvc.d`. */
#if defined(_M_ARM)
#pragma function_decl(ignore, __prefetchw)
#endif

/* If you are adding to this file,
 * please consider placing your additions
 * above the `#pragma function_decl` directives,
 * to minimise the scrolling needed for intra-file navigation.
 * Thank you!
 */
#endif
