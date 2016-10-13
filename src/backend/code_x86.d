/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1996 by Symantec
 *              Copyright (c) 2000-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     backendlicense.txt
 * Source:      $(DMDSRC backend/_code_x86.d)
 */

module ddmd.backend.code_x86;

import ddmd.backend.code;

alias code_flags_t = uint;

struct code
{
    code *next;
    code_flags_t Iflags;

    union
    {
        uint Iop;
        struct
        {
          align(1):
            ubyte  op;
            ushort pp;
            //ushort   pp : 2;
            //ushort    l : 1;
            //ushort vvvv : 4;
            //ushort    w : 1;
            //ushort mmmm : 5;
            //ushort    b : 1;
            //ushort    x : 1;
            //ushort    r : 1;
            ubyte pfx; // always 0xC4
        } //_Ivex;
    }

    /* The _EA is the "effective address" for the instruction, and consists of the modregrm byte,
     * the sib byte, and the REX prefix byte. The 16 bit code generator just used the modregrm,
     * the 32 bit x86 added the sib, and the 64 bit one added the rex.
     */
    union
    {
        uint Iea;
        struct
        {
            ubyte Irm;          // reg/mode
            ubyte Isib;         // SIB byte
            ubyte Irex;         // REX prefix
        }
    }

    /* IFL1 and IEV1 are the first operand, which usually winds up being the offset to the Effective
     * Address. IFL1 is the tag saying which variant type is in IEV1. IFL2 and IEV2 is the second
     * operand, usually for immediate instructions.
     */

    ubyte IFL1,IFL2;    // FLavors of 1st, 2nd operands
    evc IEV1;             // 1st operand, if any
    evc IEV2;             // 2nd operand, if any
}
