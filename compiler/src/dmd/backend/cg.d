/**
 * Various global symbols.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1995 by Symantec
 *              Copyright (C) 2000-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cg.c, backend/cg.d)
 */

module dmd.backend.cg;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.global;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.type;

extern (C++):

///////////////////// GLOBALS /////////////////////

__gshared
{
targ_size_t     framehandleroffset;     // offset of C++ frame handler
targ_size_t     localgotoffset; // offset of where localgot refers to

int cseg = CODE;                // current code segment
                                // (negative values mean it is the negative
                                // of the public name index of a COMDAT)

/* Stack offsets        */
targ_size_t localsize;          /* amt subtracted from SP for local vars */

/* The following are initialized for the 8088. cod3_set32() or cod3_set64()
 * will change them as appropriate.
 */
int     BPRM = 6;               /* R/M value for [BP] or [EBP]          */
regm_t  fregsaved;              // mask of registers saved across function calls

regm_t  FLOATREGS = FLOATREGS_16;
regm_t  FLOATREGS2 = FLOATREGS2_16;
regm_t  DOUBLEREGS = DOUBLEREGS_16;

Symbol *localgot;               // reference to GOT for this function
Symbol *tls_get_addr_sym;       // function __tls_get_addr

int TARGET_STACKALIGN = 2;      // default for 16 bit code
int STACKALIGN = 2;             // varies for each function


/// Is fl data?
bool[FLMAX] datafl = datafl_init;
extern (D) private enum datafl_init =
() {
    bool[FLMAX] datafl;
    foreach (fl; [ FLdata,FLudata,FLreg,FLpseudo,FLauto,FLfast,FLpara,FLextern,
                   FLcs,FLfltreg,FLallocatmp,FLdatseg,FLtlsdata,FLbprel,
                   FLstack,FLregsave,FLfuncarg,
                   FLndp, FLfardata,
                 ])
    {
        datafl[fl] = true;
    }
    return datafl;
} ();


/// Is fl on the stack?
bool[FLMAX] stackfl = stackfl_init;
extern (D) private enum stackfl_init =
() {
    bool[FLMAX] stackfl;
    foreach (fl; [ FLauto,FLfast,FLpara,FLcs,FLfltreg,FLallocatmp,FLbprel,FLstack,FLregsave,
                   FLfuncarg,
                   FLndp,
                 ])
    {
        stackfl[fl] = true;
    }
    return stackfl;
} ();

/// What segment register is associated with it?
ubyte[FLMAX] segfl = segfl_init;
extern (D) private enum segfl_init =
() {
    ubyte[FLMAX] segfl;

    // Segment registers
    enum ES = 0;
    enum CS = 1;
    enum SS = 2;
    enum DS = 3;
    enum NO = ubyte.max;        // no register

    foreach (fl, ref seg; segfl)
    {
        switch (fl)
        {
            case 0:              seg = NO;  break;
            case FLconst:        seg = NO;  break;
            case FLoper:         seg = NO;  break;
            case FLfunc:         seg = CS;  break;
            case FLdata:         seg = DS;  break;
            case FLudata:        seg = DS;  break;
            case FLreg:          seg = NO;  break;
            case FLpseudo:       seg = NO;  break;
            case FLauto:         seg = SS;  break;
            case FLfast:         seg = SS;  break;
            case FLstack:        seg = SS;  break;
            case FLbprel:        seg = SS;  break;
            case FLpara:         seg = SS;  break;
            case FLextern:       seg = DS;  break;
            case FLcode:         seg = CS;  break;
            case FLblock:        seg = CS;  break;
            case FLblockoff:     seg = CS;  break;
            case FLcs:           seg = SS;  break;
            case FLregsave:      seg = SS;  break;
            case FLndp:          seg = SS;  break;
            case FLswitch:       seg = NO;  break;
            case FLfltreg:       seg = SS;  break;
            case FLoffset:       seg = NO;  break;
            case FLfardata:      seg = NO;  break;
            case FLcsdata:       seg = CS;  break;
            case FLdatseg:       seg = DS;  break;
            case FLctor:         seg = NO;  break;
            case FLdtor:         seg = NO;  break;
            case FLdsymbol:      seg = NO;  break;
            case FLgot:          seg = NO;  break;
            case FLgotoff:       seg = NO;  break;
            case FLtlsdata:      seg = NO;  break;
            case FLlocalsize:    seg = NO;  break;
            case FLframehandler: seg = NO;  break;
            case FLasm:          seg = NO;  break;
            case FLallocatmp:    seg = SS;  break;
            case FLfuncarg:      seg = SS;  break;

            default:
                assert(0);
        }
    }

    return segfl;
} ();

/// Is fl in the symbol table?
bool[FLMAX] flinsymtab = flinsymtab_init;
extern (D) private enum flinsymtab_init =
() {
    bool[FLMAX] flinsymtab;
    foreach (fl; [ FLdata,FLudata,FLreg,FLpseudo,FLauto,FLfast,FLpara,FLextern,FLfunc,
                   FLtlsdata,FLbprel,FLstack,
                   FLfardata,FLcsdata,
                 ])
    {
        flinsymtab[fl] = true;
    }
    return flinsymtab;
} ();

}
