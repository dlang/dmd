/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1995 by Symantec
 *              Copyright (C) 2000-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
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
}

import core.stdc.stdio;

extern (C++) __gshared
{
    ubyte[FLMAX] datafl =
    () {
        ubyte[FLMAX] datafl;
        foreach (fl; [ FLdata,FLudata,FLreg,FLpseudo,FLauto,FLfast,FLpara,FLextern,
                       FLcs,FLfltreg,FLallocatmp,FLdatseg,FLtlsdata,FLbprel,
                       FLstack,FLregsave,FLfuncarg,
                       FLndp, FLfardata,
                     ])
        {
            datafl[fl] = 1;
        }
        return datafl;
    } ();


    ubyte[FLMAX] stackfl =
    () {
        ubyte[FLMAX] stackfl;
        foreach (fl; [ FLauto,FLfast,FLpara,FLcs,FLfltreg,FLallocatmp,FLbprel,FLstack,FLregsave,
                       FLfuncarg,
                       FLndp,
                     ])
        {
            stackfl[fl] = 1;
        }
        return stackfl;
    }();

    ubyte[FLMAX] segfl =
    () {
        ubyte[FLMAX] segfl;

        /* Segment registers    */
        enum ES = 0;
        enum CS = 1;
        enum SS = 2;
        enum DS = 3;

        foreach (i;  0 .. FLMAX)
        {   switch (i)
            {
                case 0:         segfl[i] = cast(byte)-1;  break;
                case FLconst:   segfl[i] = cast(byte)-1;  break;
                case FLoper:    segfl[i] = cast(byte)-1;  break;
                case FLfunc:    segfl[i] = CS;  break;
                case FLdata:    segfl[i] = DS;  break;
                case FLudata:   segfl[i] = DS;  break;
                case FLreg:     segfl[i] = cast(byte)-1;  break;
                case FLpseudo:  segfl[i] = cast(byte)-1;  break;
                case FLauto:    segfl[i] = SS;  break;
                case FLfast:    segfl[i] = SS;  break;
                case FLstack:   segfl[i] = SS;  break;
                case FLbprel:   segfl[i] = SS;  break;
                case FLpara:    segfl[i] = SS;  break;
                case FLextern:  segfl[i] = DS;  break;
                case FLcode:    segfl[i] = CS;  break;
                case FLblock:   segfl[i] = CS;  break;
                case FLblockoff: segfl[i] = CS; break;
                case FLcs:      segfl[i] = SS;  break;
                case FLregsave: segfl[i] = SS;  break;
                case FLndp:     segfl[i] = SS;  break;
                case FLswitch:  segfl[i] = cast(byte)-1;  break;
                case FLfltreg:  segfl[i] = SS;  break;
                case FLoffset:  segfl[i] = cast(byte)-1;  break;
                case FLfardata: segfl[i] = cast(byte)-1;  break;
                case FLcsdata:  segfl[i] = CS;  break;
                case FLdatseg:  segfl[i] = DS;  break;
                case FLctor:    segfl[i] = cast(byte)-1;  break;
                case FLdtor:    segfl[i] = cast(byte)-1;  break;
                case FLdsymbol: segfl[i] = cast(byte)-1;  break;
                case FLgot:     segfl[i] = cast(byte)-1;  break;
                case FLgotoff:  segfl[i] = cast(byte)-1;  break;
                case FLlocalsize: segfl[i] = cast(byte)-1;        break;
                case FLtlsdata: segfl[i] = cast(byte)-1;  break;
                case FLframehandler:    segfl[i] = cast(byte)-1;  break;
                case FLasm:     segfl[i] = cast(byte)-1;  break;
                case FLallocatmp:       segfl[i] = SS;  break;
                case FLfuncarg:         segfl[i] = SS;  break;
                default:
                        printf("error in segfl[%d]\n", i);
                        assert(0);
            }
        }

        return segfl;
    }();

    ubyte[FLMAX] flinsymtab =
    () {
        ubyte[FLMAX] flinsymtab;
        foreach (fl; [ FLdata,FLudata,FLreg,FLpseudo,FLauto,FLfast,FLpara,FLextern,FLfunc,
                       FLtlsdata,FLbprel,FLstack,
                       FLfardata,FLcsdata,
                     ])
        {
            flinsymtab[fl] = 1;
        }
        return flinsymtab;
    }();
}


