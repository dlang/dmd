// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2010 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if !DEMO && !SPP

#include        <stdio.h>
#include        <stdlib.h>
#include        <string.h>
#include        <time.h>

#include        "cc.h"
#include        "code.h"
#include        "iasm.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

//
// NOTE: For 0 operand instructions, the opcode is taken from
// the first entry and no subsequent entries are required.
// for instructions with operands, a NULL entry is required at the end
// as a terminator
//
// 0 Operand instructions
//

#define OPTABLE0(str,op,mod) PTRNTAB0 aptb0##str[] = { { op, mod }, };

OPTABLE0(AAA,     0x37  ,_i64_bit | _modax);
OPTABLE0(AAD,     0xd50a,_i64_bit | _modax);
OPTABLE0(AAM,     0xd40a,_i64_bit | _modax);
OPTABLE0(AAS,     0x3f,  _i64_bit | _modax);
OPTABLE0(CBW,     0x98,_16_bit | _modax);
OPTABLE0(CWDE,    0x98,_32_bit | _I386 | _modax);
OPTABLE0(CDQE,    0x98,_64_bit | _modax);
OPTABLE0(CLC,     0xf8,0);
OPTABLE0(CLD,     0xfc,0);
OPTABLE0(CLI,     0xfa,0);
OPTABLE0(CLTS,    0x0f06,0);
OPTABLE0(CMC,     0xf5,0);
OPTABLE0(CMPSB,   0xa6,_modsidi);
OPTABLE0(CMPSW,   0xa7,_16_bit | _modsidi);
//OPTABLE0(CMPSD, 0xa7,_32_bit | _I386 | _modsidi);
OPTABLE0(CMPSQ,   0xa7,_64_bit | _modsidi);
OPTABLE0(CWD,     0x99, _16_bit | _modaxdx);
OPTABLE0(CDQ,     0x99,_32_bit | _I386 | _modaxdx);
OPTABLE0(CQO,     0x99, _64_bit | _modaxdx);
OPTABLE0(DAA,     0x27,_i64_bit | _modax );
OPTABLE0(DAS,     0x2f,_i64_bit | _modax );
OPTABLE0(HLT,     0xf4,0);
OPTABLE0(INSB,    0x6c,_I386 | _modsi);
OPTABLE0(INSW,    0x6d,_16_bit | _I386 | _modsi);
OPTABLE0(INSD,    0x6d,_32_bit | _I386 | _modsi);
OPTABLE0(INTO,    0xce,_i64_bit);
OPTABLE0(INVD,    0x0f08,_I386);               // Actually a 486 only instruction
OPTABLE0(IRET,    0xcf,_16_bit);
OPTABLE0(IRETD,   0xcf,_32_bit | _I386);
OPTABLE0(LAHF,    0x9f,_modax);
OPTABLE0(LEAVE,   0xc9,_I386);
OPTABLE0(LOCK,    0xf0,0);
OPTABLE0(LODSB,   0xac,_modsiax);
OPTABLE0(LODSW,   0xad,_16_bit | _modsiax);
OPTABLE0(LODSD,   0xad,_32_bit | _I386 | _modsiax);
OPTABLE0(LODSQ,   0xad,_64_bit | _modsiax);
OPTABLE0(MOVSB,   0xa4, _modsidi);
OPTABLE0(MOVSW,   0xa5, _16_bit | _modsidi);
OPTABLE0(MOVSQ,   0xa5, _64_bit | _modsidi);
OPTABLE0(NOP,     0x90, 0);
OPTABLE0(OUTSB,   0x6e, _I386 | _modsi);
OPTABLE0(OUTSW,   0x6f, _16_bit | _I386 | _modsi);
OPTABLE0(OUTSD,   0x6f, _32_bit | _I386 | _modsi);
OPTABLE0(POPA,    0x61,_i64_bit | _16_bit | _I386 | _modall);
OPTABLE0(POPAD,   0x61,_i64_bit | _32_bit | _I386 | _modall);
OPTABLE0(POPF,    0x9d,           _16_bit);
OPTABLE0(POPFD,   0x9d,_i64_bit | _32_bit | _I386);
OPTABLE0(POPFQ,   0x9d, _64_bit);
OPTABLE0(PUSHA,   0x60,_i64_bit | _16_bit | _I386);
OPTABLE0(PUSHAD,  0x60,_i64_bit | _32_bit | _I386);
OPTABLE0(PUSHF,   0x9c,           _16_bit);
OPTABLE0(PUSHFD,  0x9c,_i64_bit | _32_bit | _I386);
OPTABLE0(PUSHFQ,  0x9c, _64_bit);                // TODO REX_W override is implicit
OPTABLE0(REP,     0xf3, _modcx);
OPTABLE0(REPNE,   0xf2, _modcx);
OPTABLE0(SAHF,    0x9e, 0);
OPTABLE0(SCASB,   0xAE, _moddi);
OPTABLE0(SCASW,   0xAF, _16_bit | _moddi);
OPTABLE0(SCASD,   0xAF, _32_bit | _I386 | _moddi);
OPTABLE0(SCASQ,   0xAF, _64_bit | _moddi);
OPTABLE0(STC,     0xf9, 0);
OPTABLE0(STD,     0xfd, 0);
OPTABLE0(STI,     0xfb, 0);
OPTABLE0(STOSB,   0xaa, _moddi);
OPTABLE0(STOSW,   0xAB, _16_bit | _moddi);
OPTABLE0(STOSD,   0xAB, _32_bit | _I386 | _moddi);
OPTABLE0(STOSQ,   0xAB, _64_bit | _moddi);
OPTABLE0(WAIT,    0x9B, 0);
OPTABLE0(WBINVD,  0x0f09, _I386);                        // Really a 486 opcode
OPTABLE0(XLATB,   0xd7, _modax);
OPTABLE0(CPUID,   0x0fa2, _I386 | _modall);
OPTABLE0(RDMSR,   0x0f32, _I386 | _modaxdx);
OPTABLE0(RDPMC,   0x0f33, _I386 | _modaxdx);
OPTABLE0(RDTSC,   0x0f31, _I386 | _modaxdx);
OPTABLE0(WRMSR,   0x0f30, _I386);
OPTABLE0(RSM,     0x0faa,_i64_bit | _I386);

PTRNTAB2 aptb2MOVSD[] =  /* MOVSD */ {
        { 0xa5, _32_bit | _I386 | _modsidi },
        { 0xF20F10, _r, _xmm, _xmm_m64 },
        { 0xF20F11, _r, _xmm_m64, _xmm },
};

//
// Now come the one operand instructions
// These will prove to be a little more challenging than the 0
// operand instructions
//
PTRNTAB1 aptb1BSWAP[] = /* BSWAP */ {
                                // Really is a 486 only instruction
        { 0x0fc8,   _I386, _plus_r | _r32 },
        { 0x0fc8, _64_bit, _plus_r | _r64 },
        { ASM_END, 0, 0 }
};

PTRNTAB1 aptb1CALL[] = /* CALL */ {
        { 0xe8, _cw| _i64_bit |           _modall,  _rel16  },
        { 0xff, _2 | _i64_bit | _16_bit | _modall,  _r16 },
        { 0xff, _2 | _i64_bit |           _modall,  _m16 },
        { 0x9a, _cd| _i64_bit |           _modall,  _p1616  },
        { 0xff, _3 |                      _modall,  _m1616  },
        { 0xe8, _cd|                      _modall,  _rel32  },
        { 0xff, _2 | _i64_bit | _32_bit | _modall,  _r32  },
        { 0xff, _2 |            _32_bit | _modall,  _r64  },       // REX_W override is implicit
        { 0xff, _2 | _i64_bit |           _modall,  _m32  },
        { 0xff, _2 |            _64_bit | _modall,  _m64  },       // TODO REX_W override is implicit
        { 0x9a, _cp| _i64_bit |           _modall,  _p1632 },
        { 0xff, _3 |                      _modall,  _m1632 },
        { ASM_END, 0, 0 }
};

PTRNTAB1 aptb1DEC[] = /* DEC */ {
        { 0xfe, _1,                        _rm8 },
        { 0xff, _1  |            _16_bit,  _m16 },         // Also _r16 synonym
        { 0xff, _1  |            _32_bit,  _m32 },         // Also _r32 synonym
        { 0xff, _1  |            _64_bit,  _rm64 },        // Also _r64 synonym
        { 0x48, _rw | _i64_bit | _16_bit,  _r16 | _plus_r },
        { 0x48, _rw | _i64_bit | _32_bit,  _r32 | _plus_r },
        { ASM_END, 0, 0 }
};

PTRNTAB1 aptb1INC[] = /* INC */ {
        { 0xfe, _0,                        _rm8 },
        { 0xff, _0  |            _16_bit,  _m16 },         // Also _r16 synonym
        { 0xff, _0  |            _32_bit,  _m32 },         // Also _r32 synonym
        { 0xff, _0  |            _64_bit,  _rm64 },        // Also _r64 synonym
        { 0x40, _rw | _i64_bit | _16_bit,  _r16 | _plus_r },
        { 0x40, _rd | _i64_bit | _32_bit,  _r32 | _plus_r },
        { ASM_END, 0, 0 }
};
// INT and INT 3
PTRNTAB1 aptb1INT[]= /* INT */ {
        { 0xcc, 3,              0 },    // The ulFlags here are meant to
                                        // be the value of the immediate
                                        // operand
        { 0xcd, 0,              _imm8 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1INVLPG[] = /* INVLPG */ {         // 486 only instruction
        { 0x0f01,       _I386|_7, _m8 | _m16 | _m32 | _m48 },
        { ASM_END, 0, 0 }
};

#define OPTABLE(str,op) \
PTRNTAB1 aptb1##str[] = {                    \
        { 0x70|op,   _cb,         _rel8 },   \
        { 0x0f80|op, _cw|_i64_bit,_rel16 },  \
        { 0x0f80|op, _cd,         _rel32 },  \
        { ASM_END, 0, 0 }                    \
}

OPTABLE(JO,0);
OPTABLE(JNO,1);
OPTABLE(JB,2);
OPTABLE(JNB,3);
OPTABLE(JZ,4);
OPTABLE(JNZ,5);
OPTABLE(JBE,6);
OPTABLE(JNBE,7);
OPTABLE(JS,8);
OPTABLE(JNS,9);
OPTABLE(JP,0xA);
OPTABLE(JNP,0xB);
OPTABLE(JL,0xC);
OPTABLE(JNL,0xD);
OPTABLE(JLE,0xE);
OPTABLE(JNLE,0xF);

#undef OPTABLE

PTRNTAB1 aptb1JCXZ[] = /* JCXZ */ {
        { 0xe3, _cb | _i64_bit | _16_bit_addr, _rel8 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1JECXZ[] = /* JECXZ */ {
        { 0xe3, _cb | _32_bit_addr | _I386,_rel8 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1JMP[] = /* JMP */ {
        { 0xe9, _cw| _i64_bit,           _rel16 },
        { 0xe9, _cd,                     _rel32 },
        { 0xeb, _cb,                     _rel8  },
        { 0xff, _4 | _i64_bit | _16_bit, _rm16  },
        { 0xea, _cd| _i64_bit,           _p1616 },
        { 0xff, _5,                      _m1616 },
        { 0xff, _4 | _i64_bit | _32_bit, _rm32  },
        { 0xff, _4 |            _64_bit, _rm64  },       // TODO REX_W override is implicit
        { 0xea, _cp| _i64_bit,          _p1632  },
        { 0xff, _5,                     _m1632  },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1LGDT[] = /* LGDT */ {
        { 0x0f01,       _2,     _m48 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1LIDT[] = /* LIDT */ {
        { 0x0f01,       _3,     _m48 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1LLDT[] = /* LLDT */ {
        { 0x0f00,       _2|_modnot1,    _rm16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1LMSW[] = /* LMSW */ {
        { 0x0f01,       _6|_modnot1,    _rm16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1LODS[] = /* LODS */ {
        { 0xac, _modax,_m8 },
        { 0xad, _16_bit | _modax,_m16 },
        { 0xad, _32_bit | _I386 | _modax,_m32 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1LOOP[] = /* LOOP */ {
        { 0xe2, _cb | _modcx,_rel8 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1LOOPE[] = /* LOOPE/LOOPZ */ {
        { 0xe1, _cb | _modcx,_rel8 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1LOOPNE[] = /* LOOPNE/LOOPNZ */ {
        { 0xe0, _cb | _modcx,_rel8 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1LTR[] = /* LTR */ {
        { 0x0f00,       _3|_modnot1,    _rm16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1NEG[] = /* NEG */ {
        { 0xf6, _3,     _rm8 },
        { 0xf7, _3 | _16_bit,   _rm16 },
        { 0xf7, _3 | _32_bit,   _rm32 },
        { 0xf7, _3 | _64_bit,   _rm64 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1NOT[] = /* NOT */ {
        { 0xf6, _2,     _rm8 },
        { 0xf7, _2 | _16_bit,   _rm16 },
        { 0xf7, _2 | _32_bit,   _rm32 },
        { 0xf7, _2 | _64_bit,   _rm64 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1POP[] = /* POP */ {
        { 0x8f, _0  |            _16_bit, _m16 },
        { 0x8f, _0  | _i64_bit | _32_bit, _m32 },
        { 0x8f, _0  |            _64_bit, _m64 },                 // TODO REX_W override is implicit
        { 0x58, _rw |            _16_bit, _r16 | _plus_r },
        { 0x58, _rd | _i64_bit | _32_bit, _r32 | _plus_r },
        { 0x58, _r  |            _32_bit, _r64 | _plus_r },       // REX_W override is implicit
        { 0x1f,       _i64_bit,            _ds | _seg },
        { 0x07,       _i64_bit | _modes,   _es | _seg },
        { 0x17,       _i64_bit,            _ss | _seg },
        { 0x0fa1,       0,                 _fs | _seg },
        { 0x0fa9,       0,                 _gs | _seg },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1PUSH[] = /* PUSH */ {
        { 0xff, _6 |            _16_bit,  _m16 },
        { 0xff, _6 | _i64_bit | _32_bit,  _m32 },
        { 0xff, _6 |            _64_bit,  _m64 },                // TODO REX_W override is implicit
        { 0x50, _r |            _16_bit, _r16 | _plus_r },
        { 0x50, _r | _i64_bit | _32_bit, _r32 | _plus_r },
        { 0x50, _r |            _32_bit, _r64 | _plus_r },       // REX_W override is implicit
        { 0x6a,       0,_imm8 },
        { 0x68, _16_bit,_imm16 },
        { 0x68, _16_bit,_rel16 },
        { 0x68, _32_bit,_imm32 },
        { 0x68, _32_bit,_rel32 },
        { 0x0e, _i64_bit,_cs | _seg  },
        { 0x16, _i64_bit,_ss | _seg  },
        { 0x1e, _i64_bit,_ds | _seg  },
        { 0x06, _i64_bit,_es | _seg  },
        { 0x0fa0,      0,_fs | _seg},
        { 0x0fa8,      0,_gs | _seg},
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1RET[] = /* RET */ {
        { 0xc3, 0,      0 },
        { 0xc2, _iw,    _imm16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1RETF[] = /* RETF */ {
        { 0xcb, 0, 0 },
        { 0xca, _iw, _imm16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1 aptb1SCAS[] = /* SCAS */ {
        { 0xae, _moddi, _m8 },
        { 0xaf, _16_bit | _moddi, _m16 },
        { 0xaf, _32_bit | _moddi, _m32 },
        { ASM_END, 0, 0 }
};

#define OPTABLE(str,op) \
PTRNTAB1 aptb1##str[] = {       \
        { 0xf90|op, _cb, _rm8 },        \
        { ASM_END, 0, 0 }       \
}

OPTABLE(SETO,0);
OPTABLE(SETNO,1);
OPTABLE(SETB,2);
OPTABLE(SETNB,3);
OPTABLE(SETZ,4);
OPTABLE(SETNZ,5);
OPTABLE(SETBE,6);
OPTABLE(SETNBE,7);
OPTABLE(SETS,8);
OPTABLE(SETNS,9);
OPTABLE(SETP,0xA);
OPTABLE(SETNP,0xB);
OPTABLE(SETL,0xC);
OPTABLE(SETNL,0xD);
OPTABLE(SETLE,0xE);
OPTABLE(SETNLE,0xF);

#undef OPTABLE

PTRNTAB1  aptb1SGDT[]= /* SGDT */ {
        { 0xf01, _0, _m48 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1SIDT[] = /* SIDT */ {
        { 0xf01, _1, _m48 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1SLDT[] = /* SLDT */ {
        { 0xf00, _0, _rm16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1SMSW[] = /* SMSW */ {
        { 0xf01, _4, _rm16 },
        { 0xf01, _4, _r32 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1STOS[] = /* STOS */ {
        { 0xaa, _moddi, _m8 },
        { 0xab, _16_bit | _moddi, _m16 },
        { 0xab, _32_bit | _moddi, _m32 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1STR[] = /* STR */ {
        { 0xf00, _1, _rm16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1VERR[] = /* VERR */ {
        { 0xf00, _4|_modnot1, _rm16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1VERW[] = /* VERW */ {
        { 0xf00, _5|_modnot1, _rm16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1XLAT[] = /* XLAT */ {
        { 0xd7, _modax, 0 },
        { 0xd7, _modax, _m8 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1CMPXCH8B[] = {
    { 0x0fc7, _1 | _modaxdx | _I386, _m64 },
        { ASM_END, 0, 0 }
};

PTRNTAB1  aptb1CMPXCH16B[] = {
    { 0x0fc7, _1 | _modaxdx | _64_bit, _m64 },
        { ASM_END, 0, 0 }
};

#define OPTABLE(str,op,rr,m) \
PTRNTAB2  aptb2##str[] = {                                      \
        { op+4,  _ib|m,                _al,        _imm8 },     \
        { 0x83, rr|_ib|_16_bit|m,     _rm16,      _imm8 },      \
        { op+5, _iw|_16_bit|m,        _ax,        _imm16 },     \
        { 0x83, rr|_ib|_32_bit|m,     _rm32,      _imm8 },      \
        { 0x83, rr|_ib|_64_bit|m,     _rm64,      _imm8 },      \
        { op+5, _id|_32_bit|m,        _eax,       _imm32 },     \
        { op+5, _id|_64_bit|m,        _rax,       _imm32 },     \
        { 0x80, rr|_ib|m,             _rm8,       _imm8 },      \
        { 0x81, rr|_iw|_16_bit|m,     _rm16,      _imm16 },     \
        { 0x81, rr|_id|_32_bit|m,     _rm32,      _imm32 },     \
        { 0x81, rr|_id|_64_bit|m,     _rm64,      _imm32 },     \
        { op+0, _r|m,                 _rm8,       _r8 },        \
        { op+1, _r|_16_bit|m,         _rm16,      _r16 },       \
        { op+1, _r|_32_bit|m,         _rm32,      _r32 },       \
        { op+1, _r|_64_bit|m,         _rm64,      _r64 },       \
        { op+2, _r|m,                 _r8,        _rm8 },       \
        { op+3, _r|_16_bit|m,         _r16,       _rm16 },      \
        { op+3, _r|_32_bit|m,         _r32,       _rm32 },      \
        { op+3, _r|_64_bit|m,         _r64,       _rm64 },      \
        { ASM_END, 0, 0, 0 }                                    \
}

OPTABLE(ADD,0x00,_0,0);
OPTABLE(OR, 0x08,_1,0);
OPTABLE(ADC,0x10,_2,0);
OPTABLE(SBB,0x18,_3,0);
OPTABLE(AND,0x20,_4,0);
OPTABLE(SUB,0x28,_5,0);
OPTABLE(XOR,0x30,_6,0);
OPTABLE(CMP,0x38,_7,_modnot1);

#undef OPTABLE

PTRNTAB2  aptb2ARPL[] = /* ARPL */ {
        { 0x63, _r|_i64_bit,               _rm16, _r16 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2BOUND[] = /* BOUND */ {
        { 0x62, _r|_i64_bit|_16_bit|_modnot1,_r16,_m16 },// Should really b3 _m16_16
        { 0x62, _r|_i64_bit|_32_bit|_modnot1,_r32,_m32 },// Should really be _m32_32
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2BSF[] = /* BSF */ {
        { 0x0fbc,       _cw | _16_bit,          _r16,   _rm16 },
        { 0x0fbc,       _cd|_32_bit,            _r32,   _rm32 },
        { 0x0fbc,       _cd|_64_bit,            _r64,   _rm64 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2BSR[] = /* BSR */ {
        { 0x0fbd,       _cw|_16_bit,            _r16,   _rm16 },
        { 0x0fbd,       _cd|_32_bit,            _r32,   _rm32 },
        { 0x0fbd,       _cd|_64_bit,            _r64,   _rm64 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2BT[] = /* BT */ {
        { 0x0fa3,       _cw|_16_bit|_modnot1,           _rm16,  _r16 },
        { 0x0fa3,       _cd|_32_bit|_modnot1,           _rm32,  _r32 },
        { 0x0fa3,       _cd|_64_bit|_modnot1,           _rm64,  _r64 },
        { 0x0fba,       _4|_ib|_16_bit|_modnot1,        _rm16,  _imm8 },
        { 0x0fba,       _4|_ib|_32_bit|_modnot1,        _rm32,  _imm8 },
        { 0x0fba,       _4|_ib|_64_bit|_modnot1,        _rm64,  _imm8 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2BTC[] = /* BTC */ {
        { 0x0fbb,       _cw|_16_bit,            _rm16,  _r16 },
        { 0x0fbb,       _cd|_32_bit,            _rm32,  _r32 },
        { 0x0fbb,       _cd|_64_bit,            _rm64,  _r64 },
        { 0x0fba,       _7|_ib|_16_bit, _rm16,  _imm8 },
        { 0x0fba,       _7|_ib|_32_bit, _rm32,  _imm8 },
        { 0x0fba,       _7|_ib|_64_bit, _rm64,  _imm8 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2BTR[] = /* BTR */ {
        { 0x0fb3,       _cw|_16_bit,            _rm16,  _r16 },
        { 0x0fb3,       _cd|_32_bit,            _rm32,  _r32 },
        { 0x0fb3,       _cd|_64_bit,            _rm64,  _r64 },
        { 0x0fba,       _6|_ib|_16_bit,         _rm16,  _imm8 },
        { 0x0fba,       _6|_ib|_32_bit,         _rm32,  _imm8 },
        { 0x0fba,       _6|_ib|_64_bit,         _rm64,  _imm8 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2BTS[] = /* BTS */ {
        { 0x0fab,       _cw|_16_bit,            _rm16,  _r16 },
        { 0x0fab,       _cd|_32_bit,            _rm32,  _r32 },
        { 0x0fab,       _cd|_64_bit,            _rm64,  _r64 },
        { 0x0fba,       _5|_ib|_16_bit,         _rm16,  _imm8 },
        { 0x0fba,       _5|_ib|_32_bit,         _rm32,  _imm8 },
        { 0x0fba,       _5|_ib|_64_bit,         _rm64,  _imm8 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2CMPS[] = /* CMPS */ {
        { 0xa6, _modsidi,               _m8,    _m8 },
        { 0xa7, _modsidi,       _m16,   _m16 },
        { 0xa7, _modsidi,       _m32,   _m32 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2CMPXCHG[] = /* CMPXCHG */ {
        { 0xfb0, _I386 | _cb|_mod2,     _rm8,   _r8 },
                                                // This is really a 486 only
                                                // instruction
        { 0xfb1, _I386 | _cw | _16_bit|_mod2,   _rm16,  _r16 },
        { 0xfb1, _I386 | _cd | _32_bit|_mod2,   _rm32,  _r32 },
        { 0xfb1, _I386 | _cq | _64_bit|_mod2,   _rm64,  _r64 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2DIV[] = /* DIV */ {
        { 0xf6, _6,                             _al,            _rm8 },
        { 0xf7, _6 | _16_bit | _moddx,          _ax,            _rm16 },
        { 0xf7, _6 | _32_bit | _moddx,          _eax,           _rm32 },
        { 0xf7, _6 | _64_bit | _moddx,          _rax,           _rm64 },
        { 0xf6, _6 | _modax,                    _rm8,           0 },
        { 0xf7, _6 | _16_bit | _modaxdx,        _rm16,          0 },
        { 0xf7, _6 | _32_bit | _modaxdx,        _rm32,          0 },
        { 0xf7, _6 | _64_bit | _modaxdx,        _rm64,          0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2ENTER[] = /* ENTER */ {
        { 0xc8, _iw|_ib,        _imm16, _imm8 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2IDIV[] = /* IDIV */ {
        { 0xf6, _7,                     _al,            _rm8 },
        { 0xf7, _7|_16_bit|_moddx,      _ax,            _rm16 },
        { 0xf7, _7|_32_bit|_moddx,      _eax,           _rm32 },
        { 0xf7, _7|_64_bit|_moddx,      _rax,           _rm64 },
        { 0xf6, _7 | _modax,            _rm8,           0 },
        { 0xf7, _7|_16_bit|_modaxdx,    _rm16,          0 },
        { 0xf7, _7|_32_bit|_modaxdx,    _rm32,          0 },
        { 0xf7, _7|_64_bit|_modaxdx,    _rm64,          0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2IN[] = /* IN */ {
        { 0xe4, _ib,        _al,                _imm8 },
        { 0xe5, _ib|_16_bit,_ax,                _imm8 },
        { 0xe5, _ib|_32_bit,_eax,       _imm8 },
        { 0xec, 0,          _al,                _dx },
        { 0xed, _16_bit,    _ax,                _dx },
        { 0xed, _32_bit,    _eax,       _dx },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2INS[] = /* INS */ {
        { 0x6c, _modsi, _rm8, _dx },
        { 0x6d, _modsi|_16_bit, _rm16, _dx },
        { 0x6d, _32_bit|_modsi, _rm32, _dx },
        { ASM_END, 0, 0, 0 }
};

PTRNTAB2  aptb2LAR[] = /* LAR */ {
        { 0x0f02,       _r|_16_bit,                     _r16,   _rm16 },
        { 0x0f02,       _r|_32_bit,                     _r32,   _rm32 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2LDS[] = /* LDS */ {
        { 0xc5, _r|_i64_bit|_16_bit,                    _r16,   _m32 },
        { 0xc5, _r|_i64_bit|_32_bit,                    _r32,   _m48 },
        { ASM_END, 0, 0, 0 }
};

PTRNTAB2  aptb2LEA[] = /* LEA */ {
        { 0x8d, _r|_16_bit,             _r16,   _m8 | _m16 | _m32 | _m48 },
        { 0x8d, _r|_32_bit,             _r32,   _m8 | _m16 | _m32 | _m48 },
        { 0x8d, _r|_64_bit,             _r64,   _m8 | _m16 | _m32 | _m48 | _m64 },
        { 0x8d, _r|_16_bit,             _r16,   _rel16 },
        { 0x8d, _r|_32_bit,             _r32,   _rel32 },
        { 0x8d, _r|_64_bit,             _r64,   _rel32 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2LES[] = /* LES */ {
        { 0xc4, _r|_i64_bit|_16_bit|_modes,             _r16,   _m32 },
        { 0xc4, _r|_i64_bit|_32_bit|_modes,             _r32,   _m48 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2LFS[] = /* LFS */ {
        { 0x0fb4,       _r|_16_bit,                     _r16,   _m32 },
        { 0x0fb4,       _r|_32_bit,                     _r32,   _m48 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2LGS[] = /* LGS */ {
        { 0x0fb5,       _r|_16_bit,                     _r16,   _m32  },
        { 0x0fb5,       _r|_32_bit,                     _r32,   _m48 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2LSS[] = /* LSS */ {
        { 0x0fb2,       _r|_16_bit,                     _r16,   _m32 },
        { 0x0fb2,       _r|_32_bit,                     _r32,   _m48 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2LSL[] = /* LSL */ {
        { 0x0f03,       _r|_16_bit,                     _r16,   _rm16 },
        { 0x0f03,       _r|_32_bit,                     _r32,   _rm32 },
        { ASM_END, 0, 0, 0 }
};

PTRNTAB2 aptb2MOV[] = /* MOV */ {
#if 0 // Let pinholeopt() do this
        { 0xa0, 0,              _al,            _moffs8         },
        { 0xa1, _16_bit,        _ax,            _moffs16        },
        { 0xa1, _32_bit,        _eax,           _moffs32        },
        { 0xa2, 0,              _moffs8,        _al             },
        { 0xa3, _16_bit,        _moffs16,       _ax             },
        { 0xa3, _32_bit,        _moffs32,       _eax            },
#endif
        { 0x88, _r,             _rm8,           _r8             },
        { 0x89, _r|_16_bit,     _rm16,          _r16            },
        { 0x89, _r|_32_bit,     _rm32,          _r32            },
        { 0x89, _r|_64_bit,     _rm64,          _r64            },
        { 0x8a, _r,             _r8,            _rm8            },
        { 0x8b, _r|_16_bit,     _r16,           _rm16           },
        { 0x8b, _r|_32_bit,     _r32,           _rm32           },
        { 0x8b, _r|_64_bit,     _r64,           _rm64           },
        { 0x8c, _r,             _rm16,          _seg|_ds|_es| _ss | _fs | _gs | _cs },
        { 0x8e, _r,             _seg|_ds|_es|_ss|_fs|_gs|_cs,   _rm16 },
        { 0xb0, _rb,            _r8 | _plus_r,  _imm8           },
        { 0xb8, _rw | _16_bit,  _r16 | _plus_r, _imm16          },
        { 0xb8, _rd|_32_bit,    _r32 | _plus_r, _imm32          },
        { 0xb8, _rd|_64_bit,    _r64 | _plus_r, _imm64          },
        { 0xc6, _cb,            _rm8,           _imm8           },
        { 0xc7, _cw|_16_bit,    _rm16,          _imm16          },
        { 0xc7, _cd|_32_bit,    _rm32,          _imm32          },
#if 0 // Let pinholeopt() do this
        { 0xc6, _cb,            _moffs8,        _imm8           },
        { 0xc7, _cw|_16_bit,    _moffs16,       _imm16          },
        { 0xc7, _cd|_32_bit,    _moffs32,       _imm32          },
#endif
        { 0x0f20,       _r,     _r32,           _special | _crn },
        { 0x0f22,       _r,     _special|_crn,  _r32            },
        { 0x0f21,       _r,     _r32,           _special | _drn },
        { 0x0f23,       _r,     _special|_drn,  _r32            },
        { 0x0f24,       _r,     _r32,           _special | _trn },
        { 0x0f26,       _r,     _special|_trn,  _r32            },
        { ASM_END, 0, 0, 0 }
};

PTRNTAB2  aptb2MOVS[] = {
        { 0xa4, _modsidi ,              _m8,    _m8 },
        { 0xa5, _modsidi | _16_bit,     _m16,   _m16 },
        { 0xa5, _modsidi | _32_bit,     _m32,   _m32 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2MOVSX[] = {
        { 0x0fbe,       _r|_16_bit,                     _r16,   _rm8 },
        { 0x0fbe,       _r|_32_bit,                     _r32,   _rm8 },
#if 1
        { 0x0fbf,       _r|_16_bit,             _r16,   _rm16 },
        { 0x0fbf,       _r|_32_bit,             _r32,   _rm16 },
#else
        { 0x0fbf,       _r,                     _r32,   _rm16 },
#endif
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2MOVZX[] = /* MOVZX */ {
        { 0x0fb6,       _r|_16_bit,                     _r16,   _rm8 },
        { 0x0fb6,       _r|_32_bit,                     _r32,   _rm8 },
#if 1
        { 0x0fb7,       _r|_16_bit,             _r16,   _rm16 },
        { 0x0fb7,       _r|_32_bit,             _r32,   _rm16 },
#else
        { 0x0fb7,       _r,                     _r32,   _rm16 },
#endif
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2MUL[] = /* MUL */ {
        { 0xf6, _4,                     _al,    _rm8 },
        { 0xf7, _4|_16_bit|_moddx,      _ax,    _rm16 },
        { 0xf7, _4|_32_bit|_moddx,      _eax,   _rm32 },
        { 0xf7, _4|_64_bit|_moddx,      _rax,   _rm64 },
        { 0xf6, _4|_modax,              _rm8,   0 },
        { 0xf7, _4|_16_bit|_modaxdx,    _rm16,  0 },
        { 0xf7, _4|_32_bit|_modaxdx,    _rm32,  0 },
        { 0xf7, _4|_64_bit|_modaxdx,    _rm64,  0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2OUT[] = {
        { 0xe6, _ib,            _imm8,  _al },
        { 0xe7, _ib|_16_bit,            _imm8,  _ax },
        { 0xe7, _ib|_32_bit,            _imm8,  _eax },
        { 0xee, _modnot1,               _dx,            _al },
        { 0xef, _16_bit|_modnot1,               _dx,            _ax },
        { 0xef, _32_bit|_modnot1,               _dx,            _eax },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2OUTS[] = /* OUTS */ {
        { 0x6e, _modsinot1,             _dx,            _rm8 },
        { 0x6f, _16_bit | _I386 |_modsinot1,    _dx,            _rm16 },
        { 0x6f, _32_bit | _I386| _modsinot1,    _dx,            _rm32 },
        { ASM_END, 0, 0, 0 }
};

#define OPTABLE(str,op) \
PTRNTAB2  aptb2##str[] = {      \
        { 0xd2, op,             _rm8,   _cl },  \
        { 0xc0, op|_ib,         _rm8,   _imm8 },        \
        { 0xd3, op|_16_bit,     _rm16,  _cl },  \
        { 0xc1, op|_ib|_16_bit, _rm16,  _imm8 },        \
        { 0xd3, op|_32_bit,     _rm32,  _cl },  \
        { 0xc1, op|_ib|_32_bit, _rm32,  _imm8, },       \
        { 0xd3, op|_64_bit,     _rm64,  _cl },  \
        { 0xc1, op|_ib|_64_bit, _rm64,  _imm8, },       \
        { ASM_END, 0, 0, 0 }    \
}

OPTABLE(ROL,_0);
OPTABLE(ROR,_1);
OPTABLE(RCL,_2);
OPTABLE(RCR,_3);
OPTABLE(SHL,_4);
OPTABLE(SHR,_5);
OPTABLE(SAR,_7);

#undef OPTABLE

PTRNTAB2  aptb2TEST[] = /* TEST */ {
        { 0xa8, _ib|_modnot1,           _al,    _imm8 },
        { 0xa9, _iw|_16_bit|_modnot1,   _ax,    _imm16 },
        { 0xa9, _id|_32_bit|_modnot1,   _eax,   _imm32 },
        { 0xa9, _id|_64_bit|_modnot1,   _rax,   _imm32 },
        { 0xf6, _0|_modnot1,            _rm8,   _imm8 },
        { 0xf7, _0|_16_bit|_modnot1,    _rm16,  _imm16 },
        { 0xf7, _0|_32_bit|_modnot1,    _rm32,  _imm32 },
        { 0xf7, _0|_64_bit|_modnot1,    _rm64,  _imm32 },
        { 0x84, _r|_modnot1,            _rm8,   _r8 },
        { 0x85, _r|_16_bit|_modnot1,    _rm16,  _r16 },
        { 0x85, _r|_32_bit|_modnot1,    _rm32,  _r32 },
        { 0x85, _r|_64_bit|_modnot1,    _rm64,  _r64 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2XADD[] = /* XADD */ {                    // 486 only instruction
//      { 0x0fc0,       _ib | _I386|_mod2, _rm8, _r8 },
//      { 0x0fc1,       _iw | _I386|_16_bit|_mod2, _rm16, _r16 },
//      { 0x0fc1,       _id | _I386|_32_bit|_mod2, _rm32, _r32 },
        { 0x0fc0,       _r | _I386|_mod2, _rm8, _r8 },
        { 0x0fc1,       _r | _I386|_16_bit|_mod2, _rm16, _r16 },
        { 0x0fc1,       _r | _I386|_32_bit|_mod2, _rm32, _r32 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2XCHG[] = /* XCHG */ {
        { 0x90, _r|_16_bit|_mod2,       _ax ,   _r16 | _plus_r },
        { 0x90, _r|_16_bit|_mod2,       _r16 | _plus_r, _ax  },
        { 0x90, _r|_32_bit|_mod2,       _eax,   _r32 | _plus_r },
        { 0x90, _r|_32_bit|_mod2,       _r32 | _plus_r, _eax },
        { 0x86, _r|_mod2,               _rm8,   _r8 },
        { 0x86, _r|_mod2,               _r8,    _rm8 },
        { 0x87, _r|_16_bit|_mod2,               _rm16,  _r16 },
        { 0x87, _r|_16_bit|_mod2,               _r16, _rm16 },
        { 0x87, _r|_32_bit|_mod2,               _rm32,  _r32 },
        { 0x87, _r|_32_bit|_mod2,               _r32, _rm32 },
        { 0x87, _r|_64_bit|_mod2,               _rm64,  _r64 },
        { 0x87, _r|_64_bit|_mod2,               _r64, _rm64 },
        { ASM_END, 0, 0, 0 }
};

#define OPTABLE(str,op) \
PTRNTAB2  aptb2##str[] = {      \
        { 0x0F40|op, _r|_16_bit,   _r16,   _rm16 },     \
        { 0x0F40|op, _r|_32_bit,   _r32,   _rm32 },     \
        { 0x0F40|op, _r|_64_bit,   _r64,   _rm64 },     \
        { ASM_END, 0, 0, 0 }    \
}

OPTABLE(CMOVO,0);
OPTABLE(CMOVNO,1);
OPTABLE(CMOVB,2);
OPTABLE(CMOVNB,3);
OPTABLE(CMOVZ,4);
OPTABLE(CMOVNZ,5);
OPTABLE(CMOVBE,6);
OPTABLE(CMOVNBE,7);
OPTABLE(CMOVS,8);
OPTABLE(CMOVNS,9);
OPTABLE(CMOVP,0xA);
OPTABLE(CMOVNP,0xB);
OPTABLE(CMOVL,0xC);
OPTABLE(CMOVNL,0xD);
OPTABLE(CMOVLE,0xE);
OPTABLE(CMOVNLE,0xF);

#undef OPTABLE

PTRNTAB3  aptb3IMUL[] = /* IMUL */ {
        { 0x0faf,       _r|_16_bit,             _r16,   _rm16, 0 },
        { 0x0faf,       _r|_32_bit,             _r32,   _rm32, 0 },
        { 0x0faf,       _r|_64_bit,             _r64,   _rm64, 0 },
        { 0xf6, _5|_modax,                      _rm8,   0, 0 },
        { 0xf7, _5|_16_bit|_modaxdx,            _rm16,  0, 0 },
        { 0xf7, _5|_32_bit|_modaxdx,            _rm32,  0, 0 },
        { 0xf7, _5|_64_bit|_modaxdx,            _rm64,  0, 0 },
        { 0x6b, _r|_ib|_16_bit,         _r16,   _imm8, 0 },
        { 0x6b, _r|_ib|_32_bit,         _r32,   _imm8, 0 },
        { 0x69, _r|_iw|_16_bit,         _r16,   _imm16, 0 },
        { 0x69, _r|_id|_32_bit,         _r32,   _imm32, 0 },
        { 0x69, _r|_id|_64_bit,         _r64,   _imm32, 0 },
        { 0x6b, _r|_ib|_16_bit,         _r16,   _rm16,  _imm8 },
        { 0x6b, _r|_ib|_32_bit,         _r32,   _rm32,  _imm8 },
        { 0x6b, _r|_ib|_64_bit,         _r64,   _rm64,  _imm8 },
        { 0x69, _r|_iw|_16_bit,         _r16,   _rm16,  _imm16 },
        { 0x69, _r|_id|_32_bit,         _r32,   _rm32,  _imm32 },
        { 0x69, _r|_id|_64_bit,         _r64,   _rm64,  _imm32 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB3  aptb3SHLD[] = /* SHLD */ {
        { 0x0fa4,       _cw|_16_bit, _rm16, _r16, _imm8 },
        { 0x0fa4,       _cd|_32_bit, _rm32, _r32, _imm8 },
        { 0x0fa5,       _cw|_16_bit, _rm16, _r16, _cl },
        { 0x0fa5,       _cd|_32_bit, _rm32, _r32, _cl },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB3  aptb3SHRD[] = /* SHRD */ {
        { 0x0fac,       _cw|_16_bit, _rm16, _r16, _imm8 },
        { 0x0fac,       _cd|_32_bit, _rm32, _r32, _imm8 },
        { 0x0fad,       _cw|_16_bit, _rm16, _r16, _cl },
        { 0x0fad,       _cd|_32_bit, _rm32, _r32, _cl },
        { ASM_END, 0, 0, 0 }
};
//
// Floating point instructions which have entirely different flag
// interpretations
//

OPTABLE0(F2XM1,    0xd9f0,0);
OPTABLE0(FABS,     0xd9e1,0);
OPTABLE0(FCHS,     0xd9e0,0);
OPTABLE0(FCLEX,    0xdbe2,_fwait);
OPTABLE0(FNCLEX,   0xdbe2, _nfwait);
OPTABLE0(FCOMPP,   0xded9, 0);
OPTABLE0(FCOS,     0xd9ff, 0);
OPTABLE0(FUCOMPP,  0xdae9, 0);
OPTABLE0(FDECSTP,  0xd9f6, 0);
OPTABLE0(FINCSTP,  0xd9f7, 0);
OPTABLE0(FINIT,    0xdbe3, _fwait);
OPTABLE0(FNINIT,   0xdbe3, _nfwait);
OPTABLE0(FENI,     0xdbe0, _fwait);
OPTABLE0(FNENI,    0xdbe0, _nfwait);
OPTABLE0(FDISI,    0xdbe1, _fwait);
OPTABLE0(FNDISI,   0xdbe1, _nfwait);
OPTABLE0(FLD1,     0xd9e8, 0);
OPTABLE0(FLDL2T,   0xd9e9, 0);
OPTABLE0(FLDL2E,   0xd9ea, 0);
OPTABLE0(FLDPI,    0xd9eb, 0);
OPTABLE0(FLDLG2,   0xd9ec, 0);
OPTABLE0(FLDLN2,   0xd9ed, 0);
OPTABLE0(FLDZ,     0xd9ee, 0);
OPTABLE0(FNOP,     0xd9d0, 0);
OPTABLE0(FPATAN,   0xd9f3, 0);
OPTABLE0(FPREM,    0xd9f8, 0);
OPTABLE0(FPREM1,   0xd9f5, 0);
OPTABLE0(FPTAN,    0xd9f2, 0);
OPTABLE0(FRNDINT,  0xd9fc, 0);
OPTABLE0(FSCALE,   0xd9fd, 0);
OPTABLE0(FSETPM,   0xdbe4, 0);
OPTABLE0(FSIN,     0xd9fe, 0);
OPTABLE0(FSINCOS,  0xd9fb, 0);
OPTABLE0(FSQRT,    0xd9fa, 0);
OPTABLE0(FTST,     0xd9e4, 0);
OPTABLE0(FWAIT,    0x9b, 0);
OPTABLE0(FXAM,     0xd9e5, 0);
OPTABLE0(FXTRACT,  0xd9f4, 0);
OPTABLE0(FYL2X,    0xd9f1, 0);
OPTABLE0(FYL2XP1,  0xd9f9, 0);
//
// Floating point instructions which have entirely different flag
// interpretations but they overlap, only asm_determine_operator
// flags needs to know the difference
//      1 operand floating point instructions follow
//
PTRNTAB1  aptb1FBLD[] = /* FBLD */ {
        { 0xdf, _4, _fm80 },
        { ASM_END, 0, 0 }
};

PTRNTAB1  aptb1FBSTP[] = /* FBSTP */ {
        { 0xdf, _6, _fm80 },
        { ASM_END, 0, 0 }
};
PTRNTAB2  aptb2FCMOVB[] = /* FCMOVB */ {
        { 0xdac0, 0, _st, _sti | _plus_r },
        { 0xdac1, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB2  aptb2FCMOVE[] = /* FCMOVE */ {
        { 0xdac8, 0, _st, _sti | _plus_r },
        { 0xdac9, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB2  aptb2FCMOVBE[] = /* FCMOVBE */ {
        { 0xdad0, 0, _st, _sti | _plus_r },
        { 0xdad1, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB2  aptb2FCMOVU[] = /* FCMOVU */ {
        { 0xdad8, 0, _st, _sti | _plus_r },
        { 0xdad9, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB2  aptb2FCMOVNB[] = /* FCMOVNB */ {
        { 0xdbc0, 0, _st, _sti | _plus_r },
        { 0xdbc1, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB2  aptb2FCMOVNE[] = /* FCMOVNE */ {
        { 0xdbc8, 0, _st, _sti | _plus_r },
        { 0xdbc9, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB2  aptb2FCMOVNBE[] = /* FCMOVNBE */ {
        { 0xdbd0, 0, _st, _sti | _plus_r },
        { 0xdbd1, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB2  aptb2FCMOVNU[] = /* FCMOVNU */ {
        { 0xdbd8, 0, _st, _sti | _plus_r },
        { 0xdbd9, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FCOM[] = /* FCOM */ {
        { 0xd8, _2, _m32 },
        { 0xdc, _2, _fm64 },
        { 0xd8d0, 0, _sti | _plus_r },
        { 0xd8d1, 0, 0 },
        { ASM_END, 0, 0 }
};

PTRNTAB2  aptb2FCOMI[] = /* FCOMI */ {
        { 0xdbf0, 0, _st, _sti | _plus_r },
        { 0xdbf0, 0, _sti | _plus_r, 0 },
        { 0xdbf1, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FCOMIP[] = /* FCOMIP */ {
        { 0xdff0, 0, _st, _sti | _plus_r },
        { 0xdff0, 0, _sti | _plus_r, 0 },
        { 0xdff1, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FUCOMI[] = /* FUCOMI */ {
        { 0xdbe8, 0, _st, _sti | _plus_r },
        { 0xdbe8, 0, _sti | _plus_r, 0 },
        { 0xdbe9, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FUCOMIP[] = /* FUCOMIP */ {
        { 0xdfe8, 0, _st, _sti | _plus_r },
        { 0xdfe8, 0, _sti | _plus_r, 0 },
        { 0xdfe9, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};

PTRNTAB1  aptb1FCOMP[] = /* FCOMP */ {
        { 0xd8, _3, _m32 },
        { 0xdc, _3, _fm64 },
        { 0xd8d8, 0, _sti | _plus_r },
        { 0xd8d9, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FFREE[] = /* FFREE */ {
        { 0xddc0,       0,      _sti | _plus_r },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FICOM[] = /* FICOM */ {
        { 0xde, _2, _m16 },
        { 0xda, _2, _m32 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FICOMP[] = /* FICOMP */ {
        { 0xde, _3, _m16 },
        { 0xda, _3, _m32 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FILD[] = /* FILD */ {
        { 0xdf, _0, _m16 },
        { 0xdb, _0, _m32 },
        { 0xdf, _5, _fm64 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FIST[] = /* FIST */      {
        { 0xdf, _2, _m16 },
        { 0xdb, _2, _m32 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FISTP[] = /* FISTP */ {
        { 0xdf, _3, _m16 },
        { 0xdb, _3, _m32 },
        { 0xdf, _7, _fm64 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FISTTP[] = /* FISTTP (Pentium 4, Prescott) */ {
        { 0xdf, _1, _m16 },
        { 0xdb, _1, _m32 },
        { 0xdd, _1, _fm64 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FLD[] = /* FLD */ {
        { 0xd9, _0, _m32 },
        { 0xdd, _0, _fm64 },
        { 0xdb, _5, _fm80 },
        { 0xd9c0, 0, _sti | _plus_r },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FLDCW[] = /* FLDCW */ {
        { 0xd9, _5, _m16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FLDENV[] = /* FLDENV */ {
        { 0xd9, _4, _m112 | _m224 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FRSTOR[] = /* FRSTOR */ {
        { 0xdd, _4, _m112 | _m224 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FSAVE[] = /* FSAVE */ {
        { 0xdd, _6 | _fwait, _m112 | _m224 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FNSAVE[] = /* FNSAVE */ {
        { 0xdd, _6 | _nfwait, _m112 | _m224 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FST[] = /* FST */ {
        { 0xd9, _2, _m32 },
        { 0xdd, _2, _fm64 },
        { 0xddd0, 0, _sti | _plus_r },
        { ASM_END, 0, 0 }
};

PTRNTAB1  aptb1FSTP[] = /* FSTP */ {
        { 0xd9, _3, _m32 },
        { 0xdd, _3, _fm64 },
        { 0xdb, _7, _fm80 },
        { 0xddd8, 0, _sti | _plus_r },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FSTCW[] = /* FSTCW */ {
        { 0xd9, _7 | _fwait , _m16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FNSTCW[] = /* FNSTCW */ {
        { 0xd9, _7 | _nfwait , _m16 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FSTENV[] = /* FSTENV */ {
        { 0xd9, _6 | _fwait, _m112 | _m224 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FNSTENV[] = /* FNSTENV */ {
        { 0xd9, _6 | _nfwait, _m112 | _m224 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FSTSW[] = /* FSTSW */ {
        { 0xdd, _7 | _fwait, _m16 },
        { 0xdfe0, _fwait | _modax, _ax },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FNSTSW[] = /* FNSTSW */ {
        { 0xdd, _7 | _nfwait, _m16 },
        { 0xdfe0, _nfwait | _modax, _ax },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FUCOM[] = /* FUCOM */ {
        { 0xdde0, 0, _sti | _plus_r },
        { 0xdde1, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FUCOMP[] = /* FUCOMP */ {
        { 0xdde8, 0, _sti | _plus_r },
        { 0xdde9, 0, 0 },
        { ASM_END, 0, 0 }
};
PTRNTAB1  aptb1FXCH[] = /* FXCH */ {
        { 0xd9c8, 0, _sti | _plus_r },
        { 0xd9c9, 0, 0 },
        { ASM_END, 0, 0 }
};
//
// Floating point instructions which have entirely different flag
// interpretations but they overlap, only asm_determine_operator
// flags needs to know the difference
//      2 operand floating point instructions follow
//
PTRNTAB2  aptb2FADD[] = /* FADD */ {
        { 0xd8, _0, _m32, 0 },
        { 0xdc, _0, _fm64, 0 },
        { 0xd8c0, 0, _st, _sti | _plus_r },
        { 0xdcc0, 0, _sti | _plus_r, _st },
        { 0xdec1, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};

PTRNTAB2  aptb2FADDP[] = /* FADDP */ {
        { 0xdec0, 0, _sti | _plus_r, _st },
        { 0xdec1, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FIADD[] = /* FIADD */ {
        { 0xda, _0, _m32, 0 },
        { 0xde, _0, _m16, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FDIV[] = /* FDIV */ {
        { 0xd8, _6, _m32, 0 },
        { 0xdc, _6, _fm64, 0 },
        { 0xd8f0, 0, _st, _sti | _plus_r },
        { 0xdcf8, 0, _sti | _plus_r, _st },
        { 0xdef9, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FDIVP[] = /* FDIVP */ {
        { 0xdef9, 0, 0, 0 },
        { 0xdef8, 0, _sti | _plus_r, _st },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FIDIV[] = /* FIDIV */ {
        { 0xda, _6,  _m32, 0 },
        { 0xde, _6,  _m16, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FDIVR[] = /* FDIVR */ {
        { 0xd8, _7, _m32, 0 },
        { 0xdc, _7, _fm64, 0 },
        { 0xd8f8, 0, _st, _sti | _plus_r },
        { 0xdcf0, 0, _sti | _plus_r, _st },
        { 0xdef1, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FDIVRP[] = /* FDIVRP */ {
        { 0xdef1, 0, 0, 0 },
        { 0xdef0, 0, _sti | _plus_r, _st },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FIDIVR[] = /* FIDIVR */ {
        { 0xda, _7,  _m32, 0 },
        { 0xde, _7,  _m16, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FMUL[] = /* FMUL */ {
        { 0xd8, _1, _m32, 0 },
        { 0xdc, _1, _fm64, 0 },
        { 0xd8c8, 0, _st, _sti | _plus_r },
        { 0xdcc8, 0, _sti | _plus_r, _st },
        { 0xdec9, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FMULP[] = /* FMULP */ {
        { 0xdec8, 0, _sti | _plus_r, _st },
        { 0xdec9, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FIMUL[] = /* FIMUL */ {
        { 0xda, _1, _m32, 0 },
        { 0xde, _1, _m16, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FSUB[] = /* FSUB */ {
        { 0xd8, _4, _m32, 0 },
        { 0xdc, _4, _fm64, 0 },
        { 0xd8e0, 0, _st, _sti | _plus_r },
        { 0xdce8, 0, _sti | _plus_r, _st },
        { 0xdee9, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FSUBP[] = /* FSUBP */ {
        { 0xdee8, 0, _sti | _plus_r, _st },
        { 0xdee9, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FISUB[] = /* FISUB */ {
        { 0xda, _4, _m32, 0 },
        { 0xde, _4, _m16, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FSUBR[] = /* FSUBR */ {
        { 0xd8, _5, _m32, 0 },
        { 0xdc, _5, _fm64, 0 },
        { 0xd8e8, 0, _st, _sti | _plus_r },
        { 0xdce0, 0, _sti | _plus_r, _st },
        { 0xdee1, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FSUBRP[] = /* FSUBRP */ {
        { 0xdee0, 0, _sti | _plus_r, _st },
        { 0xdee1, 0, 0, 0 },
        { ASM_END, 0, 0, 0 }
};
PTRNTAB2  aptb2FISUBR[] = /* FISUBR */ {
        { 0xda, _5, _m32, 0 },
        { 0xde, _5, _m16, 0 },
        { ASM_END, 0, 0, 0 }
};

///////////////////////////// MMX Extensions /////////////////////////

PTRNTAB0 aptb0EMMS[] = /* EMMS */       {
        { 0x0F77, 0 }
};

PTRNTAB2 aptb2MOVD[] = /* MOVD */ {
        { 0x0F6E,_r,_mm,_rm32 },
        { 0x0F7E,_r,_rm32,_mm },
        { 0x660F6E,_r,_xmm,_rm32 },
        { 0x660F7E,_r,_rm32,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVQ[] = /* MOVQ */ {
        { 0x0F6F,_r,_mm,_mmm64 },
        { 0x0F7F,_r,_mmm64,_mm },
        { 0xF30F7E,_r,_xmm,_xmm_m64 },
        { 0x660FD6,_r,_xmm_m64,_xmm },
        { 0x0F6E,  _r|_64_bit,_mm,  _rm64 },
        { 0x0F7E,  _r|_64_bit,_rm64,_mm   },
        { 0x660F6E,_r|_64_bit,_xmm, _rm64 },
        { 0x660F7E,_r|_64_bit,_rm64,_xmm  },
        { ASM_END }
};

PTRNTAB2 aptb2PACKSSDW[] = {
        { 0x0F6B, _r,_mm,_mmm64 },
        { 0x660F6B, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PACKSSWB[] = {
        { 0x0F63, _r,_mm,_mmm64 },
        { 0x660F63, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PACKUSWB[] = {
        { 0x0F67, _r,_mm,_mmm64 },
        { 0x660F67, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDB[] = {
        { 0x0FFC, _r,_mm,_mmm64 },
        { 0x660FFC, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDD[] = {
        { 0x0FFE, _r,_mm,_mmm64 },
        { 0x660FFE, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDSB[] = {
        { 0x0FEC, _r,_mm,_mmm64 },
        { 0x660FEC, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDSW[] = {
        { 0x0FED, _r,_mm,_mmm64 },
        { 0x660FED, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDUSB[] = {
        { 0x0FDC, _r,_mm,_mmm64 },
        { 0x660FDC, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDUSW[] = {
        { 0x0FDD, _r,_mm,_mmm64 },
        { 0x660FDD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDW[] = {
        { 0x0FFD, _r,_mm,_mmm64 },
        { 0x660FFD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PAND[] = {
        { 0x0FDB, _r,_mm,_mmm64 },
        { 0x660FDB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PANDN[] = {
        { 0x0FDF, _r,_mm,_mmm64 },
        { 0x660FDF, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPEQB[] = {
        { 0x0F74, _r,_mm,_mmm64 },
        { 0x660F74, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPEQD[] = {
        { 0x0F76, _r,_mm,_mmm64 },
        { 0x660F76, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPEQW[] = {
        { 0x0F75, _r,_mm,_mmm64 },
        { 0x660F75, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPGTB[] = {
        { 0x0F64, _r,_mm,_mmm64 },
        { 0x660F64, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPGTD[] = {
        { 0x0F66, _r,_mm,_mmm64 },
        { 0x660F66, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPGTW[] = {
        { 0x0F65, _r,_mm,_mmm64 },
        { 0x660F65, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMADDWD[] = {
        { 0x0FF5, _r,_mm,_mmm64 },
        { 0x660FF5, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSLLW[] = /* PSLLW */ {
        { 0x0FF1, _r,_mm,_mmm64 },
        { 0x0F71, _6,_mm,_imm8 },
        { 0x660FF1, _r,_xmm,_xmm_m128 },
        { 0x660F71, _6,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSLLD[] = /* PSLLD */ {
        { 0x0FF2, _r,_mm,_mmm64 },
        { 0x0F72, _6,_mm,_imm8 },
        { 0x660FF2, _r,_xmm,_xmm_m128 },
        { 0x660F72, _6,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSLLQ[] = /* PSLLQ */ {
        { 0x0FF3, _r,_mm,_mmm64 },
        { 0x0F73, _6,_mm,_imm8 },
        { 0x660FF3, _r,_xmm,_xmm_m128 },
        { 0x660F73, _6,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRAW[] = /* PSRAW */ {
        { 0x0FE1, _r,_mm,_mmm64 },
        { 0x0F71, _4,_mm,_imm8 },
        { 0x660FE1, _r,_xmm,_xmm_m128 },
        { 0x660F71, _4,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRAD[] = /* PSRAD */ {
        { 0x0FE2, _r,_mm,_mmm64 },
        { 0x0F72, _4,_mm,_imm8 },
        { 0x660FE2, _r,_xmm,_xmm_m128 },
        { 0x660F72, _4,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRLW[] = /* PSRLW */ {
        { 0x0FD1, _r,_mm,_mmm64 },
        { 0x0F71, _2,_mm,_imm8 },
        { 0x660FD1, _r,_xmm,_xmm_m128 },
        { 0x660F71, _2,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRLD[] = /* PSRLD */ {
        { 0x0FD2, _r,_mm,_mmm64 },
        { 0x0F72, _2,_mm,_imm8 },
        { 0x660FD2, _r,_xmm,_xmm_m128 },
        { 0x660F72, _2,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRLQ[] = /* PSRLQ */ {
        { 0x0FD3, _r,_mm,_mmm64 },
        { 0x0F73, _2,_mm,_imm8 },
        { 0x660FD3, _r,_xmm,_xmm_m128 },
        { 0x660F73, _2,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBB[] = {
        { 0x0FF8, _r,_mm,_mmm64 },
        { 0x660FF8, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBD[] = {
        { 0x0FFA, _r,_mm,_mmm64 },
        { 0x660FFA, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBSB[] = {
        { 0x0FE8, _r,_mm,_mmm64 },
        { 0x660FE8, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBSW[] = {
        { 0x0FE9, _r,_mm,_mmm64 },
        { 0x660FE9, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBUSB[] = {
        { 0x0FD8, _r,_mm,_mmm64 },
        { 0x660FD8, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBUSW[] = {
        { 0x0FD9, _r,_mm,_mmm64 },
        { 0x660FD9, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBW[] = {
        { 0x0FF9, _r,_mm,_mmm64 },
        { 0x660FF9, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKHBW[] = {
        { 0x0F68, _r,_mm,_mmm64 },
        { 0x660F68, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKHDQ[] = {
        { 0x0F6A, _r,_mm,_mmm64 },
        { 0x660F6A, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKHWD[] = {
        { 0x0F69, _r,_mm,_mmm64 },
        { 0x660F69, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKLBW[] = {
        { 0x0F60, _r,_mm,_mmm64 },
        { 0x660F60, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKLDQ[] = {
        { 0x0F62, _r,_mm,_mmm64 },
        { 0x660F62, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKLWD[] = {
        { 0x0F61, _r,_mm,_mmm64 },
        { 0x660F61, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PXOR[] = {
        { 0x0FEF, _r,_mm,_mmm64 },
        { 0x660FEF, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

////////////////////// New Opcodes /////////////////////////////

#if 0 // Use REP NOP instead
PTRNTAB0 aptb0PAUSE[] =  /* PAUSE */ {
        { 0xf390, 0 }
};
#endif

PTRNTAB0 aptb0SYSCALL[] =  /* SYSCALL */ {
        { 0x0f05, _modcxr11 }
};

PTRNTAB0 aptb0SYSRET[] =  /* SYSRET */ {
        { 0x0f07, 0 }
};

PTRNTAB0 aptb0SYSENTER[] =  /* SYSENTER */ {
        { 0x0f34, 0 }
};

PTRNTAB0 aptb0SYSEXIT[] =  /* SYSEXIT */ {
        { 0x0f35, 0 }
};

PTRNTAB0 aptb0UD2[] =  /* UD2 */ {
        { 0x0f0b, 0 }
};

PTRNTAB0 aptb0LFENCE[] = /* LFENCE */   {
        { 0x0FAEE8,     0 }
};

PTRNTAB0 aptb0MFENCE[] = /* MFENCE */   {
        { 0x0FAEF0,     0 }
};

PTRNTAB0 aptb0SFENCE[] = /* SFENCE */   {
        { 0x0FAEF8,     0 }
};

PTRNTAB1  aptb1FXSAVE[] = /* FXSAVE */ {
        { 0x0FAE, _0, _m512 },
        { ASM_END, 0, 0 }
};

PTRNTAB1  aptb1FXRSTOR[] = /* FXRSTOR */ {
        { 0x0FAE, _1, _m512 },
        { ASM_END, 0, 0 }
};

PTRNTAB1  aptb1LDMXCSR[] = /* LDMXCSR */ {
        { 0x0FAE, _2, _m32 },
        { ASM_END, 0, 0 }
};

PTRNTAB1  aptb1STMXCSR[] = /* STMXCSR */ {
        { 0x0FAE, _3, _m32 },
        { ASM_END, 0, 0 }
};

PTRNTAB1  aptb1CLFLUSH[] = /* CLFLUSH */ {
        { 0x0FAE, _7, _m8 },
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2ADDPS[] = {
        { 0x0F58, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2ADDPD[] = {
        { 0x660F58, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2ADDSD[] = {
        { 0xF20F58, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2ADDSS[] = {
        { 0xF30F58, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2ANDPD[] = {
        { 0x660F54, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2ANDPS[] = {
        { 0x0F54, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2ANDNPD[] = {
        { 0x660F55, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2ANDNPS[] = {
        { 0x0F55, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3CMPPS[] = {
        { 0x0FC2, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3CMPPD[] = {
        { 0x660FC2, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3CMPSD[] = {
        { 0xa7, _32_bit | _I386 | _modsidi },
        { 0xF20FC2, _r,_xmm,_xmm_m64,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3CMPSS[] = {
        { 0xF30FC2, _r,_xmm,_xmm_m32,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2COMISD[] = {
        { 0x660F2F, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2COMISS[] = {
        { 0x0F2F, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTDQ2PD[] = {
        { 0xF30FE6, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTDQ2PS[] = {
        { 0x0F5B, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPD2DQ[] = {
        { 0xF20FE6, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPD2PI[] = {
        { 0x660F2D, _r,_mm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPD2PS[] = {
        { 0x660F5A, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPI2PD[] = {
        { 0x660F2A, _r,_xmm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPI2PS[] = {
        { 0x0F2A, _r,_xmm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPS2DQ[] = {
        { 0x660F5B, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPS2PD[] = {
        { 0x0F5A, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPS2PI[] = {
        { 0x0F2D, _r,_mm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSD2SI[] = {
        { 0xF20F2D, _r,_r32,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSD2SS[] = {
        { 0xF20F5A, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSI2SD[] = {
        { 0xF20F2A, _r,_xmm,_rm32 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSI2SS[] = {
        { 0xF30F2A, _r,_xmm,_rm32 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSS2SD[] = {
        { 0xF30F5A, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSS2SI[] = {
        { 0xF30F2D, _r,_r32,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTPD2PI[] = {
        { 0x660F2C, _r,_mm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTPD2DQ[] = {
        { 0x660FE6, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTPS2DQ[] = {
        { 0xF30F5B, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTPS2PI[] = {
        { 0x0F2C, _r,_mm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTSD2SI[] = {
        { 0xF20F2C, _r,_r32,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTSS2SI[] = {
        { 0xF30F2C, _r,_r32,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2DIVPD[] = {
        { 0x660F5E, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2DIVPS[] = {
        { 0x0F5E, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2DIVSD[] = {
        { 0xF20F5E, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2DIVSS[] = {
        { 0xF30F5E, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2MASKMOVDQU[] = {
        { 0x660FF7, _r,_xmm,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MASKMOVQ[] = {
        { 0x0FF7, _r,_mm,_mm },
        { ASM_END }
};

PTRNTAB2 aptb2MAXPD[] = {
        { 0x660F5F, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2MAXPS[] = {
        { 0x0F5F, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2MAXSD[] = {
        { 0xF20F5F, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2MAXSS[] = {
        { 0xF30F5F, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2MINPD[] = {
        { 0x660F5D, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2MINPS[] = {
        { 0x0F5D, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2MINSD[] = {
        { 0xF20F5D, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2MINSS[] = {
        { 0xF30F5D, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVAPD[] = {
        { 0x660F28, _r,_xmm,_xmm_m128 },
        { 0x660F29, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVAPS[] = {
        { 0x0F28, _r,_xmm,_xmm_m128 },
        { 0x0F29, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVDQA[] = {
        { 0x660F6F, _r,_xmm,_xmm_m128 },
        { 0x660F7F, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVDQU[] = {
        { 0xF30F6F, _r,_xmm,_xmm_m128 },
        { 0xF30F7F, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVDQ2Q[] = {
        { 0xF20FD6, _r,_mm,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVHLPS[] = {
        { 0x0F12, _r,_xmm,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVHPD[] = {
        { 0x660F16, _r,_xmm,_xmm_m64 },
        { 0x660F17, _r,_xmm_m64,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVHPS[] = {
        { 0x0F16, _r,_xmm,_xmm_m64 },
        { 0x0F17, _r,_xmm_m64,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVLHPS[] = {
        { 0x0F16, _r,_xmm,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVLPD[] = {
        { 0x660F12, _r,_xmm,_xmm_m64 },
        { 0x660F13, _r,_xmm_m64,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVLPS[] = {
        { 0x0F12, _r,_xmm,_xmm_m64 },
        { 0x0F13, _r,_xmm_m64,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVMSKPD[] = {
        { 0x660F50, _r,_r32,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVMSKPS[] = {
        { 0x0F50, _r,_r32,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTDQ[] = {
        { 0x660FE7, _r,_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTI[] = {
        { 0x0FC3, _r,_m32,_r32 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTPD[] = {
        { 0x660F2B, _r,_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTPS[] = {
        { 0x0F2B, _r,_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTQ[] = {
        { 0x0FE7, _r,_m64,_mm },
        { ASM_END }
};

/* MOVQ */

PTRNTAB2 aptb2MOVQ2DQ[] = {
        { 0xF30FD6, _r,_xmm,_mm },
        { ASM_END }
};

/* MOVSD */

PTRNTAB2 aptb2MOVSS[] = {
        { 0xF30F10, _r,_xmm,_xmm_m32 },
        { 0xF30F11, _r,_xmm_m32,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVUPD[] = {
        { 0x660F10, _r,_xmm,_xmm_m128 },
        { 0x660F11, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVUPS[] = {
        { 0x0F10, _r,_xmm,_xmm_m128 },
        { 0x0F11, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MULPD[] = {
        { 0x660F59, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2MULPS[] = {
        { 0x0F59, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2MULSD[] = {
        { 0xF20F59, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2MULSS[] = {
        { 0xF30F59, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2ORPD[] = {
        { 0x660F56, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2ORPS[] = {
        { 0x0F56, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDQ[] = {
        { 0x0FD4, _r,_mm,_mmm64 },
        { 0x660FD4, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PAVGB[] = {
        { 0x0FE0, _r,_mm,_mmm64 },
        { 0x660FE0, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PAVGW[] = {
        { 0x0FE3, _r,_mm,_mmm64 },
        { 0x660FE3, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3PEXTRW[] = {
        { 0x0FC5, _r,_r32,_mm,_imm8 },
        { 0x660FC5, _r,_r32,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PINSRW[] = {
        { 0x0FC4, _r,_mm,_r32m16,_imm8 },
        { 0x660FC4, _r,_xmm,_r32m16,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PMAXSW[] = {
        { 0x0FEE, _r,_mm,_mmm64 },
        { 0x660FEE, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMAXUB[] = {
        { 0x0FDE, _r,_mm,_mmm64 },
        { 0x660FDE, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMINSW[] = {
        { 0x0FEA, _r,_mm,_mmm64 },
        { 0x660FEA, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMINUB[] = {
        { 0x0FDA, _r,_mm,_mmm64 },
        { 0x660FDA, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVMSKB[] = {
        { 0x0FD7, _r,_r32,_mm },
        { 0x660FD7, _r,_r32,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2PMULHUW[] = {
        { 0x0FE4, _r,_mm,_mmm64 },
        { 0x660FE4, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULHW[] = {
        { 0x0FE5, _r,_mm,_mmm64 },
        { 0x660FE5, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULLW[] = {
        { 0x0FD5, _r,_mm,_mmm64 },
        { 0x660FD5, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULUDQ[] = {
        { 0x0FF4, _r,_mm,_mmm64 },
        { 0x660FF4, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2POR[] = {
        { 0x0FEB, _r,_mm,_mmm64 },
        { 0x660FEB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHNTA[] = {
        { 0x0F18, _0,_m8 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHT0[] = {
        { 0x0F18, _1,_m8 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHT1[] = {
        { 0x0F18, _2,_m8 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHT2[] = {
        { 0x0F18, _3,_m8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSADBW[] = {
        { 0x0FF6, _r,_mm,_mmm64 },
        { 0x660FF6, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3PSHUFD[] = {
        { 0x660F70, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PSHUFHW[] = {
        { 0xF30F70, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PSHUFLW[] = {
        { 0xF20F70, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PSHUFW[] = {
        { 0x0F70, _r,_mm,_mmm64,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSLLDQ[] = {
        { 0x660F73, _7,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRLDQ[] = {
        { 0x660F73, _3,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBQ[] = {
        { 0x0FFB, _r,_mm,_mmm64 },
        { 0x660FFB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKHQDQ[] = {
        { 0x660F6D, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKLQDQ[] = {
        { 0x660F6C, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2RCPPS[] = {
        { 0x0F53, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2RCPSS[] = {
        { 0xF30F53, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2RSQRTPS[] = {
        { 0x0F52, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2RSQRTSS[] = {
        { 0xF30F52, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3SHUFPD[] = {
        { 0x660FC6, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3SHUFPS[] = {
        { 0x0FC6, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2SQRTPD[] = {
        { 0x660F51, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2SQRTPS[] = {
        { 0x0F51, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2SQRTSD[] = {
        { 0xF20F51, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2SQRTSS[] = {
        { 0xF30F51, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2SUBPD[] = {
        { 0x660F5C, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2SUBPS[] = {
        { 0x0F5C, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2SUBSD[] = {
        { 0xF20F5C, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2SUBSS[] = {
        { 0xF30F5C, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2UCOMISD[] = {
        { 0x660F2E, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2UCOMISS[] = {
        { 0x0F2E, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2UNPCKHPD[] = {
        { 0x660F15, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2UNPCKHPS[] = {
        { 0x0F15, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2UNPCKLPD[] = {
        { 0x660F14, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2UNPCKLPS[] = {
        { 0x0F14, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2XORPD[] = {
        { 0x660F57, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2XORPS[] = {
        { 0x0F57, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

/**** AMD only instructions ****/

/*
        pavgusb
        pf2id
        pfacc
        pfadd
        pfcmpeq
        pfcmpge
        pfcmpgt
        pfmax
        pfmin
        pfmul
        pfnacc
        pfpnacc
        pfrcp
        pfrcpit1
        pfrcpit2
        pfrsqit1
        pfrsqrt
        pfsub
        pfsubr
        pi2fd
        pmulhrw
        pswapd
*/

PTRNTAB2 aptb2PAVGUSB[] = {
        { 0x0F0FBF, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PF2ID[] = {
        { 0x0F0F1D, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFACC[] = {
        { 0x0F0FAE, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFADD[] = {
        { 0x0F0F9E, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFCMPEQ[] = {
        { 0x0F0FB0, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFCMPGE[] = {
        { 0x0F0F90, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFCMPGT[] = {
        { 0x0F0FA0, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFMAX[] = {
        { 0x0F0FA4, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFMIN[] = {
        { 0x0F0F94, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFMUL[] = {
        { 0x0F0FB4, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFNACC[] = {
        { 0x0F0F8A, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFPNACC[] = {
        { 0x0F0F8E, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRCP[] = {
        { 0x0F0F96, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRCPIT1[] = {
        { 0x0F0FA6, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRCPIT2[] = {
        { 0x0F0FB6, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRSQIT1[] = {
        { 0x0F0FA7, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRSQRT[] = {
        { 0x0F0F97, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFSUB[] = {
        { 0x0F0F9A, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFSUBR[] = {
        { 0x0F0FAA, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PI2FD[] = {
        { 0x0F0F0D, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULHRW[] = {
        { 0x0F0FB7, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PSWAPD[] = {
        { 0x0F0FBB, _r,_mm,_mmm64 },
        { ASM_END }
};

/* ======================= Pentium 4 (Prescott) ======================= */

/*
        ADDSUBPD
        ADDSUBPS
        FISTTP
        HADDPD
        HADDPS
        HSUBPD
        HSUBPS
        LDDQU
        MONITOR
        MOVDDUP
        MOVSHDUP
        MOVSLDUP
        MWAIT
 */

PTRNTAB0 aptb0MONITOR[] =  /* MONITOR */ {
        { 0x0f01c8, 0 }
};

PTRNTAB0 aptb0MWAIT[] =  /* MWAIT */ {
        { 0x0f01c9, 0 }
};

PTRNTAB2 aptb2ADDSUBPD[] = /* ADDSUBPD */ {
        { 0x660FD0, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2ADDSUBPS[] = /* ADDSUBPS */ {
        { 0xF20FD0, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2HADDPD[] = /* HADDPD */ {
        { 0x660F7C, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2HADDPS[] = /* HADDPS */ {
        { 0xF20F7C, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2HSUBPD[] = /* HSUBPD */ {
        { 0x660F7D, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2HSUBPS[] = /* HSUBPS */ {
        { 0xF20F7D, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2LDDQU[] = /* LDDQU */ {
        { 0xF20Ff0, _r,_xmm,_m128 },            // xmm1,mem
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2MOVDDUP[] = /* MOVDDUP */ {
        { 0xF20F12, _r,_xmm,_xmm_m64 },         // xmm1,xmm2/m64
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2MOVSHDUP[] = /* MOVSHDUP */ {
        { 0xF30F16, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END, 0, 0 }
};

PTRNTAB2 aptb2MOVSLDUP[] = /* MOVSLDUP */ {
        { 0xF30F12, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END, 0, 0 }
};

/* ======================= SSE4.1 ======================= */

/*
blendpd
blendps
blendvpd
blendvps
dppd
dpps
extractps
insertps
movntdqa
mpsadbw
packusdw
pblendub
pblendw
pcmpeqq
pextrb
pextrd
pextrq
pextrw
phminposuw
pinsrb
pinsrd
pinsrq
pmaxsb
pmaxsd
pmaxud
pmaxuw
pminsb
pminsd
pminud
pminuw
pmovsxbd
pmovsxbq
pmovsxbw
pmovsxwd
pmovsxwq
pmovsxdq
pmovzxbd
pmovzxbq
pmovzxbw
pmovzxwd
pmovzxwq
pmovzxdq
pmuldq
pmulld
ptest
roundpd
roundps
roundsd
roundss
 */


PTRNTAB3 aptb3DPPD[] = {
        { 0x660F3A41, _r,_xmm,_xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3DPPS[] = {
        { 0x660F3A40, _r,_xmm,_xmm_m128, _imm8 },
        { ASM_END }
};

/* ======================= SSE4.2 ======================= */

/*
crc32
pcmpestri
pcmpestrm
pcmpistri
pcmpistrm
pcmpgtq
popcnt
 */

/* ======================= VMS ======================= */

/*
invept
invvpid
vmcall
vmclear
vmlaunch
vmresume
vmptrld
vmptrst
vmread
vmwrite
vmxoff
vmxon
 */

/* ======================= SMX ======================= */

/*
getsec
 */




//////////////////////////////////////////////////////////////////////


//
// usNumops should be 0, 1, 2, or 3 other things are added into it
// for flag indications
// 10, 11, 12, and 13 indicate that it is a special prefix

// 20, 21, 22, and 23 indicate that this statement is a control transfer
//                      and that a new block should be created when this statement is
//                      finished. (All Jxx and LOOPxx instructions.)

// 30, 31, 32, 33 are reserved for instructions where the value of an
// immediate operand controls the code generation.
// 40, 41, 42, 43 are reserved for instructions where all of the operands
// are not required
// 50, 51, 52, 53 are reserved for the rotate and shift instructions that
// have extremely strange encodings for the second operand which is sometimes
// used to select an opcode and then discarded.  The second operand is 0
// if it is immediate 1, _cl for the CL register and _imm8 for the immediate
// 8 operand.  If the operand is an immediate 1 or the cl register, it should
// be discarded and the opcode should be encoded as a 1 operand instruction.
//
//      60, 61, 62, 63  are reserved for floating point coprocessor operations
//
// ITdata is for the DB (_EMIT), DD, DW, DQ, DT pseudo-ops

//      BT is a 486 instruction.
//      The encoding is 0f C0+reg and it is always a 32
//      bit operation

#define P PPTRNTAB0

#if 0
#define OPCODETABLE     \
        X("aaa",        0,              aptb0AAA )
#else
#define OPCODETABLE1    \
        X("__emit",     ITdata | OPdb,  NULL ) \
        X("_emit",      ITdata | OPdb,  NULL ) \
        X("aaa",        0,              aptb0AAA ) \
        X("aad",        0,              aptb0AAD ) \
        X("aam",        0,              aptb0AAM ) \
        X("aas",        0,              aptb0AAS ) \
        X("adc",        2,              (P) aptb2ADC ) \
        X("add",        2,              (P) aptb2ADD ) \
        X("addpd",      2,              (P) aptb2ADDPD ) \
        X("addps",      2,              (P) aptb2ADDPS ) \
        X("addsd",      2,              (P) aptb2ADDSD ) \
        X("addss",      2,              (P) aptb2ADDSS ) \
        X("addsubpd",   2,              (P) aptb2ADDSUBPD ) \
        X("addsubps",   2,              (P) aptb2ADDSUBPS ) \
        X("and",        2,              (P) aptb2AND ) \
        X("andnpd",     2,              (P) aptb2ANDNPD ) \
        X("andnps",     2,              (P) aptb2ANDNPS ) \
        X("andpd",      2,              (P) aptb2ANDPD ) \
        X("andps",      2,              (P) aptb2ANDPS ) \
        X("arpl",       2,              (P) aptb2ARPL ) \
        X("bound",      2,              (P) aptb2BOUND ) \
        X("bsf",        2,              (P) aptb2BSF ) \
        X("bsr",        2,              (P) aptb2BSR ) \
        X("bswap",      1,              (P) aptb1BSWAP ) \
        X("bt",         2,              (P) aptb2BT ) \
        X("btc",        2,              (P) aptb2BTC ) \
        X("btr",        2,              (P) aptb2BTR ) \
        X("bts",        2,              (P) aptb2BTS ) \
        X("call",       ITjump | 1,     (P) aptb1CALL ) \
        X("cbw",        0,              aptb0CBW ) \
        X("cdq",        0,              aptb0CDQ ) \
        X("cdqe",       0,              aptb0CDQE ) \
        X("clc",        0,              aptb0CLC ) \
        X("cld",        0,              aptb0CLD ) \
        X("clflush",    1,              (P) aptb1CLFLUSH ) \
        X("cli",        0,              aptb0CLI ) \
        X("clts",       0,              aptb0CLTS ) \
        X("cmc",        0,              aptb0CMC ) \
        X("cmova",      2,              (P) aptb2CMOVNBE ) \
        X("cmovae",     2,              (P) aptb2CMOVNB ) \
        X("cmovb",      2,              (P) aptb2CMOVB ) \
        X("cmovbe",     2,              (P) aptb2CMOVBE ) \
        X("cmovc",      2,              (P) aptb2CMOVB ) \
        X("cmove",      2,              (P) aptb2CMOVZ ) \
        X("cmovg",      2,              (P) aptb2CMOVNLE ) \
        X("cmovge",     2,              (P) aptb2CMOVNL ) \
        X("cmovl",      2,              (P) aptb2CMOVL ) \
        X("cmovle",     2,              (P) aptb2CMOVLE ) \
        X("cmovna",     2,              (P) aptb2CMOVBE ) \
        X("cmovnae",    2,              (P) aptb2CMOVB ) \
        X("cmovnb",     2,              (P) aptb2CMOVNB ) \
        X("cmovnbe",    2,              (P) aptb2CMOVNBE ) \
        X("cmovnc",     2,              (P) aptb2CMOVNB ) \
        X("cmovne",     2,              (P) aptb2CMOVNZ ) \
        X("cmovng",     2,              (P) aptb2CMOVLE ) \
        X("cmovnge",    2,              (P) aptb2CMOVL ) \
        X("cmovnl",     2,              (P) aptb2CMOVNL ) \
        X("cmovnle",    2,              (P) aptb2CMOVNLE ) \
        X("cmovno",     2,              (P) aptb2CMOVNO ) \
        X("cmovnp",     2,              (P) aptb2CMOVNP ) \
        X("cmovns",     2,              (P) aptb2CMOVNS ) \
        X("cmovnz",     2,              (P) aptb2CMOVNZ ) \
        X("cmovo",      2,              (P) aptb2CMOVO ) \
        X("cmovp",      2,              (P) aptb2CMOVP ) \
        X("cmovpe",     2,              (P) aptb2CMOVP ) \
        X("cmovpo",     2,              (P) aptb2CMOVNP ) \
        X("cmovs",      2,              (P) aptb2CMOVS ) \
        X("cmovz",      2,              (P) aptb2CMOVZ ) \
        X("cmp",        2,              (P) aptb2CMP ) \
        X("cmppd",      3,              (P) aptb3CMPPD ) \
        X("cmpps",      3,              (P) aptb3CMPPS ) \
        X("cmps",       2,              (P) aptb2CMPS ) \
        X("cmpsb",      0,              aptb0CMPSB ) \
        /*X("cmpsd",    0,              aptb0CMPSD )*/ \
        X("cmpsd",      ITopt|3,        (P) aptb3CMPSD ) \
        X("cmpsq",      0,              aptb0CMPSQ ) \
        X("cmpss",      3,              (P) aptb3CMPSS ) \
        X("cmpsw",      0,              aptb0CMPSW ) \
        X("cmpxchg",    2,              (P) aptb2CMPXCHG ) \
        X("cmpxchg16b", 1,              (P) aptb1CMPXCH16B ) \
        X("cmpxchg8b",  1,              (P) aptb1CMPXCH8B ) \
        X("comisd",     2,              (P) aptb2COMISD ) \
        X("comiss",     2,              (P) aptb2COMISS ) \
        X("cpuid",      0,              aptb0CPUID ) \
        X("cqo",        0,              aptb0CQO ) \
        X("cvtdq2pd",   2,              (P) aptb2CVTDQ2PD ) \
        X("cvtdq2ps",   2,              (P) aptb2CVTDQ2PS ) \
        X("cvtpd2dq",   2,              (P) aptb2CVTPD2DQ ) \
        X("cvtpd2pi",   2,              (P) aptb2CVTPD2PI ) \
        X("cvtpd2ps",   2,              (P) aptb2CVTPD2PS ) \
        X("cvtpi2pd",   2,              (P) aptb2CVTPI2PD ) \
        X("cvtpi2ps",   2,              (P) aptb2CVTPI2PS ) \
        X("cvtps2dq",   2,              (P) aptb2CVTPS2DQ ) \
        X("cvtps2pd",   2,              (P) aptb2CVTPS2PD ) \
        X("cvtps2pi",   2,              (P) aptb2CVTPS2PI ) \
        X("cvtsd2si",   2,              (P) aptb2CVTSD2SI ) \
        X("cvtsd2ss",   2,              (P) aptb2CVTSD2SS ) \
        X("cvtsi2sd",   2,              (P) aptb2CVTSI2SD ) \
        X("cvtsi2ss",   2,              (P) aptb2CVTSI2SS ) \
        X("cvtss2sd",   2,              (P) aptb2CVTSS2SD ) \
        X("cvtss2si",   2,              (P) aptb2CVTSS2SI ) \
        X("cvttpd2dq",  2,              (P) aptb2CVTTPD2DQ ) \
        X("cvttpd2pi",  2,              (P) aptb2CVTTPD2PI ) \
        X("cvttps2dq",  2,              (P) aptb2CVTTPS2DQ ) \
        X("cvttps2pi",  2,              (P) aptb2CVTTPS2PI ) \
        X("cvttsd2si",  2,              (P) aptb2CVTTSD2SI ) \
        X("cvttss2si",  2,              (P) aptb2CVTTSS2SI ) \
        X("cwd",        0,              aptb0CWD ) \
        X("cwde",       0,              aptb0CWDE ) \
        X("da",         ITaddr | 4,     NULL ) \
        X("daa",        0,              aptb0DAA ) \
        X("das",        0,              aptb0DAS ) \
        X("db",         ITdata | OPdb,  NULL ) \
        X("dd",         ITdata | OPdd,  NULL ) \
        X("de",         ITdata | OPde,  NULL ) \
        X("dec",        1,              (P) aptb1DEC ) \
        X("df",         ITdata | OPdf,  NULL ) \
        X("di",         ITdata | OPdi,  NULL ) \
        X("div",        ITopt  | 2,     (P) aptb2DIV ) \
        X("divpd",      2,              (P) aptb2DIVPD ) \
        X("divps",      2,              (P) aptb2DIVPS ) \
        X("divsd",      2,              (P) aptb2DIVSD ) \
        X("divss",      2,              (P) aptb2DIVSS ) \
        X("dl",         ITdata | OPdl,  NULL ) \
        X("dppd",       3,              (P) aptb3DPPD ) \
        X("dpps",       3,              (P) aptb3DPPS ) \
        X("dq",         ITdata | OPdq,  NULL ) \
        X("ds",         ITdata | OPds,  NULL ) \
        X("dt",         ITdata | OPdt,  NULL ) \
        X("dw",         ITdata | OPdw,  NULL ) \
        X("emms",       0,              aptb0EMMS ) \
        X("enter",      2,              (P) aptb2ENTER ) \
        X("f2xm1",      ITfloat | 0,    aptb0F2XM1 ) \
        X("fabs",       ITfloat | 0,    aptb0FABS ) \
        X("fadd",       ITfloat | 2,    (P) aptb2FADD ) \
        X("faddp",      ITfloat | 2,    (P) aptb2FADDP ) \
        X("fbld",       ITfloat | 1,    (P) aptb1FBLD ) \
        X("fbstp",      ITfloat | 1,    (P) aptb1FBSTP ) \
        X("fchs",       ITfloat | 0,    aptb0FCHS ) \
        X("fclex",      ITfloat | 0,    aptb0FCLEX ) \
        X("fcmovb",     ITfloat | 2,    (P) aptb2FCMOVB ) \
        X("fcmovbe",    ITfloat | 2,    (P) aptb2FCMOVBE ) \
        X("fcmove",     ITfloat | 2,    (P) aptb2FCMOVE ) \
        X("fcmovnb",    ITfloat | 2,    (P) aptb2FCMOVNB ) \
        X("fcmovnbe",   ITfloat | 2,    (P) aptb2FCMOVNBE ) \
        X("fcmovne",    ITfloat | 2,    (P) aptb2FCMOVNE ) \
        X("fcmovnu",    ITfloat | 2,    (P) aptb2FCMOVNU ) \
        X("fcmovu",     ITfloat | 2,    (P) aptb2FCMOVU ) \
        X("fcom",       ITfloat | 1,    (P) aptb1FCOM ) \
        X("fcomi",      ITfloat | 2,    (P) aptb2FCOMI ) \
        X("fcomip",     ITfloat | 2,    (P) aptb2FCOMIP ) \
        X("fcomp",      ITfloat | 1,    (P) aptb1FCOMP ) \
        X("fcompp",     ITfloat | 0,    aptb0FCOMPP ) \
        X("fcos",       ITfloat | 0,    aptb0FCOS ) \
        X("fdecstp",    ITfloat | 0,    aptb0FDECSTP ) \
        X("fdisi",      ITfloat | 0,    aptb0FDISI ) \
        X("fdiv",       ITfloat | 2,    (P) aptb2FDIV ) \
        X("fdivp",      ITfloat | 2,    (P) aptb2FDIVP ) \
        X("fdivr",      ITfloat | 2,    (P) aptb2FDIVR ) \
        X("fdivrp",     ITfloat | 2,    (P) aptb2FDIVRP ) \
        X("feni",       ITfloat | 0,    aptb0FENI ) \
        X("ffree",      ITfloat | 1,    (P) aptb1FFREE ) \
        X("fiadd",      ITfloat | 2,    (P) aptb2FIADD ) \
        X("ficom",      ITfloat | 1,    (P) aptb1FICOM ) \
        X("ficomp",     ITfloat | 1,    (P) aptb1FICOMP ) \
        X("fidiv",      ITfloat | 2,    (P) aptb2FIDIV ) \
        X("fidivr",     ITfloat | 2,    (P) aptb2FIDIVR ) \
        X("fild",       ITfloat | 1,    (P) aptb1FILD ) \
        X("fimul",      ITfloat | 2,    (P) aptb2FIMUL ) \
        X("fincstp",    ITfloat | 0,    aptb0FINCSTP ) \
        X("finit",      ITfloat | 0,    aptb0FINIT ) \
        X("fist",       ITfloat | 1,    (P) aptb1FIST ) \
        X("fistp",      ITfloat | 1,    (P) aptb1FISTP ) \
        X("fisttp",     ITfloat | 1,    (P) aptb1FISTTP ) \
        X("fisub",      ITfloat | 2,    (P) aptb2FISUB ) \
        X("fisubr",     ITfloat | 2,    (P) aptb2FISUBR ) \
        X("fld",        ITfloat | 1,    (P) aptb1FLD ) \
        X("fld1",       ITfloat | 0,    aptb0FLD1 ) \
        X("fldcw",      ITfloat | 1,    (P) aptb1FLDCW ) \
        X("fldenv",     ITfloat | 1,    (P) aptb1FLDENV ) \
        X("fldl2e",     ITfloat | 0,    aptb0FLDL2E ) \
        X("fldl2t",     ITfloat | 0,    aptb0FLDL2T ) \
        X("fldlg2",     ITfloat | 0,    aptb0FLDLG2 ) \
        X("fldln2",     ITfloat | 0,    aptb0FLDLN2 ) \
        X("fldpi",      ITfloat | 0,    aptb0FLDPI ) \
        X("fldz",       ITfloat | 0,    aptb0FLDZ ) \
        X("fmul",       ITfloat | 2,    (P) aptb2FMUL ) \
        X("fmulp",      ITfloat | 2,    (P) aptb2FMULP ) \
        X("fnclex",     ITfloat | 0,    aptb0FNCLEX ) \
        X("fndisi",     ITfloat | 0,    aptb0FNDISI ) \
        X("fneni",      ITfloat | 0,    aptb0FNENI ) \
        X("fninit",     ITfloat | 0,    aptb0FNINIT ) \
        X("fnop",       ITfloat | 0,    aptb0FNOP ) \
        X("fnsave",     ITfloat | 1,    (P) aptb1FNSAVE ) \
        X("fnstcw",     ITfloat | 1,    (P) aptb1FNSTCW ) \
        X("fnstenv",    ITfloat | 1,    (P) aptb1FNSTENV ) \
        X("fnstsw",     1,              (P) aptb1FNSTSW ) \
        X("fpatan",     ITfloat | 0,    aptb0FPATAN ) \
        X("fprem",      ITfloat | 0,    aptb0FPREM ) \
        X("fprem1",     ITfloat | 0,    aptb0FPREM1 ) \
        X("fptan",      ITfloat | 0,    aptb0FPTAN ) \
        X("frndint",    ITfloat | 0,    aptb0FRNDINT ) \
        X("frstor",     ITfloat | 1,    (P) aptb1FRSTOR ) \
        X("fsave",      ITfloat | 1,    (P) aptb1FSAVE ) \
        X("fscale",     ITfloat | 0,    aptb0FSCALE ) \
        X("fsetpm",     ITfloat | 0,    aptb0FSETPM ) \
        X("fsin",       ITfloat | 0,    aptb0FSIN ) \
        X("fsincos",    ITfloat | 0,    aptb0FSINCOS ) \
        X("fsqrt",      ITfloat | 0,    aptb0FSQRT ) \
        X("fst",        ITfloat | 1,    (P) aptb1FST ) \
        X("fstcw",      ITfloat | 1,    (P) aptb1FSTCW ) \
        X("fstenv",     ITfloat | 1,    (P) aptb1FSTENV ) \
        X("fstp",       ITfloat | 1,    (P) aptb1FSTP ) \
        X("fstsw",      1,              (P) aptb1FSTSW ) \
        X("fsub",       ITfloat | 2,    (P) aptb2FSUB ) \
        X("fsubp",      ITfloat | 2,    (P) aptb2FSUBP ) \
        X("fsubr",      ITfloat | 2,    (P) aptb2FSUBR ) \
        X("fsubrp",     ITfloat | 2,    (P) aptb2FSUBRP ) \
        X("ftst",       ITfloat | 0,    aptb0FTST ) \
        X("fucom",      ITfloat | 1,    (P) aptb1FUCOM ) \
        X("fucomi",     ITfloat | 2,    (P) aptb2FUCOMI ) \
        X("fucomip",    ITfloat | 2,    (P) aptb2FUCOMIP ) \
        X("fucomp",     ITfloat | 1,    (P) aptb1FUCOMP ) \
        X("fucompp",    ITfloat | 0,    aptb0FUCOMPP ) \
        X("fwait",      ITfloat | 0,    aptb0FWAIT ) \
        X("fxam",       ITfloat | 0,    aptb0FXAM ) \
        X("fxch",       ITfloat | 1,    (P) aptb1FXCH ) \
        X("fxrstor",    ITfloat | 1,    (P) aptb1FXRSTOR ) \
        X("fxsave",     ITfloat | 1,    (P) aptb1FXSAVE ) \
        X("fxtract",    ITfloat | 0,    aptb0FXTRACT ) \
        X("fyl2x",      ITfloat | 0,    aptb0FYL2X ) \
        X("fyl2xp1",    ITfloat | 0,    aptb0FYL2XP1 ) \
        X("haddpd",     2,              (P) aptb2HADDPD ) \
        X("haddps",     2,              (P) aptb2HADDPS ) \
        X("hlt",        0,              aptb0HLT ) \
        X("hsubpd",     2,              (P) aptb2HSUBPD ) \
        X("hsubps",     2,              (P) aptb2HSUBPS ) \
        X("idiv",       ITopt | 2,      (P) aptb2IDIV ) \
        X("imul",       ITopt | 3,      (P) aptb3IMUL ) \
        X("in",         2,              (P) aptb2IN ) \
        X("inc",        1,              (P) aptb1INC ) \
        X("ins",        2,              (P) aptb2INS ) \
        X("insb",       0,              aptb0INSB ) \
        X("insd",       0,              aptb0INSD ) \
        X("insw",       0,              aptb0INSW ) \
        X("int",        ITimmed | 1,    (P) aptb1INT ) \
        X("into",       0,              aptb0INTO ) \
        X("invd",       0,              aptb0INVD ) \
        X("invlpg",     1,              (P) aptb1INVLPG ) \
        X("iret",       0,              aptb0IRET ) \
        X("iretd",      0,              aptb0IRETD ) \
        X("ja",         ITjump | 1,     (P) aptb1JNBE ) \
        X("jae",        ITjump | 1,     (P) aptb1JNB ) \
        X("jb",         ITjump | 1,     (P) aptb1JB ) \
        X("jbe",        ITjump | 1,     (P) aptb1JBE ) \
        X("jc",         ITjump | 1,     (P) aptb1JB ) \
        X("jcxz",       ITjump | 1,     (P) aptb1JCXZ ) \
        X("je",         ITjump | 1,     (P) aptb1JZ ) \
        X("jecxz",      ITjump | 1,     (P) aptb1JECXZ ) \
        X("jg",         ITjump | 1,     (P) aptb1JNLE ) \
        X("jge",        ITjump | 1,     (P) aptb1JNL ) \
        X("jl",         ITjump | 1,     (P) aptb1JL ) \
        X("jle",        ITjump | 1,     (P) aptb1JLE ) \
        X("jmp",        ITjump | 1,     (P) aptb1JMP ) \
        X("jna",        ITjump | 1,     (P) aptb1JBE ) \
        X("jnae",       ITjump | 1,     (P) aptb1JB ) \
        X("jnb",        ITjump | 1,     (P) aptb1JNB ) \
        X("jnbe",       ITjump | 1,     (P) aptb1JNBE ) \
        X("jnc",        ITjump | 1,     (P) aptb1JNB ) \
        X("jne",        ITjump | 1,     (P) aptb1JNZ ) \
        X("jng",        ITjump | 1,     (P) aptb1JLE ) \
        X("jnge",       ITjump | 1,     (P) aptb1JL ) \
        X("jnl",        ITjump | 1,     (P) aptb1JNL ) \
        X("jnle",       ITjump | 1,     (P) aptb1JNLE ) \
        X("jno",        ITjump | 1,     (P) aptb1JNO ) \
        X("jnp",        ITjump | 1,     (P) aptb1JNP ) \
        X("jns",        ITjump | 1,     (P) aptb1JNS ) \
        X("jnz",        ITjump | 1,     (P) aptb1JNZ ) \
        X("jo",         ITjump | 1,     (P) aptb1JO ) \
        X("jp",         ITjump | 1,     (P) aptb1JP ) \
        X("jpe",        ITjump | 1,     (P) aptb1JP ) \
        X("jpo",        ITjump | 1,     (P) aptb1JNP ) \
        X("js",         ITjump | 1,     (P) aptb1JS ) \
        X("jz",         ITjump | 1,     (P) aptb1JZ ) \


#define OPCODETABLE2    \
        X("lahf",       0,              aptb0LAHF ) \
        X("lar",        2,              (P) aptb2LAR ) \
        X("lddqu",      2,              (P) aptb2LDDQU ) \
        X("ldmxcsr",    1,              (P) aptb1LDMXCSR ) \
        X("lds",        2,              (P) aptb2LDS ) \
        X("lea",        2,              (P) aptb2LEA ) \
        X("leave",      0,              aptb0LEAVE ) \
        X("les",        2,              (P) aptb2LES ) \
        X("lfence",     0,              aptb0LFENCE) \
        X("lfs",        2,              (P) aptb2LFS ) \
        X("lgdt",       1,              (P) aptb1LGDT ) \
        X("lgs",        2,              (P) aptb2LGS ) \
        X("lidt",       1,              (P) aptb1LIDT ) \
        X("lldt",       1,              (P) aptb1LLDT ) \
        X("lmsw",       1,              (P) aptb1LMSW ) \
        X("lock",       ITprefix | 0,   aptb0LOCK ) \
        X("lods",       1,              (P) aptb1LODS ) \
        X("lodsb",      0,              aptb0LODSB ) \
        X("lodsd",      0,              aptb0LODSD ) \
        X("lodsq",      0,              aptb0LODSQ ) \
        X("lodsw",      0,              aptb0LODSW ) \
        X("loop",       ITjump | 1,     (P) aptb1LOOP ) \
        X("loope",      ITjump | 1,     (P) aptb1LOOPE ) \
        X("loopne",     ITjump | 1,     (P) aptb1LOOPNE ) \
        X("loopnz",     ITjump | 1,     (P) aptb1LOOPNE ) \
        X("loopz",      ITjump | 1,     (P) aptb1LOOPE ) \
        X("lsl",        2,              (P) aptb2LSL ) \
        X("lss",        2,              (P) aptb2LSS ) \
        X("ltr",        1,              (P) aptb1LTR ) \
        X("maskmovdqu", 2,              (P) aptb2MASKMOVDQU ) \
        X("maskmovq",   2,              (P) aptb2MASKMOVQ ) \
        X("maxpd",      2,              (P) aptb2MAXPD ) \
        X("maxps",      2,              (P) aptb2MAXPS ) \
        X("maxsd",      2,              (P) aptb2MAXSD ) \
        X("maxss",      2,              (P) aptb2MAXSS ) \
        X("mfence",     0,              aptb0MFENCE) \
        X("minpd",      2,              (P) aptb2MINPD ) \
        X("minps",      2,              (P) aptb2MINPS ) \
        X("minsd",      2,              (P) aptb2MINSD ) \
        X("minss",      2,              (P) aptb2MINSS ) \
        X("monitor",    0,              (P) aptb0MONITOR ) \
        X("mov",        2,              (P) aptb2MOV ) \
        X("movapd",     2,              (P) aptb2MOVAPD ) \
        X("movaps",     2,              (P) aptb2MOVAPS ) \
        X("movd",       2,              (P) aptb2MOVD ) \
        X("movddup",    2,              (P) aptb2MOVDDUP ) \
        X("movdq2q",    2,              (P) aptb2MOVDQ2Q ) \
        X("movdqa",     2,              (P) aptb2MOVDQA ) \
        X("movdqu",     2,              (P) aptb2MOVDQU ) \
        X("movhlps",    2,              (P) aptb2MOVHLPS ) \
        X("movhpd",     2,              (P) aptb2MOVHPD ) \
        X("movhps",     2,              (P) aptb2MOVHPS ) \
        X("movlhps",    2,              (P) aptb2MOVLHPS ) \
        X("movlpd",     2,              (P) aptb2MOVLPD ) \
        X("movlps",     2,              (P) aptb2MOVLPS ) \
        X("movmskpd",   2,              (P) aptb2MOVMSKPD ) \
        X("movmskps",   2,              (P) aptb2MOVMSKPS ) \
        X("movntdq",    2,              (P) aptb2MOVNTDQ ) \
        X("movnti",     2,              (P) aptb2MOVNTI ) \
        X("movntpd",    2,              (P) aptb2MOVNTPD ) \
        X("movntps",    2,              (P) aptb2MOVNTPS ) \
        X("movntq",     2,              (P) aptb2MOVNTQ ) \
        X("movq",       2,              (P) aptb2MOVQ ) \
        X("movq2dq",    2,              (P) aptb2MOVQ2DQ ) \
        X("movs",       2,              (P) aptb2MOVS ) \
        X("movsb",      0,              aptb0MOVSB ) \
        X("movsd",      ITopt | 2,      (P) aptb2MOVSD ) \
        X("movshdup",   2,              (P) aptb2MOVSHDUP ) \
        X("movsldup",   2,              (P) aptb2MOVSLDUP ) \
        X("movsq",      0,              aptb0MOVSQ ) \
        X("movss",      2,              (P) aptb2MOVSS ) \
        X("movsw",      0,              aptb0MOVSW ) \
        X("movsx",      2,              (P) aptb2MOVSX ) \
        X("movupd",     2,              (P) aptb2MOVUPD ) \
        X("movups",     2,              (P) aptb2MOVUPS ) \
        X("movzx",      2,              (P) aptb2MOVZX ) \
        X("mul",        ITopt | 2,      (P) aptb2MUL ) \
        X("mulpd",      2,              (P) aptb2MULPD ) \
        X("mulps",      2,              (P) aptb2MULPS ) \
        X("mulsd",      2,              (P) aptb2MULSD ) \
        X("mulss",      2,              (P) aptb2MULSS ) \
        X("mwait",      0,              (P) aptb0MWAIT ) \
        X("neg",        1,              (P) aptb1NEG ) \
        X("nop",        0,              aptb0NOP ) \
        X("not",        1,              (P) aptb1NOT ) \
        X("or",         2,              (P) aptb2OR ) \
        X("orpd",       2,              (P) aptb2ORPD ) \
        X("orps",       2,              (P) aptb2ORPS ) \
        X("out",        2,              (P) aptb2OUT ) \
        X("outs",       2,              (P) aptb2OUTS ) \
        X("outsb",      0,              aptb0OUTSB ) \
        X("outsd",      0,              aptb0OUTSD ) \
        X("outsw",      0,              aptb0OUTSW ) \
        X("packssdw",   2,              (P) aptb2PACKSSDW ) \
        X("packsswb",   2,              (P) aptb2PACKSSWB ) \
        X("packuswb",   2,              (P) aptb2PACKUSWB ) \
        X("paddb",      2,              (P) aptb2PADDB ) \
        X("paddd",      2,              (P) aptb2PADDD ) \
        X("paddq",      2,              (P) aptb2PADDQ ) \
        X("paddsb",     2,              (P) aptb2PADDSB ) \
        X("paddsw",     2,              (P) aptb2PADDSW ) \
        X("paddusb",    2,              (P) aptb2PADDUSB ) \
        X("paddusw",    2,              (P) aptb2PADDUSW ) \
        X("paddw",      2,              (P) aptb2PADDW ) \
        X("pand",       2,              (P) aptb2PAND ) \
        X("pandn",      2,              (P) aptb2PANDN ) \
        /* X("pause",   0,              aptb0PAUSE) */ \
        X("pavgb",      2,              (P) aptb2PAVGB ) \
        X("pavgusb",    2,              (P) aptb2PAVGUSB ) \
        X("pavgw",      2,              (P) aptb2PAVGW ) \
        X("pcmpeqb",    2,              (P) aptb2PCMPEQB ) \
        X("pcmpeqd",    2,              (P) aptb2PCMPEQD ) \
        X("pcmpeqw",    2,              (P) aptb2PCMPEQW ) \
        X("pcmpgtb",    2,              (P) aptb2PCMPGTB ) \
        X("pcmpgtd",    2,              (P) aptb2PCMPGTD ) \
        X("pcmpgtw",    2,              (P) aptb2PCMPGTW ) \
        X("pextrw",     3,              (P) aptb3PEXTRW ) \
        X("pf2id",      2,              (P) aptb2PF2ID ) \
        X("pfacc",      2,              (P) aptb2PFACC ) \
        X("pfadd",      2,              (P) aptb2PFADD ) \
        X("pfcmpeq",    2,              (P) aptb2PFCMPEQ ) \
        X("pfcmpge",    2,              (P) aptb2PFCMPGE ) \
        X("pfcmpgt",    2,              (P) aptb2PFCMPGT ) \
        X("pfmax",      2,              (P) aptb2PFMAX ) \
        X("pfmin",      2,              (P) aptb2PFMIN ) \
        X("pfmul",      2,              (P) aptb2PFMUL ) \
        X("pfnacc",     2,              (P) aptb2PFNACC ) \
        X("pfpnacc",    2,              (P) aptb2PFPNACC ) \
        X("pfrcp",      2,              (P) aptb2PFRCP ) \
        X("pfrcpit1",   2,              (P) aptb2PFRCPIT1 ) \
        X("pfrcpit2",   2,              (P) aptb2PFRCPIT2 ) \
        X("pfrsqit1",   2,              (P) aptb2PFRSQIT1 ) \
        X("pfrsqrt",    2,              (P) aptb2PFRSQRT ) \
        X("pfsub",      2,              (P) aptb2PFSUB ) \
        X("pfsubr",     2,              (P) aptb2PFSUBR ) \
        X("pi2fd",      2,              (P) aptb2PI2FD ) \
        X("pinsrw",     3,              (P) aptb3PINSRW ) \
        X("pmaddwd",    2,              (P) aptb2PMADDWD ) \
        X("pmaxsw",     2,              (P) aptb2PMAXSW ) \
        X("pmaxub",     2,              (P) aptb2PMAXUB ) \
        X("pminsw",     2,              (P) aptb2PMINSW ) \
        X("pminub",     2,              (P) aptb2PMINUB ) \
        X("pmovmskb",   2,              (P) aptb2PMOVMSKB ) \
        X("pmulhrw",    2,              (P) aptb2PMULHRW ) \
        X("pmulhuw",    2,              (P) aptb2PMULHUW ) \
        X("pmulhw",     2,              (P) aptb2PMULHW ) \
        X("pmullw",     2,              (P) aptb2PMULLW ) \
        X("pmuludq",    2,              (P) aptb2PMULUDQ ) \
        X("pop",        1,              (P) aptb1POP ) \
        X("popa",       0,              aptb0POPA ) \
        X("popad",      0,              aptb0POPAD ) \
        X("popf",       0,              aptb0POPF ) \
        X("popfd",      0,              aptb0POPFD ) \
        X("popfq",      0,              aptb0POPFQ ) \
        X("por",        2,              (P) aptb2POR ) \
        X("prefetchnta",1,              (P) aptb1PREFETCHNTA ) \
        X("prefetcht0", 1,              (P) aptb1PREFETCHT0 ) \
        X("prefetcht1", 1,              (P) aptb1PREFETCHT1 ) \
        X("prefetcht2", 1,              (P) aptb1PREFETCHT2 ) \
        X("psadbw",     2,              (P) aptb2PSADBW ) \
        X("pshufd",     3,              (P) aptb3PSHUFD ) \
        X("pshufhw",    3,              (P) aptb3PSHUFHW ) \
        X("pshuflw",    3,              (P) aptb3PSHUFLW ) \
        X("pshufw",     3,              (P) aptb3PSHUFW ) \
        X("pslld",      2,              (P) aptb2PSLLD ) \
        X("pslldq",     2,              (P) aptb2PSLLDQ ) \
        X("psllq",      2,              (P) aptb2PSLLQ ) \
        X("psllw",      2,              (P) aptb2PSLLW ) \
        X("psrad",      2,              (P) aptb2PSRAD ) \
        X("psraw",      2,              (P) aptb2PSRAW ) \
        X("psrld",      2,              (P) aptb2PSRLD ) \
        X("psrldq",     2,              (P) aptb2PSRLDQ ) \
        X("psrlq",      2,              (P) aptb2PSRLQ ) \
        X("psrlw",      2,              (P) aptb2PSRLW ) \
        X("psubb",      2,              (P) aptb2PSUBB ) \
        X("psubd",      2,              (P) aptb2PSUBD ) \
        X("psubq",      2,              (P) aptb2PSUBQ ) \
        X("psubsb",     2,              (P) aptb2PSUBSB ) \
        X("psubsw",     2,              (P) aptb2PSUBSW ) \
        X("psubusb",    2,              (P) aptb2PSUBUSB ) \
        X("psubusw",    2,              (P) aptb2PSUBUSW ) \
        X("psubw",      2,              (P) aptb2PSUBW ) \
        X("pswapd",     2,              (P) aptb2PSWAPD ) \
        X("punpckhbw",  2,              (P) aptb2PUNPCKHBW ) \
        X("punpckhdq",  2,              (P) aptb2PUNPCKHDQ ) \
        X("punpckhqdq", 2,              (P) aptb2PUNPCKHQDQ ) \
        X("punpckhwd",  2,              (P) aptb2PUNPCKHWD ) \
        X("punpcklbw",  2,              (P) aptb2PUNPCKLBW ) \
        X("punpckldq",  2,              (P) aptb2PUNPCKLDQ ) \
        X("punpcklqdq", 2,              (P) aptb2PUNPCKLQDQ ) \
        X("punpcklwd",  2,              (P) aptb2PUNPCKLWD ) \
        X("push",       1,              (P) aptb1PUSH ) \
        X("pusha",      0,              aptb0PUSHA ) \
        X("pushad",     0,              aptb0PUSHAD ) \
        X("pushf",      0,              aptb0PUSHF ) \
        X("pushfd",     0,              aptb0PUSHFD ) \
        X("pushfq",     0,              aptb0PUSHFQ ) \
        X("pxor",       2,              (P) aptb2PXOR ) \
        X("rcl",        ITshift | 2,    (P) aptb2RCL ) \
        X("rcpps",      2,              (P) aptb2RCPPS ) \
        X("rcpss",      2,              (P) aptb2RCPSS ) \
        X("rcr",        ITshift | 2,    (P) aptb2RCR ) \
        X("rdmsr",      0,              aptb0RDMSR ) \
        X("rdpmc",      0,              aptb0RDPMC ) \
        X("rdtsc",      0,              aptb0RDTSC ) \
        X("rep",        ITprefix | 0,   aptb0REP ) \
        X("repe",       ITprefix | 0,   aptb0REP ) \
        X("repne",      ITprefix | 0,   aptb0REPNE ) \
        X("repnz",      ITprefix | 0,   aptb0REPNE ) \
        X("repz",       ITprefix | 0,   aptb0REP ) \
        X("ret",        ITopt | 1,      (P) aptb1RET ) \
        X("retf",       ITopt | 1,      (P) aptb1RETF ) \
        X("rol",        ITshift | 2,    (P) aptb2ROL ) \
        X("ror",        ITshift | 2,    (P) aptb2ROR ) \
        X("rsm",        0,              aptb0RSM ) \
        X("rsqrtps",    2,              (P) aptb2RSQRTPS ) \
        X("rsqrtss",    2,              (P) aptb2RSQRTSS ) \
        X("sahf",       0,              aptb0SAHF ) \
        X("sal",        ITshift | 2,    (P) aptb2SHL ) \
        X("sar",        ITshift | 2,    (P) aptb2SAR ) \
        X("sbb",        2,              (P) aptb2SBB ) \
        X("scas",       1,              (P) aptb1SCAS ) \
        X("scasb",      0,              aptb0SCASB ) \
        X("scasd",      0,              aptb0SCASD ) \
        X("scasq",      0,              aptb0SCASQ ) \
        X("scasw",      0,              aptb0SCASW ) \
        X("seta",       1,              (P) aptb1SETNBE ) \
        X("setae",      1,              (P) aptb1SETNB ) \
        X("setb",       1,              (P) aptb1SETB ) \
        X("setbe",      1,              (P) aptb1SETBE ) \
        X("setc",       1,              (P) aptb1SETB ) \
        X("sete",       1,              (P) aptb1SETZ ) \
        X("setg",       1,              (P) aptb1SETNLE ) \
        X("setge",      1,              (P) aptb1SETNL ) \
        X("setl",       1,              (P) aptb1SETL ) \
        X("setle",      1,              (P) aptb1SETLE ) \
        X("setna",      1,              (P) aptb1SETBE ) \
        X("setnae",     1,              (P) aptb1SETB ) \
        X("setnb",      1,              (P) aptb1SETNB ) \
        X("setnbe",     1,              (P) aptb1SETNBE ) \
        X("setnc",      1,              (P) aptb1SETNB ) \
        X("setne",      1,              (P) aptb1SETNZ ) \
        X("setng",      1,              (P) aptb1SETLE ) \
        X("setnge",     1,              (P) aptb1SETL ) \
        X("setnl",      1,              (P) aptb1SETNL ) \
        X("setnle",     1,              (P) aptb1SETNLE ) \
        X("setno",      1,              (P) aptb1SETNO ) \
        X("setnp",      1,              (P) aptb1SETNP ) \
        X("setns",      1,              (P) aptb1SETNS ) \
        X("setnz",      1,              (P) aptb1SETNZ ) \
        X("seto",       1,              (P) aptb1SETO ) \
        X("setp",       1,              (P) aptb1SETP ) \
        X("setpe",      1,              (P) aptb1SETP ) \
        X("setpo",      1,              (P) aptb1SETNP ) \
        X("sets",       1,              (P) aptb1SETS ) \
        X("setz",       1,              (P) aptb1SETZ ) \
        X("sfence",     0,              aptb0SFENCE) \
        X("sgdt",       1,              (P) aptb1SGDT ) \
        X("shl",        ITshift | 2,    (P) aptb2SHL ) \
        X("shld",       3,              (P) aptb3SHLD ) \
        X("shr",        ITshift | 2,    (P) aptb2SHR ) \
        X("shrd",       3,              (P) aptb3SHRD ) \
        X("shufpd",     3,              (P) aptb3SHUFPD ) \
        X("shufps",     3,              (P) aptb3SHUFPS ) \
        X("sidt",       1,              (P) aptb1SIDT ) \
        X("sldt",       1,              (P) aptb1SLDT ) \
        X("smsw",       1,              (P) aptb1SMSW ) \
        X("sqrtpd",     2,              (P) aptb2SQRTPD ) \
        X("sqrtps",     2,              (P) aptb2SQRTPS ) \
        X("sqrtsd",     2,              (P) aptb2SQRTSD ) \
        X("sqrtss",     2,              (P) aptb2SQRTSS ) \
        X("stc",        0,              aptb0STC ) \
        X("std",        0,              aptb0STD ) \
        X("sti",        0,              aptb0STI ) \
        X("stmxcsr",    1,              (P) aptb1STMXCSR ) \
        X("stos",       1,              (P) aptb1STOS ) \
        X("stosb",      0,              aptb0STOSB ) \
        X("stosd",      0,              aptb0STOSD ) \
        X("stosq",      0,              aptb0STOSQ ) \
        X("stosw",      0,              aptb0STOSW ) \
        X("str",        1,              (P) aptb1STR ) \
        X("sub",        2,              (P) aptb2SUB ) \
        X("subpd",      2,              (P) aptb2SUBPD ) \
        X("subps",      2,              (P) aptb2SUBPS ) \
        X("subsd",      2,              (P) aptb2SUBSD ) \
        X("subss",      2,              (P) aptb2SUBSS ) \
        X("syscall",    0,              aptb0SYSCALL ) \
        X("sysenter",   0,              aptb0SYSENTER ) \
        X("sysexit",    0,              aptb0SYSEXIT ) \
        X("sysret",     0,              aptb0SYSRET ) \
        X("test",       2,              (P) aptb2TEST ) \
        X("ucomisd",    2,              (P) aptb2UCOMISD ) \
        X("ucomiss",    2,              (P) aptb2UCOMISS ) \
        X("ud2",        0,              aptb0UD2 ) \
        X("unpckhpd",   2,              (P) aptb2UNPCKHPD ) \
        X("unpckhps",   2,              (P) aptb2UNPCKHPS ) \
        X("unpcklpd",   2,              (P) aptb2UNPCKLPD ) \
        X("unpcklps",   2,              (P) aptb2UNPCKLPS ) \
        X("verr",       1,              (P) aptb1VERR ) \
        X("verw",       1,              (P) aptb1VERW ) \
        X("wait",       0,              aptb0WAIT ) \
        X("wbinvd",     0,              aptb0WBINVD ) \
        X("wrmsr",      0,              aptb0WRMSR ) \
        X("xadd",       2,              (P) aptb2XADD ) \
        X("xchg",       2,              (P) aptb2XCHG ) \
        X("xlat",       ITopt | 1,      (P) aptb1XLAT ) \
        X("xlatb",      0,              aptb0XLATB ) \
        X("xor",        2,              (P) aptb2XOR ) \
        X("xorpd",      2,              (P) aptb2XORPD ) \
        X("xorps",      2,              (P) aptb2XORPS ) \

#endif

static const char *opcodestr[] =
{
    #define X(a,b,c)    a,
        OPCODETABLE1
        OPCODETABLE2
    #undef X
};

static OP optab[] =
{
    #define X(a,b,c)    b,c,
        OPCODETABLE1
        OPCODETABLE2
    #undef X
};


/*******************************
 */

const char *asm_opstr(OP *pop)
{
    return opcodestr[pop - optab];
}

/*******************************
 */

OP *asm_op_lookup(const char *s)
{
    OP  *pop;
    int i;
    char szBuf[12];

    //dbg_printf("asm_op_lookup('%s')\n",s);
    if (strlen(s) >= sizeof(szBuf))
        return NULL;
    strcpy(szBuf,s);
#if SCPP
    strlwr(szBuf);
#endif

    i = binary(szBuf,opcodestr,sizeof(opcodestr)/sizeof(opcodestr[0]));
    return (i == -1) ? NULL : &optab[i];
}

/*******************************
 */

void init_optab()
{   int i;

#ifdef DEBUG
    for (i = 0; i < arraysize(opcodestr) - 1; i++)
    {
        if (strcmp(opcodestr[i],opcodestr[i + 1]) >= 0)
        {
            dbg_printf("opcodestr[%d] = '%s', [%d] = '%s'\n",i,opcodestr[i],i + 1,opcodestr[i + 1]);
            assert(0);
        }
    }
#endif
}



#endif // !SPP
