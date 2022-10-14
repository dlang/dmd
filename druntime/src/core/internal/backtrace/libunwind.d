/**
 * Basic D language bindings for LLVM libunwind
 *
 * There are two available libunwind: The "upstream" one, inherited
 * from HP, which is maintained as a GNU project,
 * and the LLVM one, part of llvm-project, and the default on Mac OSX.
 *
 * They are both essential part of other languages ABI, and are available
 * in both GCC and LLVM. However, in GCC, only the higher-level functions
 * are exposed (e.g. `_Unwind_*`) while LLVM expose the higher-level
 * and lower-level (`unw_*`) functions.
 * Many distributions have a `libunwind` package as well, that provides
 * the `unw_*` functions, but since it also supports remote unwinding,
 * the function names are actually platform dependent and binding them
 * is a pain as many things rely on `#define`.
 *
 * In the future, we would like to implement backtrace using only the
 * higher-level functions (`_Unwind_*`), which will allow us to not
 * use `backtrace` and friends directly, and only retrieve the functions
 * names when needed (currently we need to eagerly get the functions names).
 *
 * Authors: Mathias 'Geod24' Lang
 * Copyright: D Language Foundation - 2020
 * See_Also:
 *   - https://www.nongnu.org/libunwind/man/libunwind(3).html
 *   - https://clang.llvm.org/docs/Toolchain.html#unwind-library
 */
module core.internal.backtrace.libunwind;

version (DRuntime_Use_Libunwind):

// Libunwind supports Windows as well, but we currently use a different
// mechanism for Windows, so the bindings haven't been brought in yet.
version (Posix):

import core.stdc.inttypes;

extern(C):
@nogc:
nothrow:

/*
 * Bindings for libunwind.h
 */
alias unw_word_t = uintptr_t;

///
struct unw_context_t
{
    ulong[_LIBUNWIND_CONTEXT_SIZE] data = void;
}

///
struct unw_cursor_t
{
    ulong[_LIBUNWIND_CURSOR_SIZE] data = void;
}

///
struct unw_proc_info_t
{
    unw_word_t  start_ip;         /* start address of function */
    unw_word_t  end_ip;           /* address after end of function */
    unw_word_t  lsda;             /* address of language specific data area, */
    /*  or zero if not used */
    unw_word_t  handler;          /* personality routine, or zero if not used */
    unw_word_t  gp;               /* not used */
    unw_word_t  flags;            /* not used */
    uint        format;           /* compact unwind encoding, or zero if none */
    uint        unwind_info_size; /* size of DWARF unwind info, or zero if none */
    // Note: It's a `void*` with LLVM and a `unw_word_t` with upstream
    unw_word_t  unwind_info;      /* address of DWARF unwind info, or zero */
    // Note: upstream might not have this member at all, or it might be a single
    // byte, however we never pass an array of this type, so this is safe to
    // just use the bigger (LLVM's) value.
    unw_word_t  extra;            /* mach_header of mach-o image containing func */
}

/// Initialize the context at the current call site
int unw_getcontext(unw_context_t*);
/// Initialize a cursor at the call site
int unw_init_local(unw_cursor_t*, unw_context_t*);
/// Goes one level up in the call chain
int unw_step(unw_cursor_t*);
/// Get infos about the current procedure (function)
int unw_get_proc_info(unw_cursor_t*, unw_proc_info_t*);
/// Get the name of the current procedure (function)
int unw_get_proc_name(unw_cursor_t*, char*, size_t, unw_word_t*);

private:

// The API between libunwind and llvm-libunwind is almost the same,
// at least for our use case, and only the struct size change,
// so handle the difference here.
// Upstream: https://github.com/libunwind/libunwind/tree/master/include
// LLVM: https://github.com/llvm/llvm-project/blob/20c926e0797e074bfb946d2c8ce002888ebc2bcd/libunwind/include/__libunwind_config.h#L29-L141
version (X86)
{
    enum _LIBUNWIND_CONTEXT_SIZE = 8;

    version (Android)
        enum _LIBUNWIND_CURSOR_SIZE = 19; // NDK r21
    else
        enum _LIBUNWIND_CURSOR_SIZE = 15;
}
else version (X86_64)
{
    version (Win64)
    {
        enum _LIBUNWIND_CONTEXT_SIZE = 54;
// #    ifdef __SEH__
// #      define _LIBUNWIND_CURSOR_SIZE 204
        enum _LIBUNWIND_CURSOR_SIZE = 66;
    } else {
        enum _LIBUNWIND_CONTEXT_SIZE = 21;
        enum _LIBUNWIND_CURSOR_SIZE = 33;
    }
}
else version (PPC64)
{
    enum _LIBUNWIND_CONTEXT_SIZE = 167;
    enum _LIBUNWIND_CURSOR_SIZE = 179;
}
else version (PPC)
{
    enum _LIBUNWIND_CONTEXT_SIZE = 117;
    enum _LIBUNWIND_CURSOR_SIZE = 124;
}
else version (AArch64)
{
    enum _LIBUNWIND_CONTEXT_SIZE = 66;
// #  if defined(__SEH__)
// #    define _LIBUNWIND_CURSOR_SIZE 164
    enum _LIBUNWIND_CURSOR_SIZE = 78;
}
else version (ARM)
{
// #  if defined(__SEH__)
// #    define _LIBUNWIND_CONTEXT_SIZE 42
// #    define _LIBUNWIND_CURSOR_SIZE 80
// #  elif defined(__ARM_WMMX)
// #    define _LIBUNWIND_CONTEXT_SIZE 61
// #    define _LIBUNWIND_CURSOR_SIZE 68
    enum _LIBUNWIND_CONTEXT_SIZE = 42;
    enum _LIBUNWIND_CURSOR_SIZE = 49;
}
else version (SPARC)
{
    enum _LIBUNWIND_CONTEXT_SIZE = 16;
    enum _LIBUNWIND_CURSOR_SIZE = 23;
}
else version (RISCV64) // 32 is not supported
{
    enum _LIBUNWIND_CONTEXT_SIZE = 64;
    enum _LIBUNWIND_CURSOR_SIZE = 76;
}
else
    static assert(0, "Platform not supported");
