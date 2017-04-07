/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1995 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/cg.c
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

targ_size_t     framehandleroffset;     // offset of C++ frame handler
#if TARGET_OSX
targ_size_t     localgotoffset; // offset of where localgot refers to
#endif

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

symbol *localgot;               // reference to GOT for this function
symbol *tls_get_addr_sym;       // function __tls_get_addr

int STACKALIGN = 2;             // default for 16 bit code
