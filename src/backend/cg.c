// Copyright (C) 1984-1995 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#include        <stdio.h>
#include        <time.h>
#include        <string.h>
#include        <stdlib.h>

#include        "cc.h"
#include        "global.h"
#include        "code.h"
#include        "type.h"
#include        "filespec.h"

///////////////////// GLOBALS /////////////////////

#include        "fltables.c"

targ_size_t     Poffset;        /* size of func parameter variables     */
targ_size_t     framehandleroffset;     // offset of C++ frame handler
#if TARGET_OSX
targ_size_t     localgotoffset; // offset of where localgot refers to
#endif

int cseg = CODE;                // current code segment
                                // (negative values mean it is the negative
                                // of the public name index of a COMDAT)

/* Stack offsets        */
targ_size_t localsize,          /* amt subtracted from SP for local vars */
        Toff,                   /* base for temporaries                 */
        Poff,Aoff,FASToff;      // comsubexps, params, regs, autos, fastpars

/* The following are initialized for the 8088. cod3_set32() or cod3_set64()
 * will change them as appropriate.
 */
int     BPRM = 6;               /* R/M value for [BP] or [EBP]          */
regm_t  fregsaved;              // mask of registers saved across function calls

regm_t  FLOATREGS = FLOATREGS_16;
regm_t  FLOATREGS2 = FLOATREGS2_16;
regm_t  DOUBLEREGS = DOUBLEREGS_16;

symbol *localgot;               // reference to GOT for this function
symbol *tls_get_addr_sym;       // function __tls_get_addr

#if TARGET_OSX
int STACKALIGN = 16;
#else
int STACKALIGN = 0;
#endif
