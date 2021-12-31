/**
 * Generates the .pdata and .xdata sections for Win64
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2012-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/pdata.d, backend/pdata.d)
 */

module dmd.backend.pdata;

version (MARS)
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.exh;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.rtlsym;
import dmd.backend.ty;
import dmd.backend.type;

extern (C++):

nothrow:

// Determine if this Symbol is stored in a COMDAT
private bool symbol_iscomdat3(Symbol* s)
{
    version (MARS)
    {
        return s.Sclass == SCcomdat ||
            config.flags2 & CFG2comdat && s.Sclass == SCinline ||
            config.flags4 & CFG4allcomdat && s.Sclass == SCglobal;
    }
    else
    {
        return s.Sclass == SCcomdat ||
            config.flags2 & CFG2comdat && s.Sclass == SCinline ||
            config.flags4 & CFG4allcomdat && (s.Sclass == SCglobal || s.Sclass == SCstatic);
    }
}

enum ALLOCA_LIMIT = 0x10000;

/**********************************
 * The .pdata section is used on Win64 by the VS debugger and dbghelp to get information
 * to walk the stack and unwind exceptions.
 * Absent it, it is assumed to be a "leaf function" where [RSP] is the return address.
 * Creates an instance of struct RUNTIME_FUNCTION:
 *   https://msdn.microsoft.com/en-US/library/ft9x1kdx%28v=vs.100%29.aspx
 *
 * Params:
 *      sf = function to generate unwind data for
 */

public void win64_pdata(Symbol *sf)
{
    //printf("win64_pdata()\n");
    assert(config.exe == EX_WIN64);

    // Generate the pdata name, which is $pdata$funcname
    size_t sflen = strlen(sf.Sident.ptr);
    char *pdata_name = cast(char *)(sflen < ALLOCA_LIMIT ? alloca(7 + sflen + 1) : malloc(7 + sflen + 1));
    assert(pdata_name);
    memcpy(pdata_name, "$pdata$".ptr, 7);
    memcpy(pdata_name + 7, sf.Sident.ptr, sflen + 1);      // include terminating 0

    Symbol *spdata = symbol_name(pdata_name,SCstatic,tstypes[TYint]);
    symbol_keep(spdata);
    symbol_debug(spdata);

    Symbol *sunwind = win64_unwind(sf);

    /* 3 pointers are emitted:
     *  1. pointer to start of function sf
     *  2. pointer past end of function sf
     *  3. pointer to unwind data
     */

    auto dtb = DtBuilder(0);
    dtb.xoff(sf,0,TYint);       // Note the TYint, these are 32 bit fixups
    dtb.xoff(sf,cast(uint)(retoffset + retsize),TYint);
    dtb.xoff(sunwind,0,TYint);
    spdata.Sdt = dtb.finish();

    spdata.Sseg = symbol_iscomdat3(sf) ? MsCoffObj_seg_pdata_comdat(sf) : MsCoffObj_seg_pdata();
    spdata.Salignment = 4;
    outdata(spdata);

    if (sflen >= ALLOCA_LIMIT) free(pdata_name);
}

private:

/**************************************************
 * Unwind data symbol goes in the .xdata section.
 * Input:
 *      sf      function to generate unwind data for
 * Returns:
 *      generated symbol referring to unwind data
 */

private Symbol *win64_unwind(Symbol *sf)
{
    // Generate the unwind name, which is $unwind$funcname
    size_t sflen = strlen(sf.Sident.ptr);
    char *unwind_name = cast(char *)(sflen < ALLOCA_LIMIT ? alloca(8 + sflen + 1) : malloc(8 + sflen + 1));
    assert(unwind_name);
    memcpy(unwind_name, "$unwind$".ptr, 8);
    memcpy(unwind_name + 8, sf.Sident.ptr, sflen + 1);     // include terminating 0

    Symbol *sunwind = symbol_name(unwind_name,SCstatic,tstypes[TYint]);
    symbol_keep(sunwind);
    symbol_debug(sunwind);

    sunwind.Sdt = unwind_data();
    sunwind.Sseg = symbol_iscomdat3(sf) ? MsCoffObj_seg_xdata_comdat(sf) : MsCoffObj_seg_xdata();
    sunwind.Salignment = 1;
    outdata(sunwind);

    if (sflen >= ALLOCA_LIMIT) free(unwind_name);
    return sunwind;
}

/************************* Win64 Unwind Data ******************************************/

/************************************************************************
 * Creates an instance of struct UNWIND_INFO:
 *   https://msdn.microsoft.com/en-US/library/ddssxxy8%28v=vs.100%29.aspx
 */

enum UWOP
{   // http://www.osronline.com/ddkx/kmarch/64bitamd_7btz.htm
    // http://uninformed.org/index.cgi?v=4&a=1&p=17
    PUSH_NONVOL,     // push saved register, OpInfo is register
    ALLOC_LARGE,     // alloc large size on stack, OpInfo is 0 or 1
    ALLOC_SMALL,     // alloc small size on stack, OpInfo is size / 8 - 1
    SET_FPREG,       // set frame pointer
    SAVE_NONVOL,     // save register, OpInfo is reg, frame offset in next FrameOffset
    SAVE_NONVOL_FAR, // save register, OpInfo is reg, frame offset in next 2 FrameOffsets
    SAVE_XMM128,     // save 64 bits of XMM reg, frame offset in next FrameOffset
    SAVE_XMM128_FAR, // save 64 bits of XMM reg, frame offset in next 2 FrameOffsets
    PUSH_MACHFRAME   // push interrupt frame, OpInfo is 0 or 1 (pushes error code too)
}

union UNWIND_CODE
{
/+
    struct
    {
        ubyte CodeOffset;       // offset of start of next instruction
        ubyte UnwindOp : 4;     // UWOP
        ubyte OpInfo   : 4;     // extra information depending on UWOP
    } op;
+/
    ushort FrameOffset;
}

ushort setUnwindCode(ubyte CodeOffset, ubyte UnwindOp, ubyte OpInfo)
{
    return cast(ushort)(CodeOffset | (UnwindOp << 8) | (OpInfo << 12));
}

enum
{
    UNW_FLAG_EHANDLER  = 1,  // function has an exception handler
    UNW_FLAG_UHANDLER  = 2,  // function has a termination handler
    UNW_FLAG_CHAININFO = 4   // not the primary one for the function
}

struct UNWIND_INFO
{
    ubyte Version;    //: 3;    // 1
    //ubyte Flags       : 5;    // UNW_FLAG_xxxx
    ubyte SizeOfProlog;         // bytes in the function prolog
    ubyte CountOfCodes;         // dimension of UnwindCode[]
    ubyte FrameRegister; //: 4; // if !=0, then frame pointer register
    //ubyte FrameOffset    : 4; // frame register offset from RSP divided by 16
    UNWIND_CODE[6] UnwindCode;
static if (0)
{
    UNWIND_CODE[((CountOfCodes + 1) & ~1) - 1]  MoreUnwindCode;
    union
    {
        // UNW_FLAG_EHANDLER | UNW_FLAG_UHANDLER
        struct
        {
            uint ExceptionHandler;
            void[n] Language_specific_handler_data;
        }

        // UNW_FLAG_CHAININFO
        RUNTIME_FUNCTION chained_unwind_info;
    }
}
}



private dt_t *unwind_data()
{
    UNWIND_INFO ui;

    /* 4 allocation size strategy:
     *  0:           no unwind instruction
     *  8..128:      UWOP.ALLOC_SMALL
     *  136..512K-8: UWOP.ALLOC_LARGE, OpInfo = 0
     *  512K..4GB-8: UWOP.ALLOC_LARGE, OpInfo = 1
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
    ui.SizeOfProlog = cast(ubyte)startoffset;
static if (0)
{
    ui.CountOfCodes = strategy + 1;
    ui.FrameRegister = 0;
    //ui.FrameOffset = 0;
}
else
{
    strategy = 0;
    ui.CountOfCodes = cast(ubyte)(strategy + 2);
    ui.FrameRegister = BP;
    //ui.FrameOffset = 0; //cod3_spoff() / 16;
}

static if (0)
{
    switch (strategy)
    {
        case 0:
            break;

        case 1:
            ui.UnwindCode[0].FrameOffset = setUnwindCode(prolog_allocoffset, UWOP.ALLOC_SMALL, (sz - 8) / 8);
            break;

        case 2:
            ui.UnwindCode[0].FrameOffset = setUnwindCode(prolog_allocoffset, UWOP.ALLOC_LARGE, 0);
            ui.UnwindCode[1].FrameOffset = (sz - 8) / 8;
            break;

        case 3:
            ui.UnwindCode[0].FrameOffset = setUnwindCode(prolog_allocoffset, UWOP.ALLOC_LARGE, 1);
            ui.UnwindCode[1].FrameOffset = sz & 0x0FFFF;
            ui.UnwindCode[2].FrameOffset = sz / 0x10000;
            break;
    }
}

static if (1)
{
    ui.UnwindCode[ui.CountOfCodes-2].FrameOffset = setUnwindCode(4, UWOP.SET_FPREG, 0);
}

    ui.UnwindCode[ui.CountOfCodes-1].FrameOffset = setUnwindCode(1, UWOP.PUSH_NONVOL, BP);

    auto dtb = DtBuilder(0);
    dtb.nbytes(4 + ((ui.CountOfCodes + 1) & ~1) * 2,cast(char *)&ui);
    return dtb.finish();
}
}
