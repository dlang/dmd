/**
 * Declarations for back end
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/global.d, backend/global.d)
 */
module dmd.backend.global;

// Online documentation: https://dlang.org/phobos/dmd_backend_global.html

import core.stdc.stdio;
import core.stdc.stdint;

import dmd.backend.barray;
import dmd.backend.cdef;
import dmd.backend.cc : Symbol, block, Classsym, BlockState, FL, Srcpos;
import dmd.backend.code;
import dmd.backend.el : elem;
import dmd.backend.mem;
import dmd.backend.symbol;
import dmd.backend.ty : TYnptr, TYvoid, tybasic, tysize, _tysize;
import dmd.backend.type;

nothrow:
@nogc:

/// Callback for errors raised by the backend
alias ErrorCallbackBackend = extern(C++) void function(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...);

package(dmd.backend) __gshared ErrorCallbackBackend errorCallbackBackend;

/// Callback for the backend to fetch cached source-file contents from the
/// front-end FileManager (populated when the module was read). Returns a
/// pointer to the bytes and sets `length`; returns null if unavailable.
alias GetFileContentsCallback = extern(C++) const(ubyte)* function(const(char)* filename, ref size_t length);

package(dmd.backend) __gshared GetFileContentsCallback getFileContentsCallback;

/**
 * Backend error report function
 * Params:
 *     srcPos = source location
 *     format = printf format string with error message
 *     args = printf format string arguments
 */
void error(T...)(Srcpos srcPos, const(char)* format, T args)
{
    errorCallbackBackend(srcPos.Sfilename, srcPos.Slinnum, srcPos.Scharnum, format, args);
}

@safe:

/***********************************
 * Params:
 *      size = alignment size
 *      offset = increase until it is on a `size` boundary
 * Returns:
 *      aligned `offset`
 */
targ_size_t _align(targ_size_t size, targ_size_t offset) @trusted
{
    switch (size)
    {
        case 1:
            break;
        case 2:
        case 4:
        case 8:
        case 16:
        case 32:
        case 64:
            offset = (offset + size - 1) & ~(size - 1);
            break;
        default:
            if (size >= 16)
                offset = (offset + 15) & ~15;
            else
                offset = (offset + _tysize[TYnptr] - 1) & ~(_tysize[TYnptr] - 1);
            break;
    }
    return offset;
}

/*******************************
 * Get size of ty
 */
targ_size_t size(tym_t ty)
{
    int sz = (tybasic(ty) == TYvoid) ? 1 : tysize(ty);
    debug
    {
        import dmd.backend.debugprint : tym_str;
        if (sz == -1)
            printf("ty: %s\n", tym_str(ty));
    }
    assert(sz!= -1);
    return sz;
}

/****************************
 * Generate symbol of type ty at DATA:offset
 */
Symbol* symboldata(targ_size_t offset, tym_t ty)
{
    import dmd.backend.symbol : symbol_generate;
    Symbol* s = symbol_generate(SC.locstat, type_fake(ty));
    s.Sfl = FL.data;
    s.Soffset = offset;
    s.Stype.Tmangle = Mangle.syscall; // writes symbol unmodified in Obj::mangle
    symbol_keep(s);                   // keep around
    return s;
}

/// Size of a register in bytes
int REGSIZE() @trusted { return _tysize[TYnptr]; }

regm_t mask(uint m) { return cast(regm_t)1 << m; }

void* util_malloc(uint n,uint size) { return mem_malloc(n * size); }
void* util_calloc(uint n,uint size) { return mem_calloc(n * size); }
void util_free(void* p) { mem_free(p); }
void* util_realloc(void* oldp,size_t n,size_t size) { return mem_realloc(oldp, n * size); }

void err_nomem() @nogc nothrow @trusted
{
    import dmd.backend.util2 : err_exit;
    printf("Error: out of memory\n");
    err_exit();
}

void symbol_keep(Symbol* s) { }
