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

mixin(import("fltables.d"));

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
