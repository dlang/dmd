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

    bool isJumpOP() { return Iop == JMP || Iop == JMPS; }
}

/*******************
 * Some instructions.
 */

enum
{
    SEGES   = 0x26,
    SEGCS   = 0x2E,
    SEGSS   = 0x36,
    SEGDS   = 0x3E,
    SEGFS   = 0x64,
    SEGGS   = 0x65,

    CALL    = 0xE8,
    JMP     = 0xE9,    // Intra-Segment Direct
    JMPS    = 0xEB,    // JMP SHORT
    JCXZ    = 0xE3,
    LOOP    = 0xE2,
    LES     = 0xC4,
    LEA     = 0x8D,
    LOCK    = 0xF0,

    JO      = 0x70,
    JNO     = 0x71,
    JC      = 0x72,
    JB      = 0x72,
    JNC     = 0x73,
    JAE     = 0x73,
    JE      = 0x74,
    JNE     = 0x75,
    JBE     = 0x76,
    JA      = 0x77,
    JS      = 0x78,
    JNS     = 0x79,
    JP      = 0x7A,
    JNP     = 0x7B,
    JL      = 0x7C,
    JGE     = 0x7D,
    JLE     = 0x7E,
    JG      = 0x7F,

    // NOP is used as a placeholder in the linked list of instructions, no
    // actual code will be generated for it.
    NOP     = SEGCS,   // don't use 0x90 because the
                       // Windows stuff wants to output 0x90's

    ASM     = SEGSS,   // string of asm bytes

    ESCAPE  = SEGDS,   // marker that special information is here
                       // (Iop2 is the type of special information)
}


enum ESCAPEmask = 0xFF; // code.Iop & ESCAPEmask ==> actual Iop

enum
{
    ESClinnum   = (1 << 8),      // line number information
    ESCctor     = (2 << 8),      // object is constructed
    ESCdtor     = (3 << 8),      // object is destructed
    ESCmark     = (4 << 8),      // mark eh stack
    ESCrelease  = (5 << 8),      // release eh stack
    ESCoffset   = (6 << 8),      // set code offset for eh
    ESCadjesp   = (7 << 8),      // adjust ESP by IEV2.Vint
    ESCmark2    = (8 << 8),      // mark eh stack
    ESCrelease2 = (9 << 8),      // release eh stack
    ESCframeptr = (10 << 8),     // replace with load of frame pointer
    ESCdctor    = (11 << 8),     // D object is constructed
    ESCddtor    = (12 << 8),     // D object is destructed
    ESCadjfpu   = (13 << 8),     // adjust fpustackused by IEV2.Vint
    ESCfixesp   = (14 << 8),     // reset ESP to end of local frame
}


