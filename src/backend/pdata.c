// Compiler implementation of the D programming language
// Copyright (c) 2012-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt
// https://github.com/D-Programming-Language/dmd/blob/master/src/backend/pdata.c

// This module generates the .pdata and .xdata sections for Win64

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "code.h"
#include        "oper.h"
#include        "global.h"
#include        "type.h"
#include        "dt.h"
#include        "exh.h"
#include        "obj.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

#if _MSC_VER || __sun
#include        <alloca.h>
#endif

#if MARS
#if TARGET_WINDOS

Symbol *win64_unwind(Symbol *sf);
dt_t *unwind_data();

/**********************************
 * The .pdata section is used on Win64 by the VS debugger and dbghelp to get information
 * to walk the stack and unwind exceptions.
 * Absent it, it is assumed to be a "leaf function" where [RSP] is the return address.
 * Creates an instance of struct RUNTIME_FUNCTION:
 *   http://msdn.microsoft.com/en-US/library/ft9x1kdx(v=vs.80).aspx
 *
 * Input:
 *      sf      function to generate unwind data for
 */

void win64_pdata(Symbol *sf)
{
//    return; // doesn't work yet

    //printf("win64_pdata()\n");
    assert(config.exe == EX_WIN64);

    // Generate the pdata name, which is $pdata$funcname
    size_t sflen = strlen(sf->Sident);
    char *pdata_name = (char *)alloca(7 + sflen + 1);
    assert(pdata_name);
    memcpy(pdata_name, "$pdata$", 7);
    memcpy(pdata_name + 7, sf->Sident, sflen + 1);      // include terminating 0

    symbol *spdata = symbol_name(pdata_name,SCstatic,tsint);
    symbol_keep(spdata);
    symbol_debug(spdata);

    symbol *sunwind = win64_unwind(sf);

    /* 3 pointers are emitted:
     *  1. pointer to start of function sf
     *  2. pointer past end of function sf
     *  3. pointer to unwind data
     */

    dt_t **pdt = &spdata->Sdt;
    pdt = dtxoff(pdt,sf,0,TYint);       // Note the TYint, these are 32 bit fixups
    pdt = dtxoff(pdt,sf,retoffset + retsize,TYint);
    pdt = dtxoff(pdt,sunwind,0,TYint);

    spdata->Sseg = symbol_iscomdat(sf) ? MsCoffObj::seg_pdata_comdat(sf) : MsCoffObj::seg_pdata();
    spdata->Salignment = 4;
    outdata(spdata);
}

/**************************************************
 * Unwind data symbol goes in the .xdata section.
 * Input:
 *      sf      function to generate unwind data for
 * Returns:
 *      generated symbol referring to unwind data
 */

Symbol *win64_unwind(Symbol *sf)
{
    // Generate the unwind name, which is $unwind$funcname
    size_t sflen = strlen(sf->Sident);
    char *unwind_name = (char *)alloca(8 + sflen + 1);
    assert(unwind_name);
    memcpy(unwind_name, "$unwind$", 8);
    memcpy(unwind_name + 8, sf->Sident, sflen + 1);     // include terminating 0

    symbol *sunwind = symbol_name(unwind_name,SCstatic,tsint);
    symbol_keep(sunwind);
    symbol_debug(sunwind);

    sunwind->Sdt = unwind_data();
    sunwind->Sseg = symbol_iscomdat(sf) ? MsCoffObj::seg_xdata_comdat(sf) : MsCoffObj::seg_xdata();
    sunwind->Salignment = 1;
    outdata(sunwind);
    return sunwind;
}

/************************* Win64 Unwind Data ******************************************/

/************************************************************************
 * Creates an instance of struct UNWIND_INFO:
 *   http://msdn.microsoft.com/en-US/library/ddssxxy8(v=vs.80).aspx
 */

enum UWOP
{   // http://www.osronline.com/ddkx/kmarch/64bitamd_7btz.htm
    // http://uninformed.org/index.cgi?v=4&a=1&p=17
    UWOP_PUSH_NONVOL,     // push saved register, OpInfo is register
    UWOP_ALLOC_LARGE,     // alloc large size on stack, OpInfo is 0 or 1
    UWOP_ALLOC_SMALL,     // alloc small size on stack, OpInfo is size / 8 - 1
    UWOP_SET_FPREG,       // set frame pointer
    UWOP_SAVE_NONVOL,     // save register, OpInfo is reg, frame offset in next FrameOffset
    UWOP_SAVE_NONVOL_FAR, // save register, OpInfo is reg, frame offset in next 2 FrameOffsets
    UWOP_SAVE_XMM128,     // save 64 bits of XMM reg, frame offset in next FrameOffset
    UWOP_SAVE_XMM128_FAR, // save 64 bits of XMM reg, frame offset in next 2 FrameOffsets
    UWOP_PUSH_MACHFRAME   // push interrupt frame, OpInfo is 0 or 1 (pushes error code too)
};

union UNWIND_CODE
{
    struct
    {
        unsigned char CodeOffset;       // offset of start of next instruction
        unsigned char UnwindOp : 4;     // UWOP
        unsigned char OpInfo   : 4;     // extra information depending on UWOP
    } op;
    unsigned short FrameOffset;
};

enum
{
    UNW_FLAG_EHANDLER  = 1,  // function has an exception handler
    UNW_FLAG_UHANDLER  = 2,  // function has a termination handler
    UNW_FLAG_CHAININFO = 4   // not the primary one for the function
};

struct UNWIND_INFO
{
    unsigned char Version       : 3;    // 1
    unsigned char Flags         : 5;    // UNW_FLAG_xxxx
    unsigned char SizeOfProlog;         // bytes in the function prolog
    unsigned char CountOfCodes;         // dimension of UnwindCode[]
    unsigned char FrameRegister : 4;    // if !=0, then frame pointer register
    unsigned char FrameOffset   : 4;    // frame register offset from RSP divided by 16
    UNWIND_CODE UnwindCode[6];
#if 0
    UNWIND_CODE MoreUnwindCode[((CountOfCodes + 1) & ~1) - 1];
    union
    {
        // UNW_FLAG_EHANDLER | UNW_FLAG_UHANDLER
        struct
        {
            unsigned long ExceptionHandler;
            void[n] Language_specific_handler_data;
        };

        // UNW_FLAG_CHAININFO
        RUNTIME_FUNCTION chained_unwind_info;
    };
#endif
};



dt_t *unwind_data()
{
    UNWIND_INFO ui;
    memset(&ui, 0, sizeof(ui));

    /* 4 allocation size strategy:
     *  0:           no unwind instruction
     *  8..128:      UWOP_ALLOC_SMALL
     *  136..512K-8: UWOP_ALLOC_LARGE, OpInfo = 0
     *  512K..4GB-8: UWOP_ALLOC_LARGE, OpInfo = 1
     */
    targ_size_t sz = localsize;
    assert((localsize & 7) == 0);
    int strategy;
    if (sz == 0)
        strategy = 0;
    else if (sz <= 128)
        strategy = 1;
    else if (sz <= 512 * 1024 - 8)
        strategy = 2;
    else
        // 512KB to 4GB-8
        strategy = 3;

    ui.Version = 1;
    //ui.Flags = 0;
    ui.SizeOfProlog = startoffset;
#if 0
    ui.CountOfCodes = strategy + 1;
    ui.FrameRegister = 0;
    ui.FrameOffset = 0;
#else
    strategy = 0;
    ui.CountOfCodes = strategy + 2;
    ui.FrameRegister = BP;
    ui.FrameOffset = 0; //cod3_spoff() / 16;
#endif

#if 0
    switch (strategy)
    {
        case 0:
            break;

        case 1:
            ui.UnwindCode[0].op.CodeOffset = prolog_allocoffset;
            ui.UnwindCode[0].op.UnwindOp = UWOP_ALLOC_SMALL;
            ui.UnwindCode[0].op.OpInfo = (sz - 8) / 8;
            break;

        case 2:
            ui.UnwindCode[0].op.CodeOffset = prolog_allocoffset;
            ui.UnwindCode[0].op.UnwindOp = UWOP_ALLOC_LARGE;
            ui.UnwindCode[0].op.OpInfo = 0;

            ui.UnwindCode[1].FrameOffset = (sz - 8) / 8;
            break;

        case 3:
            ui.UnwindCode[0].op.CodeOffset = prolog_allocoffset;
            ui.UnwindCode[0].op.UnwindOp = UWOP_ALLOC_LARGE;
            ui.UnwindCode[0].op.OpInfo = 1;

            ui.UnwindCode[1].FrameOffset = sz & 0x0FFFF;
            ui.UnwindCode[2].FrameOffset = sz / 0x10000;
            break;
    }
#endif

#if 1
    ui.UnwindCode[ui.CountOfCodes-2].op.CodeOffset = 4;
    ui.UnwindCode[ui.CountOfCodes-2].op.UnwindOp = UWOP_SET_FPREG;
    ui.UnwindCode[ui.CountOfCodes-2].op.OpInfo = 0;
#endif

    ui.UnwindCode[ui.CountOfCodes-1].op.CodeOffset = 1;
    ui.UnwindCode[ui.CountOfCodes-1].op.UnwindOp = UWOP_PUSH_NONVOL;
    ui.UnwindCode[ui.CountOfCodes-1].op.OpInfo = BP;

    dt_t *dt = NULL;
    dt_t **pdt = &dt;
    pdt = dtnbytes(pdt,4 + ((ui.CountOfCodes + 1) & ~1) * 2,(char *)&ui);
    return dt;
}

#endif
#endif

#endif
