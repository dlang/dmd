/**
 * Declarations for back end
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/global.d, backend/global.d)
 */
module dmd.backend.global;

// Online documentation: https://dlang.org/phobos/dmd_backend_global.html

@nogc:
nothrow:

import core.stdc.stdio;
import core.stdc.stdint;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.cc : Symbol, block, Classsym, Blockx;
import dmd.backend.code_x86 : code;
import dmd.backend.code;
import dmd.backend.dlist;
import dmd.backend.el;
import dmd.backend.el : elem;
import dmd.backend.mem;
import dmd.backend.symtab;
import dmd.backend.type;
//import dmd.backend.obj;

import dmd.backend.barray;

nothrow:
@safe:

// FIXME: backend can't import front end modules because missing -J flag
extern (C++) void error(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...);
package extern (C++) void fatal();

public import dmd.backend.eh : except_gentables;
import dmd.backend.var : _tysize;
import dmd.backend.ty : TYnptr, TYvoid, tybasic, tysize;

/***********************************
 * Returns: aligned `offset` if it is of size `size`.
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
targ_size_t size(tym_t ty) @trusted
{
    int sz = (tybasic(ty) == TYvoid) ? 1 : tysize(ty);
    debug
    {
        if (sz == -1)
            printf("ty: %s\n", tym_str(ty));
    }
    assert(sz!= -1);
    return sz;
}

/****************************
 * Generate symbol of type ty at DATA:offset
 */
Symbol *symboldata(targ_size_t offset, tym_t ty)
{
    Symbol *s = symbol_generate(SC.locstat, type_fake(ty));
    s.Sfl = FLdata;
    s.Soffset = offset;
    s.Stype.Tmangle = mTYman_sys; // writes symbol unmodified in Obj::mangle
    symbol_keep(s);               // keep around
    return s;
}

/// Size of a register in bytes
int REGSIZE() @trusted { return _tysize[TYnptr]; }

public import dmd.backend.var : debuga, debugb, debugc, debugd, debuge, debugf,
    debugr, debugs, debugt, debugu, debugw, debugx, debugy;

extern (D) uint mask(uint m) { return 1 << m; }

public import dmd.backend.var : OPTIMIZER, PARSER, globsym, controlc_saw, pointertype, sytab;
public import dmd.backend.cg : fregsaved, localgot, tls_get_addr_sym;
public import dmd.backend.blockopt : startblock, dfo, curblock, block_last;

__gshared Configv configv;                // non-ph part of configuration

public import dmd.backend.ee : eecontext_convs;
public import dmd.backend.elem : exp2_copytotemp;
public import dmd.backend.util2 : err_exit, ispow2;

void* util_malloc(uint n,uint size) { return mem_malloc(n * size); }
void* util_calloc(uint n,uint size) { return mem_calloc(n * size); }
void util_free(void *p) { mem_free(p); }
void *util_realloc(void *oldp,size_t n,size_t size) { return mem_realloc(oldp, n * size); }

public import dmd.backend.cgcs : comsubs, cgcs_term;
public import dmd.backend.evalu8;

void err_nomem() @nogc nothrow @trusted
{
    printf("Error: out of memory\n");
    err_exit();
}

void symbol_keep(Symbol *s) { }
public import dmd.backend.symbol : symbol_print, symbol_term, symbol_ident, symbol_calloc,
    symbol_name, symbol_generate, symbol_genauto, symbol_genauto, symbol_genauto,
    symbol_func, symbol_funcalias, meminit_free, baseclass_find, baseclass_find_nest,
    baseclass_nitems, symbol_free, symbol_add, symbol_add, symbol_insert, freesymtab,
    symbol_copy, symbol_reset, symbol_pointerType;

public import dmd.backend.cg87 : loadconst, cg87_reset;

public import dmd.backend.cod3 : cod3_thunk;

public import dmd.backend.dout : outthunk, out_readonly, out_readonly_comdat,
    out_regcand, writefunc, alignOffset, out_reset, out_readonly_sym, out_string_literal, outdata;

public import dmd.backend.blockopt : bc_goal, block_calloc, block_init, block_term, block_next,
    block_next, block_goto, block_goto, block_goto, block_goto, block_ptr, block_pred,
    block_clearvisit, block_visit, block_compbcount, blocklist_free, block_optimizer_free,
    block_free, block_appendexp, block_endfunc, brcombine, blockopt, compdfo;

public import dmd.backend.var : regstring;
public import dmd.backend.debugprint;
public import dmd.backend.cgelem : doptelem, postoptelem, elemisone;
public import dmd.backend.gloop : dom;
public import dmd.backend.util2 : binary;

public import dmd.backend.go : go_flag, optfunc;
public import dmd.backend.drtlsym : rtlsym_init, rtlsym_reset, rtlsym_term;
public import dmd.backend.compress : id_compress;
public import dmd.backend.dwarfdbginf : dwarf_CFA_set_loc, dwarf_CFA_set_reg_offset,
    dwarf_CFA_offset, dwarf_CFA_args_size;
