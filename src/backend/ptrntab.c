// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2012 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
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
#include        "global.h"
#include        "xmm.h"

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
OPTABLE0(RDTSCP,  0x0f01f9, _I386 | _modaxdx | _modcx);
OPTABLE0(WRMSR,   0x0f30, _I386);
OPTABLE0(RSM,     0x0faa,_i64_bit | _I386);

//
// Now come the one operand instructions
// These will prove to be a little more challenging than the 0
// operand instructions
//
PTRNTAB1 aptb1BSWAP[] = /* BSWAP */ {
                                // Really is a 486 only instruction
        { 0x0fc8,   _I386, _plus_r | _r32 },
        { 0x0fc8, _64_bit, _plus_r | _r64 },
        { ASM_END }
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
        { ASM_END }
};

PTRNTAB1 aptb1DEC[] = /* DEC */ {
        { 0xfe, _1,                        _rm8 },
        { 0x48, _rw | _i64_bit | _16_bit,  _r16 | _plus_r },
        { 0x48, _rd | _i64_bit | _32_bit,  _r32 | _plus_r },
        { 0xff, _1  |            _16_bit,  _rm16 },
        { 0xff, _1  |            _32_bit,  _rm32 },
        { 0xff, _1  |            _64_bit,  _rm64 },
        { ASM_END }
};

PTRNTAB1 aptb1INC[] = /* INC */ {
        { 0xfe, _0,                        _rm8 },
        { 0x40, _rw | _i64_bit | _16_bit,  _r16 | _plus_r },
        { 0x40, _rd | _i64_bit | _32_bit,  _r32 | _plus_r },
        { 0xff, _0  |            _16_bit,  _rm16 },
        { 0xff, _0  |            _32_bit,  _rm32 },
        { 0xff, _0  |            _64_bit,  _rm64 },
        { ASM_END }
};
// INT and INT 3
PTRNTAB1 aptb1INT[]= /* INT */ {
        { 0xcc, 3,              0 },    // The ulFlags here are meant to
                                        // be the value of the immediate
                                        // operand
        { 0xcd, 0,              _imm8 },
        { ASM_END }
};
PTRNTAB1 aptb1INVLPG[] = /* INVLPG */ {         // 486 only instruction
        { 0x0f01,       _I386|_7, _m8 | _m16 | _m32 | _m48 },
        { ASM_END }
};

#define OPTABLE(str,op) \
PTRNTAB1 aptb1##str[] = {                    \
        { 0x70|op,   _cb,         _rel8 },   \
        { 0x0f80|op, _cw|_i64_bit,_rel16 },  \
        { 0x0f80|op, _cd,         _rel32 },  \
        { ASM_END }                          \
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
        { ASM_END }
};
PTRNTAB1 aptb1JECXZ[] = /* JECXZ */ {
        { 0xe3, _cb | _32_bit_addr | _I386,_rel8 },
        { ASM_END }
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
        { ASM_END }
};
PTRNTAB1 aptb1LGDT[] = /* LGDT */ {
        { 0x0f01,       _2,     _m48 },
        { ASM_END }
};
PTRNTAB1 aptb1LIDT[] = /* LIDT */ {
        { 0x0f01,       _3,     _m48 },
        { ASM_END }
};
PTRNTAB1 aptb1LLDT[] = /* LLDT */ {
        { 0x0f00,       _2|_modnot1,    _rm16 },
        { ASM_END }
};
PTRNTAB1 aptb1LMSW[] = /* LMSW */ {
        { 0x0f01,       _6|_modnot1,    _rm16 },
        { ASM_END }
};
PTRNTAB1 aptb1LODS[] = /* LODS */ {
        { 0xac, _modax,_m8 },
        { 0xad, _16_bit | _modax,_m16 },
        { 0xad, _32_bit | _I386 | _modax,_m32 },
        { ASM_END }
};
PTRNTAB1 aptb1LOOP[] = /* LOOP */ {
        { 0xe2, _cb | _modcx,_rel8 },
        { ASM_END }
};
PTRNTAB1 aptb1LOOPE[] = /* LOOPE/LOOPZ */ {
        { 0xe1, _cb | _modcx,_rel8 },
        { ASM_END }
};
PTRNTAB1 aptb1LOOPNE[] = /* LOOPNE/LOOPNZ */ {
        { 0xe0, _cb | _modcx,_rel8 },
        { ASM_END }
};
PTRNTAB1 aptb1LTR[] = /* LTR */ {
        { 0x0f00,       _3|_modnot1,    _rm16 },
        { ASM_END }
};
PTRNTAB1 aptb1NEG[] = /* NEG */ {
        { 0xf6, _3,     _rm8 },
        { 0xf7, _3 | _16_bit,   _rm16 },
        { 0xf7, _3 | _32_bit,   _rm32 },
        { 0xf7, _3 | _64_bit,   _rm64 },
        { ASM_END }
};
PTRNTAB1 aptb1NOT[] = /* NOT */ {
        { 0xf6, _2,     _rm8 },
        { 0xf7, _2 | _16_bit,   _rm16 },
        { 0xf7, _2 | _32_bit,   _rm32 },
        { 0xf7, _2 | _64_bit,   _rm64 },
        { ASM_END }
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
        { ASM_END }
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
        { ASM_END }
};
PTRNTAB1 aptb1RET[] = /* RET */ {
        { 0xc3, 0,      0 },
        { 0xc2, _iw,    _imm16 },
        { ASM_END }
};
PTRNTAB1 aptb1RETF[] = /* RETF */ {
        { 0xcb, 0, 0 },
        { 0xca, _iw, _imm16 },
        { ASM_END }
};
PTRNTAB1 aptb1SCAS[] = /* SCAS */ {
        { 0xae, _moddi, _m8 },
        { 0xaf, _16_bit | _moddi, _m16 },
        { 0xaf, _32_bit | _moddi, _m32 },
        { ASM_END }
};

#define OPTABLE(str,op) \
PTRNTAB1 aptb1##str[] = {       \
        { 0xf90|op, _cb, _rm8 },        \
        { ASM_END }                     \
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
        { ASM_END }
};
PTRNTAB1  aptb1SIDT[] = /* SIDT */ {
        { 0xf01, _1, _m48 },
        { ASM_END }
};
PTRNTAB1  aptb1SLDT[] = /* SLDT */ {
        { 0xf00, _0, _rm16 },
        { ASM_END }
};
PTRNTAB1  aptb1SMSW[] = /* SMSW */ {
        { 0xf01, _4, _rm16 },
        { 0xf01, _4, _r32 },
        { ASM_END }
};
PTRNTAB1  aptb1STOS[] = /* STOS */ {
        { 0xaa, _moddi, _m8 },
        { 0xab, _16_bit | _moddi, _m16 },
        { 0xab, _32_bit | _moddi, _m32 },
        { ASM_END }
};
PTRNTAB1  aptb1STR[] = /* STR */ {
        { 0xf00, _1, _rm16 },
        { ASM_END }
};
PTRNTAB1  aptb1VERR[] = /* VERR */ {
        { 0xf00, _4|_modnot1, _rm16 },
        { ASM_END }
};
PTRNTAB1  aptb1VERW[] = /* VERW */ {
        { 0xf00, _5|_modnot1, _rm16 },
        { ASM_END }
};
PTRNTAB1  aptb1XLAT[] = /* XLAT */ {
        { 0xd7, _modax, 0 },
        { 0xd7, _modax, _m8 },
        { ASM_END }
};
PTRNTAB1  aptb1CMPXCH8B[] = /* CMPXCH8B */ {
    { 0x0fc7, _1 | _modaxdx | _I386, _m64 },
        { ASM_END }
};

PTRNTAB1  aptb1CMPXCH16B[] = /* CMPXCH16B */ {
    { 0x0fc7, _1 | _modaxdx | _64_bit, _m64 },
        { ASM_END }
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
        { ASM_END }                                             \
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
        { ASM_END }
};
PTRNTAB2  aptb2BOUND[] = /* BOUND */ {
        { 0x62, _r|_i64_bit|_16_bit|_modnot1,_r16,_m16 },// Should really b3 _m16_16
        { 0x62, _r|_i64_bit|_32_bit|_modnot1,_r32,_m32 },// Should really be _m32_32
        { ASM_END }
};
PTRNTAB2  aptb2BSF[] = /* BSF */ {
        { 0x0fbc,       _cw | _16_bit,          _r16,   _rm16 },
        { 0x0fbc,       _cd|_32_bit,            _r32,   _rm32 },
        { 0x0fbc,       _cq|_64_bit,            _r64,   _rm64 },
        { ASM_END }
};
PTRNTAB2  aptb2BSR[] = /* BSR */ {
        { 0x0fbd,       _cw|_16_bit,            _r16,   _rm16 },
        { 0x0fbd,       _cd|_32_bit,            _r32,   _rm32 },
        { 0x0fbd,       _cq|_64_bit,            _r64,   _rm64 },
        { ASM_END }
};
PTRNTAB2  aptb2BT[] = /* BT */ {
        { 0x0fa3,       _cw|_16_bit|_modnot1,           _rm16,  _r16 },
        { 0x0fa3,       _cd|_32_bit|_modnot1,           _rm32,  _r32 },
        { 0x0fa3,       _cq|_64_bit|_modnot1,           _rm64,  _r64 },
        { 0x0fba,       _4|_ib|_16_bit|_modnot1,        _rm16,  _imm8 },
        { 0x0fba,       _4|_ib|_32_bit|_modnot1,        _rm32,  _imm8 },
        { 0x0fba,       _4|_ib|_64_bit|_modnot1,        _rm64,  _imm8 },
        { ASM_END }
};
PTRNTAB2  aptb2BTC[] = /* BTC */ {
        { 0x0fbb,       _cw|_16_bit,            _rm16,  _r16 },
        { 0x0fbb,       _cd|_32_bit,            _rm32,  _r32 },
        { 0x0fbb,       _cq|_64_bit,            _rm64,  _r64 },
        { 0x0fba,       _7|_ib|_16_bit, _rm16,  _imm8 },
        { 0x0fba,       _7|_ib|_32_bit, _rm32,  _imm8 },
        { 0x0fba,       _7|_ib|_64_bit, _rm64,  _imm8 },
        { ASM_END }
};
PTRNTAB2  aptb2BTR[] = /* BTR */ {
        { 0x0fb3,       _cw|_16_bit,            _rm16,  _r16 },
        { 0x0fb3,       _cd|_32_bit,            _rm32,  _r32 },
        { 0x0fb3,       _cq|_64_bit,            _rm64,  _r64 },
        { 0x0fba,       _6|_ib|_16_bit,         _rm16,  _imm8 },
        { 0x0fba,       _6|_ib|_32_bit,         _rm32,  _imm8 },
        { 0x0fba,       _6|_ib|_64_bit,         _rm64,  _imm8 },
        { ASM_END }
};
PTRNTAB2  aptb2BTS[] = /* BTS */ {
        { 0x0fab,       _cw|_16_bit,            _rm16,  _r16 },
        { 0x0fab,       _cd|_32_bit,            _rm32,  _r32 },
        { 0x0fab,       _cq|_64_bit,            _rm64,  _r64 },
        { 0x0fba,       _5|_ib|_16_bit,         _rm16,  _imm8 },
        { 0x0fba,       _5|_ib|_32_bit,         _rm32,  _imm8 },
        { 0x0fba,       _5|_ib|_64_bit,         _rm64,  _imm8 },
        { ASM_END }
};
PTRNTAB2  aptb2CMPS[] = /* CMPS */ {
        { 0xa6, _modsidi,               _m8,    _m8 },
        { 0xa7, _modsidi,       _m16,   _m16 },
        { 0xa7, _modsidi,       _m32,   _m32 },
        { ASM_END }
};
PTRNTAB2  aptb2CMPXCHG[] = /* CMPXCHG */ {
        { 0xfb0, _I386 | _cb|_mod2,     _rm8,   _r8 },
                                                // This is really a 486 only
                                                // instruction
        { 0xfb1, _I386 | _cw | _16_bit|_mod2,   _rm16,  _r16 },
        { 0xfb1, _I386 | _cd | _32_bit|_mod2,   _rm32,  _r32 },
        { 0xfb1, _I386 | _cq | _64_bit|_mod2,   _rm64,  _r64 },
        { ASM_END }
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
        { ASM_END }
};
PTRNTAB2  aptb2ENTER[] = /* ENTER */ {
        { 0xc8, _iw|_ib,        _imm16, _imm8 },
        { ASM_END }
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
        { ASM_END }
};
PTRNTAB2  aptb2IN[] = /* IN */ {
        { 0xe4, _ib,        _al,                _imm8 },
        { 0xe5, _ib|_16_bit,_ax,                _imm8 },
        { 0xe5, _ib|_32_bit,_eax,       _imm8 },
        { 0xec, 0,          _al,                _dx },
        { 0xed, _16_bit,    _ax,                _dx },
        { 0xed, _32_bit,    _eax,       _dx },
        { ASM_END }
};
PTRNTAB2  aptb2INS[] = /* INS */ {
        { 0x6c, _modsi, _rm8, _dx },
        { 0x6d, _modsi|_16_bit, _rm16, _dx },
        { 0x6d, _32_bit|_modsi, _rm32, _dx },
        { ASM_END }
};

PTRNTAB2  aptb2LAR[] = /* LAR */ {
        { 0x0f02,       _r|_16_bit,                     _r16,   _rm16 },
        { 0x0f02,       _r|_32_bit,                     _r32,   _rm32 },
        { ASM_END }
};
PTRNTAB2  aptb2LDS[] = /* LDS */ {
        { 0xc5, _r|_i64_bit|_16_bit,                    _r16,   _m32 },
        { 0xc5, _r|_i64_bit|_32_bit,                    _r32,   _m48 },
        { ASM_END }
};

PTRNTAB2  aptb2LEA[] = /* LEA */ {
        { 0x8d, _r|_16_bit,             _r16,   _m8 | _m16 | _m32 | _m48 },
        { 0x8d, _r|_32_bit,             _r32,   _m8 | _m16 | _m32 | _m48 },
        { 0x8d, _r|_64_bit,             _r64,   _m8 | _m16 | _m32 | _m48 | _m64 },
        { 0x8d, _r|_16_bit,             _r16,   _rel16 },
        { 0x8d, _r|_32_bit,             _r32,   _rel32 },
        { 0x8d, _r|_64_bit,             _r64,   _rel32 },
        { ASM_END }
};
PTRNTAB2  aptb2LES[] = /* LES */ {
        { 0xc4, _r|_i64_bit|_16_bit|_modes,             _r16,   _m32 },
        { 0xc4, _r|_i64_bit|_32_bit|_modes,             _r32,   _m48 },
        { ASM_END }
};
PTRNTAB2  aptb2LFS[] = /* LFS */ {
        { 0x0fb4,       _r|_16_bit,                     _r16,   _m32 },
        { 0x0fb4,       _r|_32_bit,                     _r32,   _m48 },
        { ASM_END }
};
PTRNTAB2  aptb2LGS[] = /* LGS */ {
        { 0x0fb5,       _r|_16_bit,                     _r16,   _m32  },
        { 0x0fb5,       _r|_32_bit,                     _r32,   _m48 },
        { ASM_END }
};
PTRNTAB2  aptb2LSS[] = /* LSS */ {
        { 0x0fb2,       _r|_16_bit,                     _r16,   _m32 },
        { 0x0fb2,       _r|_32_bit,                     _r32,   _m48 },
        { ASM_END }
};
PTRNTAB2  aptb2LSL[] = /* LSL */ {
        { 0x0f03,       _r|_16_bit,                     _r16,   _rm16 },
        { 0x0f03,       _r|_32_bit,                     _r32,   _rm32 },
        { ASM_END }
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
        { ASM_END }
};

PTRNTAB2  aptb2MOVS[] = /* MOVS */ {
        { 0xa4, _modsidi ,              _m8,    _m8 },
        { 0xa5, _modsidi | _16_bit,     _m16,   _m16 },
        { 0xa5, _modsidi | _32_bit,     _m32,   _m32 },
        { ASM_END }
};
PTRNTAB2  aptb2MOVSX[] = /* MOVSX */ {
        { 0x0fbe,       _r|_16_bit,             _r16,   _rm8 },
        { 0x0fbe,       _r|_32_bit,             _r32,   _rm8 },
        { 0x0fbe,       _r|_64_bit,             _r64,   _rm8 },  // TODO: REX_W override is implicit
        { 0x0fbf,       _r|_16_bit,             _r16,   _rm16 },
        { 0x0fbf,       _r|_32_bit,             _r32,   _rm16 },
        { 0x0fbf,       _r|_64_bit,             _r64,   _rm16 }, // TODO: REX_W override is implicit
        { ASM_END }
};
PTRNTAB2  aptb2MOVSXD[] = /* MOVSXD */ {
        { 0x63,         _r|_64_bit,             _r64,   _rm32 }, // TODO: REX_W override is implicit
        { ASM_END }
};
PTRNTAB2  aptb2MOVZX[] = /* MOVZX */ {
        { 0x0fb6,       _r|_16_bit,             _r16,   _rm8 },
        { 0x0fb6,       _r|_32_bit,             _r32,   _rm8 },
        { 0x0fb6,       _r|_64_bit,             _r64,   _rm8 },  // TODO: REX_W override is implicit
        { 0x0fb7,       _r|_16_bit,             _r16,   _rm16 },
        { 0x0fb7,       _r|_32_bit,             _r32,   _rm16 },
        { 0x0fb7,       _r|_64_bit,             _r64,   _rm16 }, // TODO: REX_W override is implicit
        { ASM_END }
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
        { ASM_END }
};
PTRNTAB2  aptb2OUT[] = /* OUT */ {
        { 0xe6, _ib,            _imm8,  _al },
        { 0xe7, _ib|_16_bit,            _imm8,  _ax },
        { 0xe7, _ib|_32_bit,            _imm8,  _eax },
        { 0xee, _modnot1,               _dx,            _al },
        { 0xef, _16_bit|_modnot1,               _dx,            _ax },
        { 0xef, _32_bit|_modnot1,               _dx,            _eax },
        { ASM_END }
};
PTRNTAB2  aptb2OUTS[] = /* OUTS */ {
        { 0x6e, _modsinot1,             _dx,            _rm8 },
        { 0x6f, _16_bit | _I386 |_modsinot1,    _dx,            _rm16 },
        { 0x6f, _32_bit | _I386| _modsinot1,    _dx,            _rm32 },
        { ASM_END }
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
        { ASM_END }                                     \
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
        { ASM_END }
};
PTRNTAB2  aptb2XADD[] = /* XADD */ {                    // 486 only instruction
//      { 0x0fc0,       _ib | _I386|_mod2, _rm8, _r8 },
//      { 0x0fc1,       _iw | _I386|_16_bit|_mod2, _rm16, _r16 },
//      { 0x0fc1,       _id | _I386|_32_bit|_mod2, _rm32, _r32 },
        { 0x0fc0,       _r | _I386|_mod2, _rm8, _r8 },
        { 0x0fc1,       _r | _I386|_16_bit|_mod2, _rm16, _r16 },
        { 0x0fc1,       _r | _I386|_32_bit|_mod2, _rm32, _r32 },
        { 0x0fc1,       _r | _64_bit|_mod2, _rm64, _r64 },
        { ASM_END }
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
        { ASM_END }
};

#define OPTABLE(str,op) \
PTRNTAB2  aptb2##str[] = {      \
        { 0x0F40|op, _r|_16_bit,   _r16,   _rm16 },     \
        { 0x0F40|op, _r|_32_bit,   _r32,   _rm32 },     \
        { 0x0F40|op, _r|_64_bit,   _r64,   _rm64 },     \
        { ASM_END }    \
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
        { ASM_END }
};
PTRNTAB3  aptb3SHLD[] = /* SHLD */ {
        { 0x0fa4,       _cw|_16_bit, _rm16, _r16, _imm8 },
        { 0x0fa4,       _cd|_32_bit, _rm32, _r32, _imm8 },
        { 0x0fa4,       _cq|_64_bit, _rm64, _r64, _imm8 },
        { 0x0fa5,       _cw|_16_bit, _rm16, _r16, _cl },
        { 0x0fa5,       _cd|_32_bit, _rm32, _r32, _cl },
        { 0x0fa5,       _cq|_64_bit, _rm64, _r64, _cl },
        { ASM_END }
};
PTRNTAB3  aptb3SHRD[] = /* SHRD */ {
        { 0x0fac,       _cw|_16_bit, _rm16, _r16, _imm8 },
        { 0x0fac,       _cd|_32_bit, _rm32, _r32, _imm8 },
        { 0x0fac,       _cq|_64_bit, _rm64, _r64, _imm8 },
        { 0x0fad,       _cw|_16_bit, _rm16, _r16, _cl },
        { 0x0fad,       _cd|_32_bit, _rm32, _r32, _cl },
        { 0x0fad,       _cq|_64_bit, _rm64, _r64, _cl },
        { ASM_END }
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
        { ASM_END }
};

PTRNTAB1  aptb1FBSTP[] = /* FBSTP */ {
        { 0xdf, _6, _fm80 },
        { ASM_END }
};
PTRNTAB2  aptb2FCMOVB[] = /* FCMOVB */ {
        { 0xdac0, 0, _st, _sti | _plus_r },
        { 0xdac1, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FCMOVE[] = /* FCMOVE */ {
        { 0xdac8, 0, _st, _sti | _plus_r },
        { 0xdac9, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FCMOVBE[] = /* FCMOVBE */ {
        { 0xdad0, 0, _st, _sti | _plus_r },
        { 0xdad1, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FCMOVU[] = /* FCMOVU */ {
        { 0xdad8, 0, _st, _sti | _plus_r },
        { 0xdad9, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FCMOVNB[] = /* FCMOVNB */ {
        { 0xdbc0, 0, _st, _sti | _plus_r },
        { 0xdbc1, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FCMOVNE[] = /* FCMOVNE */ {
        { 0xdbc8, 0, _st, _sti | _plus_r },
        { 0xdbc9, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FCMOVNBE[] = /* FCMOVNBE */ {
        { 0xdbd0, 0, _st, _sti | _plus_r },
        { 0xdbd1, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FCMOVNU[] = /* FCMOVNU */ {
        { 0xdbd8, 0, _st, _sti | _plus_r },
        { 0xdbd9, 0, 0 },
        { ASM_END }
};
PTRNTAB1  aptb1FCOM[] = /* FCOM */ {
        { 0xd8, _2, _m32 },
        { 0xdc, _2, _fm64 },
        { 0xd8d0, 0, _sti | _plus_r },
        { 0xd8d1, 0, 0 },
        { ASM_END }
};

PTRNTAB2  aptb2FCOMI[] = /* FCOMI */ {
        { 0xdbf0, 0, _st, _sti | _plus_r },
        { 0xdbf0, 0, _sti | _plus_r, 0 },
        { 0xdbf1, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FCOMIP[] = /* FCOMIP */ {
        { 0xdff0, 0, _st, _sti | _plus_r },
        { 0xdff0, 0, _sti | _plus_r, 0 },
        { 0xdff1, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FUCOMI[] = /* FUCOMI */ {
        { 0xdbe8, 0, _st, _sti | _plus_r },
        { 0xdbe8, 0, _sti | _plus_r, 0 },
        { 0xdbe9, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FUCOMIP[] = /* FUCOMIP */ {
        { 0xdfe8, 0, _st, _sti | _plus_r },
        { 0xdfe8, 0, _sti | _plus_r, 0 },
        { 0xdfe9, 0, 0, 0 },
        { ASM_END }
};

PTRNTAB1  aptb1FCOMP[] = /* FCOMP */ {
        { 0xd8, _3, _m32 },
        { 0xdc, _3, _fm64 },
        { 0xd8d8, 0, _sti | _plus_r },
        { 0xd8d9, 0, 0 },
        { ASM_END }
};
PTRNTAB1  aptb1FFREE[] = /* FFREE */ {
        { 0xddc0,       0,      _sti | _plus_r },
        { ASM_END }
};
PTRNTAB1  aptb1FICOM[] = /* FICOM */ {
        { 0xde, _2, _m16 },
        { 0xda, _2, _m32 },
        { ASM_END }
};
PTRNTAB1  aptb1FICOMP[] = /* FICOMP */ {
        { 0xde, _3, _m16 },
        { 0xda, _3, _m32 },
        { ASM_END }
};
PTRNTAB1  aptb1FILD[] = /* FILD */ {
        { 0xdf, _0, _m16 },
        { 0xdb, _0, _m32 },
        { 0xdf, _5, _fm64 },
        { ASM_END }
};
PTRNTAB1  aptb1FIST[] = /* FIST */      {
        { 0xdf, _2, _m16 },
        { 0xdb, _2, _m32 },
        { ASM_END }
};
PTRNTAB1  aptb1FISTP[] = /* FISTP */ {
        { 0xdf, _3, _m16 },
        { 0xdb, _3, _m32 },
        { 0xdf, _7, _fm64 },
        { ASM_END }
};
PTRNTAB1  aptb1FLD[] = /* FLD */ {
        { 0xd9, _0, _m32 },
        { 0xdd, _0, _fm64 },
        { 0xdb, _5, _fm80 },
        { 0xd9c0, 0, _sti | _plus_r },
        { ASM_END }
};
PTRNTAB1  aptb1FLDCW[] = /* FLDCW */ {
        { 0xd9, _5, _m16 },
        { ASM_END }
};
PTRNTAB1  aptb1FLDENV[] = /* FLDENV */ {
        { 0xd9, _4, _m112 | _m224 },
        { ASM_END }
};
PTRNTAB1  aptb1FRSTOR[] = /* FRSTOR */ {
        { 0xdd, _4, _m112 | _m224 },
        { ASM_END }
};
PTRNTAB1  aptb1FSAVE[] = /* FSAVE */ {
        { 0xdd, _6 | _fwait, _m112 | _m224 },
        { ASM_END }
};
PTRNTAB1  aptb1FNSAVE[] = /* FNSAVE */ {
        { 0xdd, _6 | _nfwait, _m112 | _m224 },
        { ASM_END }
};
PTRNTAB1  aptb1FST[] = /* FST */ {
        { 0xd9, _2, _m32 },
        { 0xdd, _2, _fm64 },
        { 0xddd0, 0, _sti | _plus_r },
        { ASM_END }
};

PTRNTAB1  aptb1FSTP[] = /* FSTP */ {
        { 0xd9, _3, _m32 },
        { 0xdd, _3, _fm64 },
        { 0xdb, _7, _fm80 },
        { 0xddd8, 0, _sti | _plus_r },
        { ASM_END }
};
PTRNTAB1  aptb1FSTCW[] = /* FSTCW */ {
        { 0xd9, _7 | _fwait , _m16 },
        { ASM_END }
};
PTRNTAB1  aptb1FNSTCW[] = /* FNSTCW */ {
        { 0xd9, _7 | _nfwait , _m16 },
        { ASM_END }
};
PTRNTAB1  aptb1FSTENV[] = /* FSTENV */ {
        { 0xd9, _6 | _fwait, _m112 | _m224 },
        { ASM_END }
};
PTRNTAB1  aptb1FNSTENV[] = /* FNSTENV */ {
        { 0xd9, _6 | _nfwait, _m112 | _m224 },
        { ASM_END }
};
PTRNTAB1  aptb1FSTSW[] = /* FSTSW */ {
        { 0xdd, _7 | _fwait, _m16 },
        { 0xdfe0, _fwait | _modax, _ax },
        { ASM_END }
};
PTRNTAB1  aptb1FNSTSW[] = /* FNSTSW */ {
        { 0xdd, _7 | _nfwait, _m16 },
        { 0xdfe0, _nfwait | _modax, _ax },
        { ASM_END }
};
PTRNTAB1  aptb1FUCOM[] = /* FUCOM */ {
        { 0xdde0, 0, _sti | _plus_r },
        { 0xdde1, 0, 0 },
        { ASM_END }
};
PTRNTAB1  aptb1FUCOMP[] = /* FUCOMP */ {
        { 0xdde8, 0, _sti | _plus_r },
        { 0xdde9, 0, 0 },
        { ASM_END }
};
PTRNTAB1  aptb1FXCH[] = /* FXCH */ {
        { 0xd9c8, 0, _sti | _plus_r },
        { 0xd9c9, 0, 0 },
        { ASM_END }
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
        { ASM_END }
};

PTRNTAB2  aptb2FADDP[] = /* FADDP */ {
        { 0xdec0, 0, _sti | _plus_r, _st },
        { 0xdec1, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FIADD[] = /* FIADD */ {
        { 0xda, _0, _m32, 0 },
        { 0xde, _0, _m16, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FDIV[] = /* FDIV */ {
        { 0xd8, _6, _m32, 0 },
        { 0xdc, _6, _fm64, 0 },
        { 0xd8f0, 0, _st, _sti | _plus_r },
        { 0xdcf8, 0, _sti | _plus_r, _st },
        { 0xdef9, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FDIVP[] = /* FDIVP */ {
        { 0xdef9, 0, 0, 0 },
        { 0xdef8, 0, _sti | _plus_r, _st },
        { ASM_END }
};
PTRNTAB2  aptb2FIDIV[] = /* FIDIV */ {
        { 0xda, _6,  _m32, 0 },
        { 0xde, _6,  _m16, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FDIVR[] = /* FDIVR */ {
        { 0xd8, _7, _m32, 0 },
        { 0xdc, _7, _fm64, 0 },
        { 0xd8f8, 0, _st, _sti | _plus_r },
        { 0xdcf0, 0, _sti | _plus_r, _st },
        { 0xdef1, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FDIVRP[] = /* FDIVRP */ {
        { 0xdef1, 0, 0, 0 },
        { 0xdef0, 0, _sti | _plus_r, _st },
        { ASM_END }
};
PTRNTAB2  aptb2FIDIVR[] = /* FIDIVR */ {
        { 0xda, _7,  _m32, 0 },
        { 0xde, _7,  _m16, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FMUL[] = /* FMUL */ {
        { 0xd8, _1, _m32, 0 },
        { 0xdc, _1, _fm64, 0 },
        { 0xd8c8, 0, _st, _sti | _plus_r },
        { 0xdcc8, 0, _sti | _plus_r, _st },
        { 0xdec9, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FMULP[] = /* FMULP */ {
        { 0xdec8, 0, _sti | _plus_r, _st },
        { 0xdec9, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FIMUL[] = /* FIMUL */ {
        { 0xda, _1, _m32, 0 },
        { 0xde, _1, _m16, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FSUB[] = /* FSUB */ {
        { 0xd8, _4, _m32, 0 },
        { 0xdc, _4, _fm64, 0 },
        { 0xd8e0, 0, _st, _sti | _plus_r },
        { 0xdce8, 0, _sti | _plus_r, _st },
        { 0xdee9, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FSUBP[] = /* FSUBP */ {
        { 0xdee8, 0, _sti | _plus_r, _st },
        { 0xdee9, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FISUB[] = /* FISUB */ {
        { 0xda, _4, _m32, 0 },
        { 0xde, _4, _m16, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FSUBR[] = /* FSUBR */ {
        { 0xd8, _5, _m32, 0 },
        { 0xdc, _5, _fm64, 0 },
        { 0xd8e8, 0, _st, _sti | _plus_r },
        { 0xdce0, 0, _sti | _plus_r, _st },
        { 0xdee1, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FSUBRP[] = /* FSUBRP */ {
        { 0xdee0, 0, _sti | _plus_r, _st },
        { 0xdee1, 0, 0, 0 },
        { ASM_END }
};
PTRNTAB2  aptb2FISUBR[] = /* FISUBR */ {
        { 0xda, _5, _m32, 0 },
        { 0xde, _5, _m16, 0 },
        { ASM_END }
};

///////////////////////////// MMX Extensions /////////////////////////

PTRNTAB0 aptb0EMMS[] = /* EMMS */       {
        { 0x0F77, 0 }
};

PTRNTAB2 aptb2MOVD[] = /* MOVD */ {
        { 0x0F6E,_r,_mm,_rm32 },
        { 0x0F7E,_r,_rm32,_mm },
        { LODD,_r,_xmm,_rm32 },
        { STOD,_r,_rm32,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVD[] = /* VMOVD */ {
        { VEX_128_WIG(LODD), _r, _xmm, _rm32 },
        { VEX_128_WIG(STOD), _r, _rm32, _xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVQ[] = /* MOVQ */ {
        { 0x0F6F,_r,_mm,_mmm64 },
        { 0x0F7F,_r,_mmm64,_mm },
        { LODQ,_r,_xmm,_xmm_m64 },
        { STOQ,_r,_xmm_m64,_xmm },
        { 0x0F6E,  _r|_64_bit,_mm,  _rm64 },
        { 0x0F7E,  _r|_64_bit,_rm64,_mm   },
        { LODD,_r|_64_bit,_xmm, _rm64 },
        { STOD,_r|_64_bit,_rm64,_xmm  },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVQ[] = /* VMOVQ */ {
        { VEX_128_W1(LODD), _r, _xmm, _rm64 },
        { VEX_128_W1(STOD), _r, _rm64, _xmm },
        { ASM_END }
};

PTRNTAB2 aptb2PACKSSDW[] = /* PACKSSDW */ {
        { 0x0F6B, _r,_mm,_mmm64 },
        { PACKSSDW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPACKSSDW[] = /* VPACKSSDW */ {
        { VEX_NDS_128_WIG(PACKSSDW), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PACKSSWB[] = /* PACKSSWB */ {
        { 0x0F63, _r,_mm,_mmm64 },
        { PACKSSWB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPACKSSWB[] = /* VPACKSSWB */ {
        { VEX_NDS_128_WIG(PACKSSWB), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PACKUSWB[] = /* PACKUSWB */ {
        { 0x0F67, _r,_mm,_mmm64 },
        { PACKUSWB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPACKUSWB[] = /* VPACKUSWB */ {
        { VEX_NDS_128_WIG(PACKUSWB), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDB[] = /* PADDB */ {
        { 0x0FFC, _r,_mm,_mmm64 },
        { PADDB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPADDB[] = /* VPADDB */ {
        { VEX_NDS_128_WIG(PADDB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDD[] = /* PADDD */ {
        { 0x0FFE, _r,_mm,_mmm64 },
        { PADDD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPADDD[] = /* VPADDD */ {
        { VEX_NDS_128_WIG(PADDD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDSB[] = /* PADDSB */ {
        { 0x0FEC, _r,_mm,_mmm64 },
        { PADDSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPADDSB[] = /* VPADDSB */ {
        { VEX_NDS_128_WIG(PADDSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDSW[] = /* PADDSW */ {
        { 0x0FED, _r,_mm,_mmm64 },
        { PADDSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPADDSW[] = /* VPADDSW */ {
        { VEX_NDS_128_WIG(PADDSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDUSB[] = /* PADDUSB */ {
        { 0x0FDC, _r,_mm,_mmm64 },
        { PADDUSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPADDUSB[] = /* VPADDUSB */ {
        { VEX_NDS_128_WIG(PADDUSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDUSW[] = /* PADDUSW */ {
        { 0x0FDD, _r,_mm,_mmm64 },
        { PADDUSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPADDUSW[] = /* VPADDUSW */ {
        { VEX_NDS_128_WIG(PADDUSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDW[] = /* PADDW */ {
        { 0x0FFD, _r,_mm,_mmm64 },
        { PADDW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPADDW[] = /* VPADDW */ {
        { VEX_NDS_128_WIG(PADDW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PAND[] = /* PAND */ {
        { 0x0FDB, _r,_mm,_mmm64 },
        { PAND, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPAND[] = /* VPAND */ {
        { VEX_NDS_128_WIG(PAND), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PANDN[] = /* PANDN */ {
        { 0x0FDF, _r,_mm,_mmm64 },
        { PANDN, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPANDN[] = /* VPANDN */ {
        { VEX_NDS_128_WIG(PANDN), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPEQB[] = /* PCMPEQB */ {
        { 0x0F74, _r,_mm,_mmm64 },
        { PCMPEQB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPEQB[] = /* VPCMPEQB */ {
        { VEX_NDS_128_WIG(PCMPEQB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPEQD[] = /* PCMPEQD */ {
        { 0x0F76, _r,_mm,_mmm64 },
        { PCMPEQD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPEQD[] = /* VPCMPEQD */ {
        { VEX_NDS_128_WIG(PCMPEQD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPEQW[] = /* PCMPEQW */ {
        { 0x0F75, _r,_mm,_mmm64 },
        { PCMPEQW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPEQW[] = /* VPCMPEQW */ {
        { VEX_NDS_128_WIG(PCMPEQW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPGTB[] = /* PCMPGTB */ {
        { 0x0F64, _r,_mm,_mmm64 },
        { PCMPGTB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPGTB[] = /* VPCMPGTB */ {
        { VEX_NDS_128_WIG(PCMPGTB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPGTD[] = /* PCMPGTD */ {
        { 0x0F66, _r,_mm,_mmm64 },
        { PCMPGTD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPGTD[] = /* VPCMPGTD */ {
        { VEX_NDS_128_WIG(PCMPGTD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPGTW[] = /* PCMPGTW */ {
        { 0x0F65, _r,_mm,_mmm64 },
        { PCMPGTW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPGTW[] = /* VPCMPGTW */ {
        { VEX_NDS_128_WIG(PCMPGTW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMADDWD[] = /* PMADDWD */ {
        { 0x0FF5, _r,_mm,_mmm64 },
        { PMADDWD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMADDWD[] = /* VPMADDWD */ {
        { VEX_NDS_128_WIG(PMADDWD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSLLW[] = /* PSLLW */ {
        { 0x0FF1, _r,_mm,_mmm64 },
        { 0x0F71, _6,_mm,_imm8 },
        { PSLLW, _r,_xmm,_xmm_m128 },
        { 0x660F71, _6,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSLLW[] = /* VPSLLW */ {
        { VEX_NDS_128_WIG(PSLLW), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F71), _6, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSLLD[] = /* PSLLD */ {
        { 0x0FF2, _r,_mm,_mmm64 },
        { 0x0F72, _6,_mm,_imm8 },
        { PSLLD, _r,_xmm,_xmm_m128 },
        { 0x660F72, _6,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSLLD[] = /* VPSLLD */ {
        { VEX_NDS_128_WIG(PSLLD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F72), _6, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSLLQ[] = /* PSLLQ */ {
        { 0x0FF3, _r,_mm,_mmm64 },
        { 0x0F73, _6,_mm,_imm8 },
        { PSLLQ, _r,_xmm,_xmm_m128 },
        { PSLLDQ & 0xFFFFFF, _6,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSLLQ[] = /* VPSLLQ */ {
        { VEX_NDS_128_WIG(PSLLQ), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG((PSLLDQ & 0xFFFFFF)), _6, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRAW[] = /* PSRAW */ {
        { 0x0FE1, _r,_mm,_mmm64 },
        { 0x0F71, _4,_mm,_imm8 },
        { PSRAW, _r,_xmm,_xmm_m128 },
        { 0x660F71, _4,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSRAW[] = /* VPSRAW */ {
        { VEX_NDS_128_WIG(PSRAW), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F71), _4, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRAD[] = /* PSRAD */ {
        { 0x0FE2, _r,_mm,_mmm64 },
        { 0x0F72, _4,_mm,_imm8 },
        { PSRAD, _r,_xmm,_xmm_m128 },
        { 0x660F72, _4,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSRAD[] = /* VPSRAD */ {
        { VEX_NDS_128_WIG(PSRAD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F72), _4, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRLW[] = /* PSRLW */ {
        { 0x0FD1, _r,_mm,_mmm64 },
        { 0x0F71, _2,_mm,_imm8 },
        { PSRLW, _r,_xmm,_xmm_m128 },
        { 0x660F71, _2,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSRLW[] = /* VPSRLW */ {
        { VEX_NDS_128_WIG(PSRLW), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F71), _2, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRLD[] = /* PSRLD */ {
        { 0x0FD2, _r,_mm,_mmm64 },
        { 0x0F72, _2,_mm,_imm8 },
        { PSRLD, _r,_xmm,_xmm_m128 },
        { 0x660F72, _2,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSRLD[] = /* VPSRLD */ {
        { VEX_NDS_128_WIG(PSRLD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F72), _2, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRLQ[] = /* PSRLQ */ {
        { 0x0FD3, _r,_mm,_mmm64 },
        { 0x0F73, _2,_mm,_imm8 },
        { PSRLQ, _r,_xmm,_xmm_m128 },
        { (PSLLDQ & 0xFFFFFF), _2,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSRLQ[] = /* VPSRLQ */ {
        { VEX_NDS_128_WIG(PSRLQ), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG((PSLLDQ & 0xFFFFFF)), _2, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBB[] = /* PSUBB */ {
        { 0x0FF8, _r,_mm,_mmm64 },
        { PSUBB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSUBB[] = /* VPSUBB */ {
        { VEX_NDS_128_WIG(PSUBB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBD[] = /* PSUBD */ {
        { 0x0FFA, _r,_mm,_mmm64 },
        { PSUBD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSUBD[] = /* VPSUBD */ {
        { VEX_NDS_128_WIG(PSUBD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBSB[] = /* PSUBSB */ {
        { 0x0FE8, _r,_mm,_mmm64 },
        { PSUBSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSUBSB [] = /* VPSUBSB  */ {
        { VEX_NDS_128_WIG(PSUBSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBSW[] = /* PSUBSW */ {
        { 0x0FE9, _r,_mm,_mmm64 },
        { PSUBSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSUBSW[] = /* VPSUBSW */ {
        { VEX_NDS_128_WIG(PSUBSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBUSB[] = /* PSUBUSB */ {
        { 0x0FD8, _r,_mm,_mmm64 },
        { PSUBUSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSUBUSB[] = /* VPSUBUSB */ {
        { VEX_NDS_128_WIG(PSUBUSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBUSW[] = /* PSUBUSW */ {
        { 0x0FD9, _r,_mm,_mmm64 },
        { PSUBUSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSUBUSW[] = /* VPSUBUSW */ {
        { VEX_NDS_128_WIG(PSUBUSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};


PTRNTAB2 aptb2PSUBW[] = /* PSUBW */ {
        { 0x0FF9, _r,_mm,_mmm64 },
        { PSUBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSUBW[] = /* VPSUBW */ {
        { VEX_NDS_128_WIG(PSUBW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKHBW[] = /* PUNPCKHBW */ {
        { 0x0F68, _r,_mm,_mmm64 },
        { PUNPCKHBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPUNPCKHBW[] = /* VPUNPCKHBW */ {
        { VEX_NDS_128_WIG(PUNPCKHBW), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKHDQ[] = /* PUNPCKHDQ */ {
        { 0x0F6A, _r,_mm,_mmm64 },
        { PUNPCKHDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPUNPCKHDQ[] = /* VPUNPCKHDQ */ {
        { VEX_NDS_128_WIG(PUNPCKHDQ), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKHWD[] = /* PUNPCKHWD */ {
        { 0x0F69, _r,_mm,_mmm64 },
        { PUNPCKHWD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPUNPCKHWD[] = /* VPUNPCKHWD */ {
        { VEX_NDS_128_WIG(PUNPCKHWD), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKLBW[] = /* PUNPCKLBW */ {
        { 0x0F60, _r,_mm,_mmm64 },
        { PUNPCKLBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPUNPCKLBW[] = /* VPUNPCKLBW */ {
        { VEX_NDS_128_WIG(PUNPCKLBW), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKLDQ[] = /* PUNPCKLDQ */ {
        { 0x0F62, _r,_mm,_mmm64 },
        { PUNPCKLDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPUNPCKLDQ[] = /* VPUNPCKLDQ */ {
        { VEX_NDS_128_WIG(PUNPCKLDQ), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKLWD[] = /* PUNPCKLWD */ {
        { 0x0F61, _r,_mm,_mmm64 },
        { PUNPCKLWD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPUNPCKLWD[] = /* VPUNPCKLWD */ {
        { VEX_NDS_128_WIG(PUNPCKLWD), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PXOR[] = /* PXOR */ {
        { 0x0FEF, _r,_mm,_mmm64 },
        { PXOR, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPXOR[] = /* VPXOR */ {
        { VEX_NDS_128_WIG(PXOR), _r,_xmm,_xmm,_xmm_m128 },
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
        { ASM_END }
};

PTRNTAB1  aptb1FXRSTOR[] = /* FXRSTOR */ {
        { 0x0FAE, _1, _m512 },
        { ASM_END }
};

PTRNTAB1  aptb1LDMXCSR[] = /* LDMXCSR */ {
        { 0x0FAE, _2, _m32 },
        { ASM_END }
};

PTRNTAB1  aptb1VLDMXCSR[] = /* VLDMXCSR */ {
        { VEX_128_WIG(0x0FAE), _2, _m32 },
        { ASM_END }
};

PTRNTAB1  aptb1STMXCSR[] = /* STMXCSR */ {
        { 0x0FAE, _3, _m32 },
        { ASM_END }
};

PTRNTAB1  aptb1VSTMXCSR[] = /* VSTMXCSR */ {
        { VEX_128_WIG(0x0FAE), _3, _m32 },
        { ASM_END }
};

PTRNTAB1  aptb1CLFLUSH[] = /* CLFLUSH */ {
        { 0x0FAE, _7, _m8 },
        { ASM_END }
};

PTRNTAB2 aptb2ADDPS[] = /* ADDPS */ {
        { ADDPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VADDPS[] = /* VADDPS */ {
        { VEX_NDS_128_WIG(ADDPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(ADDPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
};

PTRNTAB2 aptb2ADDPD[] = /* ADDPD */ {
        { ADDPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VADDPD[] = /* VADDPD */ {
        { VEX_NDS_128_WIG(ADDPD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(ADDPD), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2ADDSD[] = /* ADDSD */ {
        { ADDSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB3 aptb3VADDSD[] = /* VADDSD */ {
        { VEX_NDS_128_WIG(ADDSD), _r, _xmm, _xmm, _xmm_m64, },
        { ASM_END }
};

PTRNTAB2 aptb2ADDSS[] = /* ADDSS */ {
        { ADDSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VADDSS[] = /* VADDSS */ {
        { VEX_NDS_128_WIG(ADDSS), _r, _xmm, _xmm, _xmm_m32, },
        { ASM_END }
};

PTRNTAB2 aptb2ANDPD[] = /* ANDPD */ {
        { ANDPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VANDPD[] = /* VANDPD */ {
        { VEX_NDS_128_WIG(ANDPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ANDPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2ANDPS[] = /* ANDPS */ {
        { ANDPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VANDPS[] = /* VANDPS */ {
        { VEX_NDS_128_WIG(ANDPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ANDPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2ANDNPD[] = /* ANDNPD */ {
        { ANDNPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VANDNPD[] = /* VANDNPD */ {
        { VEX_NDS_128_WIG(ANDNPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ANDNPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2ANDNPS[] = /* ANDNPS */ {
        { ANDNPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VANDNPS[] = /* VANDNPS */ {
        { VEX_NDS_128_WIG(ANDNPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ANDNPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB3 aptb3CMPPS[] = /* CMPPS */ {
        { CMPPS, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VCMPPS[] = /* VCMPPS */ {
        { VEX_NDS_128_WIG(CMPPS), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(CMPPS), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3CMPPD[] = /* CMPPD */ {
        { CMPPD, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VCMPPD[] = /* VCMPPD */ {
        { VEX_NDS_128_WIG(CMPPD), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(CMPPD), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3CMPSD[] = /* CMPSD */ {
        { 0xa7, _32_bit | _I386 | _modsidi },
        { CMPSD, _r,_xmm,_xmm_m64,_imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VCMPSD[] = /* VCMPSD */ {
        { VEX_NDS_128_WIG(CMPSD), _r, _xmm, _xmm, _xmm_m64, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3CMPSS[] = /* CMPSS */ {
        { CMPSS, _r,_xmm,_xmm_m32,_imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VCMPSS[] = /* VCMPSS */ {
        { VEX_NDS_128_WIG(CMPSS), _r, _xmm, _xmm, _xmm_m32, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2COMISD[] = /* COMISD */ {
        { COMISD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VCOMISD[] = /* VCOMISD */ {
        { VEX_128_WIG(COMISD), _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2COMISS[] = /* COMISS */ {
        { COMISS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2VCOMISS[] = /* VCOMISS */ {
        { VEX_128_WIG(COMISS), _r, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTDQ2PD[] = /* CVTDQ2PD */ {
        { CVTDQ2PD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTDQ2PD[] = /* VCVTDQ2PD */ {
        { VEX_128_WIG(CVTDQ2PD), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTDQ2PD), _r, _ymm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTDQ2PS[] = /* CVTDQ2PS */ {
        { CVTDQ2PS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTDQ2PS[] = /* VCVTDQ2PS */ {
        { VEX_128_WIG(CVTDQ2PS), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTDQ2PS), _r, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPD2DQ[] = /* CVTPD2DQ */ {
        { CVTPD2DQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTPD2DQ[] = /* VCVTPD2DQ */ {
        { VEX_128_WIG(CVTPD2DQ), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTPD2DQ), _r, _xmm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPD2PI[] = /* CVTPD2PI */ {
        { CVTPD2PI, _r,_mm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPD2PS[] = /* CVTPD2PS */ {
        { CVTPD2PS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTPD2PS[] = /* VCVTPD2PS */ {
        { VEX_128_WIG(CVTPD2PS), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTPD2PS), _r, _xmm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPI2PD[] = /* CVTPI2PD */ {
        { CVTPI2PD, _r,_xmm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPI2PS[] = /* CVTPI2PS */ {
        { CVTPI2PS, _r,_xmm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPS2DQ[] = /* CVTPS2DQ */ {
        { CVTPS2DQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTPS2DQ[] = /* VCVTPS2DQ */ {
        { VEX_128_WIG(CVTPS2DQ), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTPS2DQ), _r, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPS2PD[] = /* CVTPS2PD */ {
        { CVTPS2PD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTPS2PD[] = /* VCVTPS2PD */ {
        { VEX_128_WIG(CVTPS2PD), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTPS2PD), _r, _ymm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTPS2PI[] = /* CVTPS2PI */ {
        { CVTPS2PI, _r,_mm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSD2SI[] = /* CVTSD2SI */ {
        { CVTSD2SI, _r,_r32,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTSD2SI[] = /* VCVTSD2SI */ {
        { VEX_128_WIG(CVTSD2SI), _r, _r32, _xmm_m64 },
        { VEX_128_W1(CVTSD2SI), _r, _r64, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSD2SS[] = /* CVTSD2SS */ {
        { CVTSD2SS, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB3 aptb3VCVTSD2SS[] = /* VCVTSD2SS */ {
        { VEX_NDS_128_WIG(CVTSD2SS), _r, _xmm, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSI2SD[] = /* CVTSI2SD */ {
        { CVTSI2SD, _r,_xmm,_rm32 },
        { ASM_END }
};

PTRNTAB3 aptb3VCVTSI2SD[] = /* VCVTSI2SD */ {
        { VEX_NDS_128_WIG(CVTSI2SD), _r, _xmm, _xmm, _rm32 },
        { VEX_NDS_128_W1(CVTSI2SD), _r, _xmm, _xmm, _rm64 }, // implicit REX_W
        { ASM_END }
};

PTRNTAB2 aptb2CVTSI2SS[] = /* CVTSI2SS */ {
        { CVTSI2SS, _r,_xmm,_rm32 },
        { ASM_END }
};

PTRNTAB3 aptb3VCVTSI2SS[] = /* VCVTSI2SS */ {
        { VEX_NDS_128_WIG(CVTSI2SS), _r, _xmm, _xmm, _rm32 },
        { VEX_NDS_128_W1(CVTSI2SS), _r, _xmm, _xmm, _rm64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSS2SD[] = /* CVTSS2SD */ {
        { CVTSS2SD, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VCVTSS2SD[] = /* VCVTSS2SD */ {
        { VEX_NDS_128_WIG(CVTSS2SD), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTSS2SI[] = /* CVTSS2SI */ {
        { CVTSS2SI, _r,_r32,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTSS2SI[] = /* VCVTSS2SI */ {
        { VEX_128_WIG(CVTSS2SI), _r, _r32, _xmm_m32 },
        { VEX_128_W1(CVTSS2SI), _r, _r64, _xmm_m32 }, // implicit REX_W
        { ASM_END }
};

PTRNTAB2 aptb2CVTTPD2PI[] = /* CVTTPD2PI */ {
        { CVTTPD2PI, _r,_mm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTPD2DQ[] = /* CVTTPD2DQ */ {
        { CVTTPD2DQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTTPD2DQ[] = /* VCVTTPD2DQ */ {
        { VEX_128_WIG(CVTTPD2DQ), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTTPD2DQ), _r, _xmm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTPS2DQ[] = /* CVTTPS2DQ */ {
        { CVTTPS2DQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTTPS2DQ[] = /* VCVTTPS2DQ */ {
        { VEX_128_WIG(CVTTPS2DQ), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTTPS2DQ), _r, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTPS2PI[] = /* CVTTPS2PI */ {
        { CVTTPS2PI, _r,_mm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2CVTTSD2SI[] = /* CVTTSD2SI */ {
        { CVTTSD2SI, _r,_r32,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTTSD2SI[] = /* VCVTTSD2SI */ {
        { VEX_128_WIG(CVTTSD2SI), _r, _r32, _xmm_m64 },
        { VEX_128_W1(CVTTSD2SI), _r, _r64, _xmm_m64 }, // implicit REX_W
        { ASM_END }
};

PTRNTAB2 aptb2CVTTSS2SI[] = /* CVTTSS2SI */ {
        { CVTTSS2SI, _r,_r32,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2VCVTTSS2SI[] = /* VCVTTSS2SI */ {
        { VEX_128_WIG(CVTTSS2SI), _r, _r32, _xmm_m64 },
        { VEX_128_W1(CVTTSS2SI), _r, _r64, _xmm_m64 }, // implicit REX_W
        { ASM_END }
};

PTRNTAB2 aptb2DIVPD[] = /* DIVPD */ {
        { DIVPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VDIVPD [] = /* VDIVPD  */ {
        { VEX_NDS_128_WIG(DIVPD), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(DIVPD), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
};

PTRNTAB2 aptb2DIVPS[] = /* DIVPS */ {
        { DIVPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VDIVPS [] = /* VDIVPS  */ {
        { VEX_NDS_128_WIG(DIVPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(DIVPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
};

PTRNTAB2 aptb2DIVSD[] = /* DIVSD */ {
        { DIVSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB3 aptb3VDIVSD [] = /* VDIVSD  */ {
        { VEX_NDS_128_WIG(DIVSD), _r, _xmm, _xmm, _xmm_m64, },
        { ASM_END }
};

PTRNTAB2 aptb2DIVSS[] = /* DIVSS */ {
        { DIVSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VDIVSS [] = /* VDIVSS  */ {
        { VEX_NDS_128_WIG(DIVSS), _r, _xmm, _xmm, _xmm_m32, },
        { ASM_END }
};

PTRNTAB2 aptb2MASKMOVDQU[] = /* MASKMOVDQU */ {
        { MASKMOVDQU, _r,_xmm,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMASKMOVDQU[] = /* VMASKMOVDQU */ {
        { VEX_128_WIG(MASKMOVDQU), _r, _xmm, _xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MASKMOVQ[] = /* MASKMOVQ */ {
        { MASKMOVQ, _r,_mm,_mm },
        { ASM_END }
};

PTRNTAB2 aptb2MAXPD[] = /* MAXPD */ {
        { MAXPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VMAXPD[] = /* VMAXPD */ {
        { VEX_NDS_128_WIG(MAXPD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(MAXPD), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2MAXPS[] = /* MAXPS */ {
        { MAXPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VMAXPS[] = /* VMAXPS */ {
        { VEX_NDS_128_WIG(MAXPS), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(MAXPS), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2MAXSD[] = /* MAXSD */ {
        { MAXSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB3 aptb3VMAXSD[] = /* VMAXSD */ {
        { VEX_NDS_128_WIG(MAXSD), _r, _xmm, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2MAXSS[] = /* MAXSS */ {
        { MAXSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VMAXSS[] = /* VMAXSS */ {
        { VEX_NDS_128_WIG(MAXSS), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2MINPD[] = /* MINPD */ {
        { MINPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VMINPD[] = /* VMINPD */ {
        { VEX_NDS_128_WIG(MINPD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(MINPD), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2MINPS[] = /* MINPS */ {
        { MINPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VMINPS[] = /* VMINPS */ {
        { VEX_NDS_128_WIG(MINPS), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(MINPS), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2MINSD[] = /* MINSD */ {
        { MINSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB3 aptb3VMINSD[] = /* VMINSD */ {
        { VEX_NDS_128_WIG(MINSD), _r, _xmm, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2MINSS[] = /* MINSS */ {
        { MINSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VMINSS[] = /* VMINSS */ {
        { VEX_NDS_128_WIG(MINSS), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVAPD[] = /* MOVAPD */ {
        { LODAPD, _r,_xmm,_xmm_m128 },
        { STOAPD, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVAPD[] = /* VMOVAPD */ {
        { VEX_128_WIG(LODAPD), _r, _xmm, _xmm_m128 },
        { VEX_128_WIG(STOAPD), _r, _xmm_m128, _xmm },
        { VEX_256_WIG(LODAPD), _r, _ymm, _ymm_m256 },
        { VEX_256_WIG(STOAPD), _r, _ymm_m256, _ymm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVAPS[] = /* MOVAPS */ {
        { LODAPS, _r,_xmm,_xmm_m128 },
        { STOAPS, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVAPS [] = /* VMOVAPS */ {
        { VEX_128_WIG(LODAPS), _r, _xmm, _xmm_m128, },
        { VEX_128_WIG(STOAPS), _r, _xmm_m128, _xmm, },
        { VEX_256_WIG(LODAPS), _r, _ymm, _ymm_m256, },
        { VEX_256_WIG(STOAPS), _r, _ymm_m256, _ymm, },
        { ASM_END },
};

PTRNTAB2 aptb2MOVDQA[] = /* MOVDQA */ {
        { LODDQA, _r,_xmm,_xmm_m128 },
        { STODQA, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVDQA[] = /* VMOVDQA */ {
        { VEX_128_WIG(LODDQA), _r, _xmm, _xmm_m128 },
        { VEX_128_WIG(STODQA), _r, _xmm_m128, _xmm },
        { VEX_256_WIG(LODDQA), _r, _ymm, _ymm_m256 },
        { VEX_256_WIG(STODQA), _r, _ymm_m256, _ymm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVDQU[] = /* MOVDQU */ {
        { LODDQU, _r,_xmm,_xmm_m128 },
        { STODQU, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVDQU[] = /* VMOVDQU */ {
        { VEX_128_WIG(LODDQU), _r, _xmm, _xmm_m128 },
        { VEX_128_WIG(STODQU), _r, _xmm_m128, _xmm },
        { VEX_256_WIG(LODDQU), _r, _ymm, _ymm_m256 },
        { VEX_256_WIG(STODQU), _r, _ymm_m256, _ymm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVDQ2Q[] = /* MOVDQ2Q */ {
        { MOVDQ2Q, _r,_mm,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVHLPS[] = /* MOVHLPS */ {
        { MOVHLPS, _r,_xmm,_xmm },
        { ASM_END }
};

PTRNTAB3 aptb3VMOVHLPS[] = /* VMOVHLPS */ {
        { VEX_NDS_128_WIG(MOVHLPS), _r, _xmm, _xmm, _xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVHPD[] = /* MOVHPD */ {
        { LODHPD, _r,_xmm,_xmm_m64 },
        { STOHPD, _r,_xmm_m64,_xmm },
        { ASM_END }
};

PTRNTAB3 aptb3VMOVHPD[] = /* VMOVHPD */ {
        { VEX_NDS_128_WIG(LODHPD), _r, _xmm, _xmm, _m64 },
        { VEX_128_WIG(STOHPD), _r, _m64, _xmm, 0 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVHPS[] = /* MOVHPS */ {
        { LODHPS, _r,_xmm,_xmm_m64 },
        { STOHPS, _r,_xmm_m64,_xmm },
        { ASM_END }
};

PTRNTAB3 aptb3VMOVHPS[] = /* VMOVHPS */ {
        { VEX_NDS_128_WIG(LODHPS), _r, _xmm, _xmm, _m64 },
        { VEX_128_WIG(STOHPS), _r, _m64, _xmm, 0 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVLHPS[] = /* MOVLHPS */ {
        { MOVLHPS, _r,_xmm,_xmm },
        { ASM_END }
};

PTRNTAB3 aptb3VMOVLHPS[] = /* VMOVLHPS */ {
        { VEX_NDS_128_WIG(MOVLHPS), _r, _xmm, _xmm, _xmm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVLPD[] = /* MOVLPD */ {
        { LODLPD, _r,_xmm,_xmm_m64 },
        { STOLPD, _r,_xmm_m64,_xmm },
        { ASM_END }
};

PTRNTAB3 aptb3VMOVLPD[] = /* VMOVLPD */ {
        { VEX_NDS_128_WIG(LODLPD), _r, _xmm, _xmm, _m64 },
        { VEX_128_WIG(STOLPD), _r, _m64, _xmm, 0 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVLPS[] = /* MOVLPS */ {
        { LODLPS, _r,_xmm,_xmm_m64 },
        { STOLPS, _r,_xmm_m64,_xmm },
        { ASM_END }
};

PTRNTAB3 aptb3VMOVLPS[] = /* VMOVLPS */ {
        { VEX_NDS_128_WIG(LODLPS), _r, _xmm, _xmm, _m64 },
        { VEX_128_WIG(STOLPS), _r, _m64, _xmm, 0 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVMSKPD[] = /* MOVMSKPD */ {
        { MOVMSKPD, _r,_r32,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVMSKPD [] = /* VMOVMSKPD */ {
        { VEX_128_WIG(MOVMSKPD), _r, _r32, _xmm },
        { VEX_256_WIG(MOVMSKPD), _r, _r32, _ymm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVMSKPS[] = /* MOVMSKPS */ {
        { MOVMSKPS, _r,_r32,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVMSKPS [] = /* VMOVMSKPS */ {
        { VEX_128_WIG(MOVMSKPS), _r, _r32, _xmm },
        { VEX_256_WIG(MOVMSKPS), _r, _r32, _ymm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTDQ[] = /* MOVNTDQ */ {
        { MOVNTDQ, _r,_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVNTDQ[] = /* VMOVNTDQ */ {
        { VEX_128_WIG(MOVNTDQ), _r, _m128, _xmm },
        { VEX_256_WIG(MOVNTDQ), _r, _m256, _ymm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTI[] = /* MOVNTI */ {
        { MOVNTI, _r,_m32,_r32 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTPD[] = /* MOVNTPD */ {
        { MOVNTPD, _r,_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVNTPD[] = /* VMOVNTPD */ {
        { VEX_128_WIG(MOVNTPD), _r, _m128, _xmm },
        { VEX_256_WIG(MOVNTPD), _r, _m256, _ymm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTPS[] = /* MOVNTPS */ {
        { MOVNTPS, _r,_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVNTPS[] = /* VMOVNTPS */ {
        { VEX_128_WIG(MOVNTPS), _r, _m128, _xmm },
        { VEX_256_WIG(MOVNTPS), _r, _m256, _ymm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTQ[] = /* MOVNTQ */ {
        { MOVNTQ, _r,_m64,_mm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVQ2DQ[] = /* MOVQ2DQ */ {
        { MOVQ2DQ, _r,_xmm,_mm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVSD[] =  /* MOVSD */ {
        { 0xa5, _32_bit | _I386 | _modsidi },
        { LODSD, _r, _xmm, _xmm_m64 },
        { STOSD, _r, _xmm_m64, _xmm },
        { ASM_END }
};

PTRNTAB3 aptb3VMOVSD[] = /* VMOVSD */ {
        { VEX_NDS_128_WIG(LODSD), _r, _xmm, _xmm, _xmm },
        { VEX_128_WIG(STOSD), _r, _m64, _xmm, 0 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVSS[] =  /* MOVSS */ {
        { LODSS, _r,_xmm,_xmm_m32 },
        { STOSS, _r,_xmm_m32,_xmm },
        { ASM_END }
};

PTRNTAB3 aptb3VMOVSS[] = /* VMOVSS */ {
        { VEX_NDS_128_WIG(LODSS), _r, _xmm, _xmm, _xmm },
        { VEX_128_WIG(STOSS), _r, _m32, _xmm, 0 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVUPD[] = /* MOVUPD */ {
        { LODUPD, _r,_xmm,_xmm_m128 },
        { STOUPD, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVUPD[] = /* VMOVUPD */ {
        { VEX_128_WIG(LODUPD), _r, _xmm, _xmm_m128 },
        { VEX_128_WIG(STOUPD), _r, _xmm_m128, _xmm },
        { VEX_256_WIG(LODUPD), _r, _ymm, _ymm_m256 },
        { VEX_256_WIG(STOUPD), _r, _ymm_m256, _ymm },
        { ASM_END }
};

PTRNTAB2 aptb2MOVUPS[] = /* MOVUPS */ {
        { LODUPS, _r,_xmm,_xmm_m128 },
        { STOUPS, _r,_xmm_m128,_xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVUPS [] = /* VMOVUPS */ {
        { VEX_128_WIG(LODUPS), _r, _xmm, _xmm_m128, },
        { VEX_128_WIG(STOUPS), _r, _xmm_m128, _xmm, },
        { VEX_256_WIG(LODUPS), _r, _ymm, _ymm_m256, },
        { VEX_256_WIG(STOUPS), _r, _ymm_m256, _ymm, },
        { ASM_END }
};

PTRNTAB2 aptb2MULPD[] = /* MULPD */ {
        { MULPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VMULPD [] = /* VMULPD  */ {
        { VEX_NDS_128_WIG(MULPD), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(MULPD), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
};

PTRNTAB2 aptb2MULPS[] = /* MULPS */ {
        { MULPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VMULPS [] = /* VMULPS  */ {
        { VEX_NDS_128_WIG(MULPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(MULPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
};

PTRNTAB2 aptb2MULSD[] = /* MULSD */ {
        { MULSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB3 aptb3VMULSD [] = /* VMULSD  */ {
        { VEX_NDS_128_WIG(MULSD), _r, _xmm, _xmm, _xmm_m64, },
        { ASM_END }
};

PTRNTAB2 aptb2MULSS[] = /* MULSS */ {
        { MULSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VMULSS [] = /* VMULSS  */ {
        { VEX_NDS_128_WIG(MULSS), _r, _xmm, _xmm, _xmm_m32, },
        { ASM_END }
};

PTRNTAB2 aptb2ORPD[] = /* ORPD */ {
        { ORPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VORPD[] = /* VORPD */ {
        { VEX_NDS_128_WIG(ORPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ORPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2ORPS[] = /* ORPS */ {
        { ORPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VORPS[] = /* VORPS */ {
        { VEX_NDS_128_WIG(ORPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ORPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2PADDQ[] = /* PADDQ */ {
        { 0x0FD4, _r,_mm,_mmm64 },
        { PADDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPADDQ[] = /* VPADDQ */ {
        { VEX_NDS_128_WIG(PADDQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PAVGB[] = /* PAVGB */ {
        { 0x0FE0, _r,_mm,_mmm64 },
        { PAVGB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPAVGB[] = /* VPAVGB */ {
        { VEX_NDS_128_WIG(PAVGB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PAVGW[] = /* PAVGW */ {
        { 0x0FE3, _r,_mm,_mmm64 },
        { PAVGW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPAVGW[] = /* VPAVGW */ {
        { VEX_NDS_128_WIG(PAVGW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3PEXTRW[] = /* PEXTRW */ {
        { 0x0FC5, _r,_r32,_mm,_imm8 },
        { 0x0FC5, _r,_r64,_mm,_imm8 },
        { 0x660FC5, _r,_r32,_xmm,_imm8 },
        { 0x660FC5, _r,_r64,_xmm,_imm8 },
        { 0x660F3A15, _r,_m16,_xmm,_imm8 },    // synonym for r32/r64
        { ASM_END }
};

PTRNTAB3 aptb3VPEXTRW[] = /* VPEXTRW */ {
        { VEX_128_WIG(0x660FC5), _r,_r32,_xmm,_imm8 },
        { VEX_128_WIG(0x660FC5), _r,_r64,_xmm,_imm8 },
        { VEX_128_WIG(0x660F3A15), _r,_m16,_xmm,_imm8 },    // synonym for r32/r64
        { ASM_END }
};

PTRNTAB3 aptb3PINSRW[] = /* PINSRW */ {
        { 0x0FC4, _r,_mm,_r32m16,_imm8 },
        { PINSRW, _r,_xmm,_r32m16,_imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VPINSRW[] = /* VPINSRW */ {
        { VEX_NDS_128_WIG(PINSRW), _r, _xmm, _xmm, _r32m16, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PMAXSW[] = /* PMAXSW */ {
        { 0x0FEE, _r,_mm,_mmm64 },
        { PMAXSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMAXSW[] = /* VPMAXSW */ {
        { VEX_NDS_128_WIG(PMAXSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMAXUB[] = /* PMAXUB */ {
        { 0x0FDE, _r,_mm,_mmm64 },
        { PMAXUB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMAXUB[] = /* VPMAXUB */ {
        { VEX_NDS_128_WIG(PMAXUB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMINSW[] = /* PMINSW */ {
        { 0x0FEA, _r,_mm,_mmm64 },
        { PMINSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMINSW[] = /* VPMINSW */ {
        { VEX_NDS_128_WIG(PMINSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMINUB[] = /* PMINUB */ {
        { 0x0FDA, _r,_mm,_mmm64 },
        { PMINUB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMINUB[] = /* VPMINUB */ {
        { VEX_NDS_128_WIG(PMINUB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVMSKB[] = /* PMOVMSKB */ {
        { 0x0FD7, _r,_r32,_mm },
        { PMOVMSKB, _r, _r32, _xmm },
        { PMOVMSKB, _r|_64_bit, _r64, _xmm },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVMSKB[] = /* VPMOVMSKB */ {
        { VEX_128_WIG(PMOVMSKB), _r, _r32, _xmm },
        { ASM_END }
};

PTRNTAB2 aptb2PMULHUW[] = /* PMULHUW */ {
        { 0x0FE4, _r,_mm,_mmm64 },
        { PMULHUW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMULHUW[] = /* VPMULHUW */ {
        { VEX_NDS_128_WIG(PMULHUW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULHW[] = /* PMULHW */ {
        { 0x0FE5, _r,_mm,_mmm64 },
        { PMULHW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMULHW[] = /* VPMULHW */ {
        { VEX_NDS_128_WIG(PMULHW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULLW[] = /* PMULLW */ {
        { 0x0FD5, _r,_mm,_mmm64 },
        { PMULLW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMULLW[] = /* VPMULLW */ {
        { VEX_NDS_128_WIG(PMULLW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULUDQ[] = /* PMULUDQ */ {
        { 0x0FF4, _r,_mm,_mmm64 },
        { PMULUDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMULUDQ[] = /* VPMULUDQ */ {
        { VEX_NDS_128_WIG(PMULUDQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2POR[] = /* POR */ {
        { 0x0FEB, _r,_mm,_mmm64 },
        { POR, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPOR[] = /* VPOR */ {
        { VEX_NDS_128_WIG(POR), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHNTA[] = /* PREFETCHNTA */ {
        { PREFETCH, _0,_m8 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHT0[] = /* PREFETCHT0 */ {
        { PREFETCH, _1,_m8 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHT1[] = /* PREFETCHT1 */ {
        { PREFETCH, _2,_m8 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHT2[] = /* PREFETCHT2 */ {
        { PREFETCH, _3,_m8 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHW[] = /* PREFETCHW */ {
        { 0x0F0D, _1,_m8 },
        { ASM_END }
};

PTRNTAB1 aptb1PREFETCHWT1[] = /* PREFETCHWT1 */ {
        { 0x0F0D, _2,_m8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSADBW[] = /* PSADBW */ {
        { 0x0FF6, _r,_mm,_mmm64 },
        { PSADBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSADBW[] = /* VPSADBW */ {
        { VEX_NDS_128_WIG(PSADBW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};


PTRNTAB3 aptb3PSHUFD[] = /* PSHUFD */ {
        { PSHUFD, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSHUFD[] = /* VPSHUFD */ {
        { VEX_128_WIG(PSHUFD), _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PSHUFHW[] = /* PSHUFHW */ {
        { PSHUFHW, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSHUFHW[] = /* VPSHUFHW */ {
        { VEX_128_WIG(PSHUFHW), _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PSHUFLW[] = /* PSHUFLW */ {
        { PSHUFLW, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSHUFLW[] = /* VPSHUFLW */ {
        { VEX_128_WIG(PSHUFLW), _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PSHUFW[] = /* PSHUFW */ {
        { PSHUFW, _r,_mm,_mmm64,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSLLDQ[] = /* PSLLDQ */ {
        { (PSLLDQ & 0xFFFFFF), _7,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSLLDQ[] = /* VPSLLDQ */ {
        { VEX_NDD_128_WIG((PSLLDQ & 0xFFFFFF)), _7, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSRLDQ[] = /* PSRLDQ */ {
        { PSRLDQ & 0xFFFFFF, _3,_xmm,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSRLDQ[] = /* VPSRLDQ */ {
        { VEX_NDD_128_WIG((PSRLDQ & 0xFFFFFF)), _3, _xmm, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PSUBQ[] = /* PSUBQ */ {
        { 0x0FFB, _r,_mm,_mmm64 },
        { PSUBQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSUBQ[] = /* VPSUBQ */ {
        { VEX_NDS_128_WIG(PSUBQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKHQDQ[] = /* PUNPCKHQDQ */ {
        { PUNPCKHQDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPUNPCKHQDQ[] = /* VPUNPCKHQDQ */ {
        { VEX_NDS_128_WIG(PUNPCKHQDQ), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PUNPCKLQDQ[] = /* PUNPCKLQDQ */ {
        { PUNPCKLQDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPUNPCKLQDQ[] = /* VPUNPCKLQDQ */ {
        { VEX_NDS_128_WIG(PUNPCKLQDQ), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2RCPPS[] = /* RCPPS */ {
        { RCPPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VRCPPS[] = /* VRCPPS */ {
        { VEX_128_WIG(RCPPS), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(RCPPS), _r, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2RCPSS[] = /* RCPSS */ {
        { RCPSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VRCPSS[] = /* VRCPSS */ {
        { VEX_NDS_128_WIG(RCPSS), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2RSQRTPS[] = /* RSQRTPS */ {
        { RSQRTPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2RSQRTSS[] = /* RSQRTSS */ {
        { RSQRTSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3SHUFPD[] = /* SHUFPD */ {
        { SHUFPD, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VSHUFPD[] = /* VSHUFPD */ {
        { VEX_NDS_128_WIG(SHUFPD), _r,_xmm,_xmm,_xmm_m128,_imm8 },
        { VEX_NDS_256_WIG(SHUFPD), _r,_ymm,_ymm,_ymm_m256,_imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3SHUFPS[] = /* SHUFPS */ {
        { SHUFPS, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VSHUFPS[] = /* VSHUFPS */ {
        { VEX_NDS_128_WIG(SHUFPS), _r,_xmm,_xmm,_xmm_m128,_imm8 },
        { VEX_NDS_256_WIG(SHUFPS), _r,_ymm,_ymm,_ymm_m256,_imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2SQRTPD[] = /* SQRTPD */ {
        { SQRTPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VSQRTPD[] = /* VSQRTPD */ {
        { VEX_128_WIG(SQRTPD), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(SQRTPD), _r, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2SQRTPS[] = /* SQRTPS */ {
        { SQRTPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VSQRTPS[] = /* VSQRTPS */ {
        { VEX_128_WIG(SQRTPS), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(SQRTPS), _r, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2SQRTSD[] = /* SQRTSD */ {
        { SQRTSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB3 aptb3VSQRTSD[] = /* VSQRTSD */ {
        { VEX_NDS_128_WIG(SQRTSD), _r, _xmm, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2SQRTSS[] = /* SQRTSS */ {
        { SQRTSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VSQRTSS[] = /* VSQRTSS */ {
        { VEX_NDS_128_WIG(SQRTSS), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2SUBPD[] = /* SUBPD */ {
        { SUBPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VSUBPD [] = /* VSUBPD  */ {
        { VEX_NDS_128_WIG(SUBPD), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(SUBPD), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
};

PTRNTAB2 aptb2SUBPS[] = /* SUBPS */ {
        { SUBPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VSUBPS [] = /* VSUBPS  */ {
        { VEX_NDS_128_WIG(SUBPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(SUBPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
};

PTRNTAB2 aptb2SUBSD[] = /* SUBSD */ {
        { SUBSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB3 aptb3VSUBSD[] = /* VSUBSD */ {
        { VEX_NDS_128_WIG(SUBSD), _r, _xmm, _xmm, _xmm_m64, },
        { ASM_END }
};

PTRNTAB2 aptb2SUBSS[] = /* SUBSS */ {
        { SUBSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VSUBSS[] = /* VSUBSS */ {
        { VEX_NDS_128_WIG(SUBSS), _r, _xmm, _xmm, _xmm_m32, },
        { ASM_END }
};

PTRNTAB2 aptb2UCOMISD[] = /* UCOMISD */ {
        { UCOMISD, _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VUCOMISD[] = /* VUCOMISD */ {
        { VEX_128_WIG(UCOMISD), _r,_xmm,_xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2UCOMISS[] = /* UCOMISS */ {
        { UCOMISS, _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2VUCOMISS[] = /* VUCOMISS */ {
        { VEX_128_WIG(UCOMISS), _r,_xmm,_xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2UNPCKHPD[] = /* UNPCKHPD */ {
        { UNPCKHPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VUNPCKHPD[] = /* VUNPCKHPD */ {
        { VEX_NDS_128_WIG(UNPCKHPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(UNPCKHPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2UNPCKHPS[] = /* UNPCKHPS */ {
        { UNPCKHPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VUNPCKHPS[] = /* VUNPCKHPS */ {
        { VEX_NDS_128_WIG(UNPCKHPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(UNPCKHPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2UNPCKLPD[] = /* UNPCKLPD */ {
        { UNPCKLPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VUNPCKLPD[] = /* VUNPCKLPD */ {
        { VEX_NDS_128_WIG(UNPCKLPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(UNPCKLPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2UNPCKLPS[] = /* UNPCKLPS */ {
        { UNPCKLPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VUNPCKLPS[] = /* VUNPCKLPS */ {
        { VEX_NDS_128_WIG(UNPCKLPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(UNPCKLPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2XORPD[] = /* XORPD */ {
        { XORPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VXORPD[] = /* VXORPD */ {
        { VEX_NDS_128_WIG(XORPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(XORPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2XORPS[] = /* XORPS */ {
        { XORPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VXORPS[] = /* VXORPS */ {
        { VEX_NDS_128_WIG(XORPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(XORPS), _r,_ymm,_ymm,_ymm_m256 },
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

PTRNTAB2 aptb2PAVGUSB[] = /* PAVGUSB */ {
        { 0x0F0FBF, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PF2ID[] = /* PF2ID */ {
        { 0x0F0F1D, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFACC[] = /* PFACC */ {
        { 0x0F0FAE, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFADD[] = /* PFADD */ {
        { 0x0F0F9E, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFCMPEQ[] = /* PFCMPEQ */ {
        { 0x0F0FB0, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFCMPGE[] = /* PFCMPGE */ {
        { 0x0F0F90, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFCMPGT[] = /* PFCMPGT */ {
        { 0x0F0FA0, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFMAX[] = /* PFMAX */ {
        { 0x0F0FA4, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFMIN[] = /* PFMIN */ {
        { 0x0F0F94, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFMUL[] = /* PFMUL */ {
        { 0x0F0FB4, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFNACC[] = /* PFNACC */ {
        { 0x0F0F8A, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFPNACC[] = /* PFPNACC */ {
        { 0x0F0F8E, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRCP[] = /* PFRCP */ {
        { 0x0F0F96, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRCPIT1[] = /* PFRCPIT1 */ {
        { 0x0F0FA6, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRCPIT2[] = /* PFRCPIT2 */ {
        { 0x0F0FB6, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRSQIT1[] = /* PFRSQIT1 */ {
        { 0x0F0FA7, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFRSQRT[] = /* PFRSQRT */ {
        { 0x0F0F97, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFSUB[] = /* PFSUB */ {
        { 0x0F0F9A, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PFSUBR[] = /* PFSUBR */ {
        { 0x0F0FAA, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PI2FD[] = /* PI2FD */ {
        { 0x0F0F0D, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULHRW[] = /* PMULHRW */ {
        { 0x0F0FB7, _r,_mm,_mmm64 },
        { ASM_END }
};

PTRNTAB2 aptb2PSWAPD[] = /* PSWAPD */ {
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

PTRNTAB1  aptb1FISTTP[] = /* FISTTP */ {
        { 0xdf, _1, _m16 },
        { 0xdb, _1, _m32 },
        { 0xdd, _1, _fm64 },
        { ASM_END }
};

PTRNTAB0 aptb0MONITOR[] =  /* MONITOR */ {
        { MONITOR, 0 }
};

PTRNTAB0 aptb0MWAIT[] =  /* MWAIT */ {
        { MWAIT, 0 }
};

PTRNTAB2 aptb2ADDSUBPD[] = /* ADDSUBPD */ {
        { ADDSUBPD, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
};

PTRNTAB3  aptb3VADDSUBPD[] = /* VADDSUBPD */ {
        { VEX_NDS_128_WIG(ADDSUBPD), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(ADDSUBPD), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
};

PTRNTAB2 aptb2ADDSUBPS[] = /* ADDSUBPS */ {
        { ADDSUBPS, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
};

PTRNTAB3  aptb3VADDSUBPS[] = /* VADDSUBPS */ {
        { VEX_NDS_128_WIG(ADDSUBPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(ADDSUBPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
};

PTRNTAB2 aptb2HADDPD[] = /* HADDPD */ {
        { HADDPD, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
};

PTRNTAB3 aptb3VHADDPD[] = /* VHADDPD */ {
        { VEX_NDS_128_WIG(HADDPD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(HADDPD), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2HADDPS[] = /* HADDPS */ {
        { HADDPS, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
};

PTRNTAB3 aptb3VHADDPS[] = /* VHADDPS */ {
        { VEX_NDS_128_WIG(HADDPS), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(HADDPS), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2HSUBPD[] = /* HSUBPD */ {
        { HSUBPD, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
};

PTRNTAB2 aptb2HSUBPS[] = /* HSUBPS */ {
        { HSUBPS, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
};

PTRNTAB2 aptb2LDDQU[] = /* LDDQU */ {
        { LDDQU, _r,_xmm,_m128 },            // xmm1,mem
        { ASM_END }
};

PTRNTAB2 aptb2VLDDQU[] = /* VLDDQU */ {
        { VEX_128_WIG(LDDQU), _r, _xmm, _m128 },
        { VEX_256_WIG(LDDQU), _r, _ymm, _m256 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVDDUP[] = /* MOVDDUP */ {
        { MOVDDUP, _r,_xmm,_xmm_m64 },         // xmm1,xmm2/m64
        { ASM_END }
};

PTRNTAB2 aptb2VMOVDDUP[] = /* VMOVDDUP */ {
        { VEX_128_WIG(MOVDDUP), _r,_xmm,_xmm_m64 },
        { VEX_256_WIG(MOVDDUP), _r,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVSHDUP[] = /* MOVSHDUP */ {
        { MOVSHDUP, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
};

PTRNTAB2 aptb2VMOVSHDUP[] = /* VMOVSHDUP */ {
        { VEX_128_WIG(MOVSHDUP), _r,_xmm,_xmm_m128 },
        { VEX_256_WIG(MOVSHDUP), _r,_ymm,_ymm_m256 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVSLDUP[] = /* MOVSLDUP */ {
        { MOVSLDUP, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
};

PTRNTAB2 aptb2VMOVSLDUP[] = /* VMOVSLDUP */ {
        { VEX_128_WIG(MOVSLDUP), _r,_xmm,_xmm_m128 },
        { VEX_256_WIG(MOVSLDUP), _r,_ymm,_ymm_m256 },
        { ASM_END }
};

/* ======================= SSSE3 ======================= */

/*
palignr
phaddd
phaddw
phaddsw
phsubd
phsubw
phsubsw
pmaddubsw
pmulhrsw
pshufb
pabsb
pabsd
pabsw
psignb
psignd
psignw
*/

PTRNTAB3 aptb3PALIGNR[] = /* PALIGNR */ {
        { 0x0F3A0F, _r,_mm,_mmm64, _imm8 },
        { PALIGNR, _r,_xmm,_xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VPALIGNR[] = /* VPALIGNR */ {
        { VEX_NDS_128_WIG(PALIGNR), _r,_xmm,_xmm,_xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PHADDD[] = /* PHADDD */ {
        { 0x0F3802, _r,_mm,_mmm64 },
        { PHADDD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPHADDD[] = /* VPHADDD */ {
        { VEX_NDS_128_WIG(PHADDD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PHADDW[] = /* PHADDW */ {
        { 0x0F3801, _r,_mm,_mmm64 },
        { PHADDW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPHADDW[] = /* VPHADDW */ {
        { VEX_NDS_128_WIG(PHADDW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PHADDSW[] = /* PHADDSW */ {
        { 0x0F3803, _r,_mm,_mmm64 },
        { PHADDSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPHADDSW[] = /* VPHADDSW */ {
        { VEX_NDS_128_WIG(PHADDSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PHSUBD[] = /* PHSUBD */ {
        { 0x0F3806, _r,_mm,_mmm64 },
        { PHSUBD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPHSUBD[] = /* VPHSUBD */ {
        { VEX_NDS_128_WIG(PHSUBD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PHSUBW[] = /* PHSUBW */ {
        { 0x0F3805, _r,_mm,_mmm64 },
        { PHSUBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPHSUBW[] = /* VPHSUBW */ {
        { VEX_NDS_128_WIG(PHSUBW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PHSUBSW[] = /* PHSUBSW */ {
        { 0x0F3807, _r,_mm,_mmm64 },
        { PHSUBSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPHSUBSW[] = /* VPHSUBSW */ {
        { VEX_NDS_128_WIG(PHSUBSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMADDUBSW[] = /* PMADDUBSW */ {
        { 0x0F3804, _r,_mm,_mmm64 },
        { PMADDUBSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMADDUBSW[] = /* VPMADDUBSW */ {
        { VEX_NDS_128_WIG(PMADDUBSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULHRSW[] = /* PMULHRSW */ {
        { 0x0F380B, _r,_mm,_mmm64 },
        { PMULHRSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMULHRSW[] = /* VPMULHRSW */ {
        { VEX_NDS_128_WIG(PMULHRSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSHUFB[] = /* PSHUFB */ {
        { 0x0F3800, _r,_mm,_mmm64 },
        { PSHUFB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSHUFB[] = /* VPSHUFB */ {
        { VEX_NDS_128_WIG(PSHUFB), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PABSB[] = /* PABSB */ {
        { 0x0F381C, _r,_mm,_mmm64 },
        { PABSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VPABSB [] = /* VPABSB */ {
        { VEX_128_WIG(PABSB), _r, _xmm, _xmm_m128 },
        { ASM_END }
};


PTRNTAB2 aptb2PABSD[] = /* PABSD */ {
        { 0x0F381E, _r,_mm,_mmm64 },
        { PABSD, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VPABSD [] = /* VPABSD  */ {
        { VEX_128_WIG(PABSD), _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PABSW[] = /* PABSW */ {
        { 0x0F381D, _r,_mm,_mmm64 },
        { PABSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VPABSW [] = /* VPABSW */ {
        { VEX_128_WIG(PABSW), _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSIGNB[] = /* PSIGNB */ {
        { 0x0F3808, _r,_mm,_mmm64 },
        { PSIGNB, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSIGNB[] = /* VPSIGNB */ {
        { VEX_NDS_128_WIG(PSIGNB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSIGND[] = /* PSIGND */ {
        { 0x0F380A, _r,_mm,_mmm64 },
        { PSIGND, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSIGND[] = /* VPSIGND */ {
        { VEX_NDS_128_WIG(PSIGND), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PSIGNW[] = /* PSIGNW */ {
        { 0x0F3809, _r,_mm,_mmm64 },
        { PSIGNW, _r,_xmm,_xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPSIGNW[] = /* VPSIGNW */ {
        { VEX_NDS_128_WIG(PSIGNW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
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
pblendvb
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

PTRNTAB3 aptb3BLENDPD[] = /* BLENDPD */ {
        { BLENDPD, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VBLENDPD[] = /* VBLENDPD */ {
        { VEX_NDS_128_WIG(BLENDPD), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(BLENDPD), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3BLENDPS[] = /* BLENDPS */ {
        { BLENDPS, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VBLENDPS[] = /* VBLENDPS */ {
        { VEX_NDS_128_WIG(BLENDPS), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(BLENDPS), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3BLENDVPD[] = /* BLENDVPD */ {
        { BLENDVPD, _r, _xmm, _xmm_m128, _xmm0 },
        { ASM_END }
};

PTRNTAB4 aptb4VBLENDVPD[] = /* VBLENDVPD */ {
        { VEX_NDS_128_WIG(0x660F3A4B), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(0x660F3A4B), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3BLENDVPS[] = /* BLENDVPS */ {
        { BLENDVPS, _r, _xmm, _xmm_m128, _xmm0 },
        { ASM_END }
};

PTRNTAB4 aptb4VBLENDVPS[] = /* VBLENDVPS */ {
        { VEX_NDS_128_WIG(0x660F3A4A), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(0x660F3A4A), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3DPPD[] = /* DPPD */ {
        { DPPD, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB4  aptb4VDPPD[] = /* VDPPD */ {
        { VEX_NDS_128_WIG(DPPD), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3DPPS[] = /* DPPS */ {
        { DPPS, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB4  aptb4VDPPS[] = /* VDPPS */ {
        { VEX_NDS_128_WIG(DPPS), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(DPPS), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3EXTRACTPS[] = /* EXTRACTPS */ {
        { EXTRACTPS, _r, _rm32, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VEXTRACTPS[] = /* VEXTRACTPS */ {
        { VEX_128_WIG(EXTRACTPS), _r, _rm32, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3INSERTPS[] = /* INSERTPS */ {
        { INSERTPS, _r, _xmm, _xmm_m32, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VINSERTPS[] = /* VINSERTPS */ {
        { VEX_NDS_128_WIG(INSERTPS), _r, _xmm, _xmm, _xmm_m32, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2MOVNTDQA[] = /* MOVNTDQA */ {
        { MOVNTDQA, _r, _xmm, _m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VMOVNTDQA[] = /* VMOVNTDQA */ {
        { VEX_128_WIG(MOVNTDQA), _r, _xmm, _m128 },
        { ASM_END }
};

PTRNTAB3 aptb3MPSADBW[] = /* MPSADBW */ {
        { MPSADBW, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VMPSADBW [] = /* VMPSADBW */ {
        { VEX_NDS_128_WIG(MPSADBW), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PACKUSDW[] = /* PACKUSDW */ {
        { PACKUSDW, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPACKUSDW[] = /* VPACKUSDW */ {
        { VEX_NDS_128_WIG(PACKUSDW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3PBLENDVB[] = /* PBLENDVB */ {
        { PBLENDVB, _r, _xmm, _xmm_m128, _xmm0 },
        { ASM_END }
};

PTRNTAB4 aptb4VPBLENDVB[] = /* VPBLENDVB */ {
        { VEX_NDS_128_WIG(0x660F3A4C), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PBLENDW[] = /* PBLENDW */ {
        { PBLENDW, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VPBLENDW[] = /* VPBLENDW */ {
        { VEX_NDS_128_WIG(PBLENDW), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPEQQ[] = /* PCMPEQQ */ {
        { PCMPEQQ, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPEQQ[] = /* VPCMPEQQ */ {
        { VEX_NDS_128_WIG(PCMPEQQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3PEXTRB[] = /* PEXTRB */ {
        { PEXTRB, _r, _regm8, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPEXTRB[] = /* VPEXTRB */ {
        { VEX_128_WIG(PEXTRB), _r, _regm8, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PEXTRD[] = /* PEXTRD */ {
        { PEXTRD, _r, _rm32, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPEXTRD[] = /* VPEXTRD */ {
        { VEX_128_WIG(PEXTRD), _r, _rm32, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PEXTRQ[] = /* PEXTRQ */ {
        { PEXTRQ, _r|_64_bit, _rm64, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPEXTRQ[] = /* VPEXTRQ */ {
        { VEX_128_W1(PEXTRD), _r, _rm64, _xmm, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PHMINPOSUW[] = /* PHMINPOSUW  */ {
        { PHMINPOSUW, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VPHMINPOSUW[] = /* VPHMINPOSUW */ {
        { VEX_128_WIG(PHMINPOSUW), _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3PINSRB[] = /* PINSRB */ {
        { PINSRB, _r, _xmm, _r32, _imm8 },
        { PINSRB, _r, _xmm, _rm8, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VPINSRB[] = /* VPINSRB */ {
        { VEX_NDS_128_WIG(PINSRB), _r, _xmm, _xmm, _r32m8, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PINSRD[] = /* PINSRD */ {
        { PINSRD, _r, _xmm, _rm32, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VPINSRD[] = /* VPINSRD */ {
        { VEX_NDS_128_WIG(PINSRD), _r, _xmm, _xmm, _rm32, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PINSRQ[] = /* PINSRQ */ {
        { PINSRQ, _r|_64_bit, _xmm, _rm64, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VPINSRQ[] = /* VPINSRQ */ {
        { VEX_NDS_128_W1(PINSRD), _r, _xmm, _xmm, _rm64, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PMAXSB[] = /* PMAXSB */ {
        { PMAXSB, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMAXSB[] = /* VPMAXSB */ {
        { VEX_NDS_128_WIG(PMAXSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMAXSD[] = /* PMAXSD */ {
        { PMAXSD, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMAXSD[] = /* VPMAXSD */ {
        { VEX_NDS_128_WIG(PMAXSD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMAXUD[] = /* PMAXUD */ {
        { PMAXUD, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMAXUD[] = /* VPMAXUD */ {
        { VEX_NDS_128_WIG(PMAXUD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMAXUW[] = /* PMAXUW */ {
        { PMAXUW, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMAXUW[] = /* VPMAXUW */ {
        { VEX_NDS_128_WIG(PMAXUW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMINSB[] = /* PMINSB */ {
        { PMINSB, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMINSB[] = /* VPMINSB */ {
        { VEX_NDS_128_WIG(PMINSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMINSD[] = /* PMINSD */ {
        { PMINSD, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMINSD[] = /* VPMINSD */ {
        { VEX_NDS_128_WIG(PMINSD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMINUD[] = /* PMINUD */ {
        { PMINUD, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMINUD[] = /* VPMINUD */ {
        { VEX_NDS_128_WIG(PMINUD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMINUW[] = /* PMINUW */ {
        { PMINUW, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMINUW[] = /* VPMINUW */ {
        { VEX_NDS_128_WIG(PMINUW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVSXBW[] = /* PMOVSXBW */ {
        { PMOVSXBW, _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVSXBW[] = /* VPMOVSXBW */ {
        { VEX_128_WIG(PMOVSXBW), _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVSXBD[] = /* PMOVSXBD */ {
        { PMOVSXBD, _r, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVSXBD[] = /* VPMOVSXBD */ {
        { VEX_128_WIG(PMOVSXBD), _r, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVSXBQ[] = /* PMOVSXBQ */ {
        { PMOVSXBQ, _r, _xmm, _xmm_m16 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVSXBQ[] = /* VPMOVSXBQ */ {
        { VEX_128_WIG(PMOVSXBQ), _r, _xmm, _xmm_m16 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVSXWD[] = /* PMOVSXWD */ {
        { PMOVSXWD, _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVSXWD[] = /* VPMOVSXWD */ {
        { VEX_128_WIG(PMOVSXWD), _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVSXWQ[] = /* PMOVSXWQ */ {
        { PMOVSXWQ, _r, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVSXWQ[] = /* VPMOVSXWQ */ {
        { VEX_128_WIG(PMOVSXWQ), _r, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVSXDQ[] = /* PMOVSXDQ */ {
        { PMOVSXDQ, _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVSXDQ[] = /* VPMOVSXDQ */ {
        { VEX_128_WIG(PMOVSXDQ), _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVZXBW[] = /* PMOVZXBW */ {
        { PMOVZXBW, _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVZXBW[] = /* VPMOVZXBW */ {
        { VEX_128_WIG(PMOVZXBW), _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVZXBD[] = /* PMOVZXBD */ {
        { PMOVZXBD, _r, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVZXBD[] = /* VPMOVZXBD */ {
        { VEX_128_WIG(PMOVZXBD), _r, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVZXBQ[] = /* PMOVZXBQ */ {
        { PMOVZXBQ, _r, _xmm, _xmm_m16 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVZXBQ[] = /* VPMOVZXBQ */ {
        { VEX_128_WIG(PMOVZXBQ), _r, _xmm, _xmm_m16 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVZXWD[] = /* PMOVZXWD */ {
        { PMOVZXWD, _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVZXWD[] = /* VPMOVZXWD */ {
        { VEX_128_WIG(PMOVZXWD), _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVZXWQ[] = /* PMOVZXWQ */ {
        { PMOVZXWQ, _r, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVZXWQ[] = /* VPMOVZXWQ */ {
        { VEX_128_WIG(PMOVZXWQ), _r, _xmm, _xmm_m32 },
        { ASM_END }
};

PTRNTAB2 aptb2PMOVZXDQ[] = /* PMOVZXDQ */ {
        { PMOVZXDQ, _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VPMOVZXDQ[] = /* VPMOVZXDQ */ {
        { VEX_128_WIG(PMOVZXDQ), _r, _xmm, _xmm_m64 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULDQ[] = /* PMULDQ */ {
        { PMULDQ, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMULDQ[] = /* VPMULDQ */ {
        { VEX_NDS_128_WIG(PMULDQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PMULLD[] = /* PMULLD */ {
        { PMULLD, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPMULLD[] = /* VPMULLD */ {
        { VEX_NDS_128_WIG(PMULLD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2PTEST[] = /* PTEST */ {
        { PTEST, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VPTEST[] = /* VPTEST */ {
        { VEX_128_WIG(PTEST), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(PTEST), _r, _ymm, _ymm_m256 },
        { ASM_END }
};

PTRNTAB3 aptb3ROUNDPD[] = /* ROUNDPD */ {
        { ROUNDPD, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VROUNDPD[] = /* VROUNDPD */ {
        { VEX_128_WIG(ROUNDPD), _r, _xmm, _xmm_m128, _imm8 },
        { VEX_256_WIG(ROUNDPD), _r, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3ROUNDPS[] = /* ROUNDPS */ {
        { ROUNDPS, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VROUNDPS[] = /* VROUNDPS */ {
        { VEX_128_WIG(ROUNDPS), _r, _xmm, _xmm_m128, _imm8 },
        { VEX_256_WIG(ROUNDPS), _r, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3ROUNDSD[] = /* ROUNDSD */ {
        { ROUNDSD, _r, _xmm, _xmm_m64, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VROUNDSD[] = /* VROUNDSD */ {
        { VEX_NDS_128_WIG(ROUNDSD), _r, _xmm, _xmm, _xmm_m64, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3ROUNDSS[] = /* ROUNDSS */ {
        { ROUNDSS, _r, _xmm, _xmm_m32, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VROUNDSS[] = /* VROUNDSS */ {
        { VEX_NDS_128_WIG(ROUNDSS), _r, _xmm, _xmm, _xmm_m32, _imm8 },
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

PTRNTAB2 aptb2CRC32[] = /* CRC32 */ {
        { 0xF20F38F0, _r        , _r32, _rm8  },
        { 0xF20F38F0, _r|_64_bit, _r64, _rm8  },
        { 0xF20F38F1, _r|_16_bit, _r32, _rm16 },
        { 0xF20F38F1, _r|_32_bit, _r32, _rm32 },
        { 0xF20F38F1, _r|_64_bit, _r64, _rm64 },
        { ASM_END }
};

PTRNTAB3 aptb3PCMPESTRI [] = /* PCMPESTRI */ {
        { PCMPESTRI, _r|_modcx  , _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPESTRI[] = /* VPCMPESTRI */ {
        { VEX_128_WIG(PCMPESTRI), _r|_modcx, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PCMPESTRM[] = /* PCMPESTRM */ {
        { PCMPESTRM, _r|_modxmm0, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPESTRM[] = /* VPCMPESTRM */ {
        { VEX_128_WIG(PCMPESTRM), _r|_modxmm0, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PCMPISTRI [] = /* PCMPISTRI */ {
        { PCMPISTRI, _r|_modcx  , _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPISTRI[] = /* VPCMPISTRI */ {
        { VEX_128_WIG(PCMPISTRI), _r|_modcx, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3PCMPISTRM [] = /* PCMPISTRM */ {
        { PCMPISTRM, _r|_modxmm0, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPISTRM[] = /* VPCMPISTRM */ {
        { VEX_128_WIG(PCMPISTRM), _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB2 aptb2PCMPGTQ [] = /* PCMPGTQ */ {
        { PCMPGTQ, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB3 aptb3VPCMPGTQ[] = /* VPCMPGTQ */ {
        { VEX_NDS_128_WIG(PCMPGTQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2POPCNT [] = /* POPCNT */ {
        { POPCNT, _r|_16_bit, _r16, _rm16 },
        { POPCNT, _r|_32_bit, _r32, _rm32 },
        { POPCNT, _r|_64_bit, _r64, _rm64 },
        { ASM_END }
};

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

/* ======================= CLMUL ======================= */

PTRNTAB3 aptb3PCLMULQDQ[] = /* PCLMULQDQ */ {
        { 0x660F3A44, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VPCLMULQDQ[] = /* VPCLMULQDQ */ {
        { VEX_NDS_128_WIG(0x660F3A44), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
};

/* ======================= AVX ======================= */

PTRNTAB2 aptb2VBROADCASTF128[] = /* VBROADCASTF128 */ {
        { VEX_256_WIG(0x660F381A), _r, _ymm, _m128 },
        { ASM_END }
};

PTRNTAB2 aptb2VBROADCASTSD[] = /* VBROADCASTSD */ {
        { VEX_256_WIG(0x660F3819), _r, _ymm, _m64 },
        { ASM_END }
};

PTRNTAB2 aptb2VBROADCASTSS[] = /* VBROADCASTSS */ {
        { VEX_128_WIG(0x660F3818), _r, _xmm, _m32 },
        { VEX_256_WIG(0x660F3818), _r, _ymm, _m32 },
        { ASM_END }
};

PTRNTAB3 aptb3VEXTRACTF128[] = /* VEXTRACTF128 */ {
        { VEX_256_WIG(0x660F3A19), _r, _xmm_m128, _ymm, _imm8 },
        { ASM_END }
};

PTRNTAB4 aptb4VINSERTF128[] = /* VINSERTF128 */ {
        { VEX_NDS_256_WIG(0x660F3A18), _r, _ymm, _ymm, _xmm_m128, _imm8 },
        { ASM_END }
};

PTRNTAB3 aptb3VMASKMOVPS[] = /* VMASKMOVPS */ {
        { VEX_NDS_128_WIG(0x660F382C), _r, _xmm, _xmm, _m128 },
        { VEX_NDS_256_WIG(0x660F382C), _r, _ymm, _ymm, _m256 },
        { VEX_NDS_128_WIG(0x660F382E), _r, _m128, _xmm, _xmm },
        { VEX_NDS_256_WIG(0x660F382E), _r, _m256, _ymm, _ymm },
        { ASM_END }
};

PTRNTAB3 aptb3VMASKMOVPD[] = /* VMASKMOVPD */ {
        { VEX_NDS_128_WIG(0x660F382D), _r, _xmm, _xmm, _m128 },
        { VEX_NDS_256_WIG(0x660F382D), _r, _ymm, _ymm, _m256 },
        { VEX_NDS_128_WIG(0x660F382F), _r, _m128, _xmm, _xmm },
        { VEX_NDS_256_WIG(0x660F382F), _r, _m256, _ymm, _ymm },
        { ASM_END }
};

PTRNTAB0 aptb0VZEROALL[] = /* VZEROALL */ {
        { VEX_256_WIG(0x0F77), _modall }, // FIXME: need _modxmm
        { ASM_END },
};

PTRNTAB0 aptb0VZEROUPPER[] = /* VZEROUPPER */ {
        { VEX_128_WIG(0x0F77), _modall }, // FIXME: need _modxmm
        { ASM_END },
};

PTRNTAB0  aptb0XGETBV[] = /* XGETBV */ {
        { XGETBV, _modaxdx },
        { ASM_END },
};

PTRNTAB1  aptb1XRSTOR[] = /* XRSTOR */ {
        { 0x0FAE, _5, _m512 },
        { ASM_END }
};

PTRNTAB1  aptb1XRSTOR64[] = /* XRSTOR64 */ {
        { 0x0FAE, _5|_64_bit, _m512 }, // TODO: REX_W override is implicit
        { ASM_END }
};

PTRNTAB1  aptb1XSAVE[] = /* XSAVE */ {
        { 0x0FAE, _4, _m512 },
        { ASM_END }
};

PTRNTAB1  aptb1XSAVE64[] = /* XSAVE64 */ {
        { 0x0FAE, _4|_64_bit, _m512 }, // TODO: REX_W override is implicit
        { ASM_END }
};

PTRNTAB1  aptb1XSAVEOPT[] = /* XSAVEOPT */ {
        { 0x0FAE, _6, _m512 },
        { ASM_END }
};

PTRNTAB1  aptb1XSAVEOPT64[] = /* XSAVEOPT64 */ {
        { 0x0FAE, _6|_64_bit, _m512 }, // TODO: REX_W override is implicit
        { ASM_END }
};

PTRNTAB0  aptb0XSETBV[] = /* XSETBV */ {
        { XSETBV, 0 },
        { ASM_END },
};

PTRNTAB3  aptb3VPERMILPD[] = /* VPERMILPD */ {
        { VEX_NDS_128_WIG(0x660F380D), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(0x660F380D), _r, _ymm, _ymm, _ymm_m256 },
        { VEX_128_WIG(0x660F3A05), _r, _xmm, _xmm_m128, _imm8 },
        { VEX_256_WIG(0x660F3A05), _r, _ymm, _ymm_m256, _imm8 },
        { ASM_END },
};

PTRNTAB3  aptb3VPERMILPS[] = /* VPERMILPS */ {
        { VEX_NDS_128_WIG(0x660F380C), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(0x660F380C), _r, _ymm, _ymm, _ymm_m256 },
        { VEX_128_WIG(0x660F3A04), _r, _xmm, _xmm_m128, _imm8 },
        { VEX_256_WIG(0x660F3A04), _r, _ymm, _ymm_m256, _imm8 },
        { ASM_END },
};

PTRNTAB4  aptb3VPERM2F128[] = /* VPERM2F128 */ {
        { VEX_NDS_256_WIG(0x660F3A06), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END },
};

/* ======================= AES ======================= */

PTRNTAB2 aptb2AESENC[] = /* AESENC */ {
        { AESENC, _r, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB3 aptb3VAESENC[] = /* VAESENC */ {
        { VEX_NDS_128_WIG(AESENC), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB2 aptb2AESENCLAST[] = /* AESENCLAST */ {
        { AESENCLAST, _r, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB3 aptb3VAESENCLAST[] = /* VAESENCLAST */ {
        { VEX_NDS_128_WIG(AESENCLAST), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB2 aptb2AESDEC[] = /* AESDEC */ {
        { AESDEC, _r, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB3 aptb3VAESDEC[] = /* VAESDEC */ {
        { VEX_NDS_128_WIG(AESDEC), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB2 aptb2AESDECLAST[] = /* AESDECLAST */ {
        { AESDECLAST, _r, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB3 aptb3VAESDECLAST[] = /* VAESDECLAST */ {
        { VEX_NDS_128_WIG(AESDECLAST), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB2 aptb2AESIMC[] = /* AESIMC */ {
        { AESIMC, _r, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB2 aptb2VAESIMC[] = /* VAESIMC */ {
        { VEX_128_WIG(AESIMC), _r, _xmm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB3 aptb3AESKEYGENASSIST[] = /* AESKEYGENASSIST */ {
        { AESKEYGENASSIST, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END },
};

PTRNTAB3 aptb3VAESKEYGENASSIST[] = /* VAESKEYGENASSIST */ {
        { VEX_128_WIG(AESKEYGENASSIST), _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END },
};

/* ======================= FSGSBASE ======================= */

PTRNTAB1 aptb1RDFSBASE[] = /* RDFSBASE */ {
        { 0xF30FAE, _0, _r32 },
        { 0xF30FAE, _0|_64_bit, _r64 },
        { ASM_END },
};

PTRNTAB1 aptb1RDGSBASE[] = /* RDGSBASE */ {
        { 0xF30FAE, _1, _r32 },
        { 0xF30FAE, _1|_64_bit, _r64 },
        { ASM_END },
};

PTRNTAB1 aptb1WRFSBASE[] = /* WRFSBASE */ {
        { 0xF30FAE, _2, _r32 },
        { 0xF30FAE, _2|_64_bit, _r64 },
        { ASM_END },
};

PTRNTAB1 aptb1WRGSBASE[] = /* WRGSBASE */ {
        { 0xF30FAE, _3, _r32 },
        { 0xF30FAE, _3|_64_bit, _r64 },
        { ASM_END },
};

/* ======================= RDRAND ======================= */

PTRNTAB1 aptb1RDRAND[] = /* RDRAND */ {
        { 0x0FC7, _6|_16_bit, _r16 },
        { 0x0FC7, _6|_32_bit, _r32 },
        { 0x0FC7, _6|_64_bit, _r64 },
        { ASM_END },
};

/* ======================= FP16C ======================= */

PTRNTAB2 aptb2VCVTPH2PS[] = /* VCVTPH2PS */ {
        { VEX_128_WIG(0x660F3813), _r, _xmm, _xmm_m64 },
        { VEX_256_WIG(0x660F3813), _r, _ymm, _xmm_m128 },
        { ASM_END },
};

PTRNTAB3 aptb3VCVTPS2PH[] = /* VCVTPS2PH */ {
        { VEX_128_WIG(0x660F3A13), _r, _xmm_m64, _xmm, _imm8  },
        { VEX_256_WIG(0x660F3A13), _r, _xmm_m128, _ymm, _imm8  },
        { ASM_END },
};

/* ======================= FMA ======================= */

PTRNTAB3 aptb3VFMADD132PD[] = /* VFMADD132PD */ {
        { VEX_DDS_128_W1(0x660F3898), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F3898), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD213PD[] = /* VFMADD213PD */ {
        { VEX_DDS_128_W1(0x660F38A8), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38A8), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD231PD[] = /* VFMADD231PD */ {
        { VEX_DDS_128_W1(0x660F38B8), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38B8), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD132PS[] = /* VFMADD132PS */ {
        { VEX_DDS_128_WIG(0x660F3898), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F3898), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD213PS[] = /* VFMADD213PS */ {
        { VEX_DDS_128_WIG(0x660F38A8), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38A8), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD231PS[] = /* VFMADD231PS */ {
        { VEX_DDS_128_WIG(0x660F38B8), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38B8), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD132SD[] = /* VFMADD132SD */ {
        { VEX_DDS_128_W1(0x660F3899), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD213SD[] = /* VFMADD213SD */ {
        { VEX_DDS_128_W1(0x660F38A9), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD231SD[] = /* VFMADD231SD */ {
        { VEX_DDS_128_W1(0x660F38B9), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD132SS[] = /* VFMADD132SS */ {
        { VEX_DDS_128_WIG(0x660F3899), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD213SS[] = /* VFMADD213SS */ {
        { VEX_DDS_128_WIG(0x660F38A9), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADD231SS[] = /* VFMADD231SS */ {
        { VEX_DDS_128_WIG(0x660F38B9), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADDSUB132PD[] = /* VFMADDSUB132PD */ {
        { VEX_DDS_128_W1(0x660F3896), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F3896), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADDSUB213PD[] = /* VFMADDSUB213PD */ {
        { VEX_DDS_128_W1(0x660F38A6), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38A6), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADDSUB231PD[] = /* VFMADDSUB231PD */ {
        { VEX_DDS_128_W1(0x660F38B6), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38B6), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADDSUB132PS[] = /* VFMADDSUB132PS */ {
        { VEX_DDS_128_WIG(0x660F3896), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F3896), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADDSUB213PS[] = /* VFMADDSUB213PS */ {
        { VEX_DDS_128_WIG(0x660F38A6), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38A6), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMADDSUB231PS[] = /* VFMADDSUB231PS */ {
        { VEX_DDS_128_WIG(0x660F38B6), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38B6), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUBADD132PD[] = /* VFMSUBADD132PD */ {
        { VEX_DDS_128_W1(0x660F3897), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F3897), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUBADD213PD[] = /* VFMSUBADD213PD */ {
        { VEX_DDS_128_W1(0x660F38A7), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38A7), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUBADD231PD[] = /* VFMSUBADD231PD */ {
        { VEX_DDS_128_W1(0x660F38B7), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38B7), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUBADD132PS[] = /* VFMSUBADD132PS */ {
        { VEX_DDS_128_WIG(0x660F3897), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F3897), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUBADD213PS[] = /* VFMSUBADD213PS */ {
        { VEX_DDS_128_WIG(0x660F38A7), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38A7), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUBADD231PS[] = /* VFMSUBADD231PS */ {
        { VEX_DDS_128_WIG(0x660F38B7), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38B7), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB132PD[] = /* VFMSUB132PD */ {
        { VEX_DDS_128_W1(0x660F389A), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F389A), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB213PD[] = /* VFMSUB213PD */ {
        { VEX_DDS_128_W1(0x660F38AA), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38AA), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB231PD[] = /* VFMSUB231PD */ {
        { VEX_DDS_128_W1(0x660F38BA), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38BA), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB132PS[] = /* VFMSUB132PS */ {
        { VEX_DDS_128_WIG(0x660F389A), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F389A), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB213PS[] = /* VFMSUB213PS */ {
        { VEX_DDS_128_WIG(0x660F38AA), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38AA), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB231PS[] = /* VFMSUB231PS */ {
        { VEX_DDS_128_WIG(0x660F38BA), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38BA), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB132SD[] = /* VFMSUB132SD */ {
        { VEX_DDS_128_W1(0x660F389B), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB213SD[] = /* VFMSUB213SD */ {
        { VEX_DDS_128_W1(0x660F38AB), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB231SD[] = /* VFMSUB231SD */ {
        { VEX_DDS_128_W1(0x660F38BB), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB132SS[] = /* VFMSUB132SS */ {
        { VEX_DDS_128_WIG(0x660F389B), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB213SS[] = /* VFMSUB213SS */ {
        { VEX_DDS_128_WIG(0x660F38AB), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

PTRNTAB3 aptb3VFMSUB231SS[] = /* VFMSUB231SS */ {
        { VEX_DDS_128_WIG(0x660F38BB), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
};

/* ======================= SHA ======================= */

PTRNTAB3 aptb3SHA1RNDS4[] = /* SHA1RNDS4 */ {
        { 0x0F3ACC, _ib, _xmm, _xmm_m128, _imm8 },
        { ASM_END },
};

PTRNTAB2 aptb2SHA1NEXTE[] = /* SHA1NEXTE */ {
        { 0x0F38C8, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2SHA1MSG1[] = /* SHA1MSG1 */ {
        { 0x0F38C9, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2SHA1MSG2[] = /* SHA1MSG2 */ {
        { 0x0F38CA, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2SHA256RNDS2[] = /* SHA256RNDS2 */ {
        { 0x0F38CB, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2SHA256MSG1[] = /* SHA256MSG1 */ {
        { 0x0F38CC, _r, _xmm, _xmm_m128 },
        { ASM_END }
};

PTRNTAB2 aptb2SHA256MSG2[] = /* SHA256MSG2 */ {
        { 0x0F38CD, _r, _xmm, _xmm_m128 },
        { ASM_END }
};
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
#define OPCODETABLE                             \
        X("aaa",        0,              aptb0AAA )
#else
#define OPCODETABLE1                                            \
        X("__emit",     ITdata | OPdb,  NULL )                      \
        X("_emit",      ITdata | OPdb,  NULL )                      \
        X("aaa",        0,              aptb0AAA )                  \
        X("aad",        0,              aptb0AAD )                  \
        X("aam",        0,              aptb0AAM )                  \
        X("aas",        0,              aptb0AAS )                  \
        X("adc",        2,              (P) aptb2ADC )              \
        X("add",        2,              (P) aptb2ADD )              \
        X("addpd",      2,              (P) aptb2ADDPD )            \
        X("addps",      2,              (P) aptb2ADDPS )            \
        X("addsd",      2,              (P) aptb2ADDSD )            \
        X("addss",      2,              (P) aptb2ADDSS )            \
        X("addsubpd",   2,              (P) aptb2ADDSUBPD )         \
        X("addsubps",   2,              (P) aptb2ADDSUBPS )         \
        X("aesdec",     2,              (P) aptb2AESDEC )           \
        X("aesdeclast", 2,              (P) aptb2AESDECLAST )       \
        X("aesenc",     2,              (P) aptb2AESENC )           \
        X("aesenclast", 2,              (P) aptb2AESENCLAST )       \
        X("aesimc",     2,              (P) aptb2AESIMC )           \
        X("aeskeygenassist", 3,         (P) aptb3AESKEYGENASSIST )  \
        X("and",        2,              (P) aptb2AND )              \
        X("andnpd",     2,              (P) aptb2ANDNPD )           \
        X("andnps",     2,              (P) aptb2ANDNPS )           \
        X("andpd",      2,              (P) aptb2ANDPD )            \
        X("andps",      2,              (P) aptb2ANDPS )            \
        X("arpl",       2,              (P) aptb2ARPL )             \
        X("blendpd",    3,              (P) aptb3BLENDPD )          \
        X("blendps",    3,              (P) aptb3BLENDPS )          \
        X("blendvpd",   3,              (P) aptb3BLENDVPD )         \
        X("blendvps",   3,              (P) aptb3BLENDVPS )         \
        X("bound",      2,              (P) aptb2BOUND )            \
        X("bsf",        2,              (P) aptb2BSF )              \
        X("bsr",        2,              (P) aptb2BSR )              \
        X("bswap",      1,              (P) aptb1BSWAP )            \
        X("bt",         2,              (P) aptb2BT )               \
        X("btc",        2,              (P) aptb2BTC )              \
        X("btr",        2,              (P) aptb2BTR )              \
        X("bts",        2,              (P) aptb2BTS )              \
        X("call",       ITjump | 1,     (P) aptb1CALL )             \
        X("cbw",        0,              aptb0CBW )                  \
        X("cdq",        0,              aptb0CDQ )                  \
        X("cdqe",       0,              aptb0CDQE )                 \
        X("clc",        0,              aptb0CLC )                  \
        X("cld",        0,              aptb0CLD )                  \
        X("clflush",    1,              (P) aptb1CLFLUSH )          \
        X("cli",        0,              aptb0CLI )                  \
        X("clts",       0,              aptb0CLTS )                 \
        X("cmc",        0,              aptb0CMC )                  \
        X("cmova",      2,              (P) aptb2CMOVNBE )          \
        X("cmovae",     2,              (P) aptb2CMOVNB )           \
        X("cmovb",      2,              (P) aptb2CMOVB )            \
        X("cmovbe",     2,              (P) aptb2CMOVBE )           \
        X("cmovc",      2,              (P) aptb2CMOVB )            \
        X("cmove",      2,              (P) aptb2CMOVZ )            \
        X("cmovg",      2,              (P) aptb2CMOVNLE )          \
        X("cmovge",     2,              (P) aptb2CMOVNL )           \
        X("cmovl",      2,              (P) aptb2CMOVL )            \
        X("cmovle",     2,              (P) aptb2CMOVLE )           \
        X("cmovna",     2,              (P) aptb2CMOVBE )           \
        X("cmovnae",    2,              (P) aptb2CMOVB )            \
        X("cmovnb",     2,              (P) aptb2CMOVNB )           \
        X("cmovnbe",    2,              (P) aptb2CMOVNBE )          \
        X("cmovnc",     2,              (P) aptb2CMOVNB )           \
        X("cmovne",     2,              (P) aptb2CMOVNZ )           \
        X("cmovng",     2,              (P) aptb2CMOVLE )           \
        X("cmovnge",    2,              (P) aptb2CMOVL )            \
        X("cmovnl",     2,              (P) aptb2CMOVNL )           \
        X("cmovnle",    2,              (P) aptb2CMOVNLE )          \
        X("cmovno",     2,              (P) aptb2CMOVNO )           \
        X("cmovnp",     2,              (P) aptb2CMOVNP )           \
        X("cmovns",     2,              (P) aptb2CMOVNS )           \
        X("cmovnz",     2,              (P) aptb2CMOVNZ )           \
        X("cmovo",      2,              (P) aptb2CMOVO )            \
        X("cmovp",      2,              (P) aptb2CMOVP )            \
        X("cmovpe",     2,              (P) aptb2CMOVP )            \
        X("cmovpo",     2,              (P) aptb2CMOVNP )           \
        X("cmovs",      2,              (P) aptb2CMOVS )            \
        X("cmovz",      2,              (P) aptb2CMOVZ )            \
        X("cmp",        2,              (P) aptb2CMP )              \
        X("cmppd",      3,              (P) aptb3CMPPD )            \
        X("cmpps",      3,              (P) aptb3CMPPS )            \
        X("cmps",       2,              (P) aptb2CMPS )             \
        X("cmpsb",      0,              aptb0CMPSB )                \
        /*X("cmpsd",    0,              aptb0CMPSD )*/              \
        X("cmpsd",      ITopt|3,        (P) aptb3CMPSD )            \
        X("cmpsq",      0,              aptb0CMPSQ )                \
        X("cmpss",      3,              (P) aptb3CMPSS )            \
        X("cmpsw",      0,              aptb0CMPSW )                \
        X("cmpxchg",    2,              (P) aptb2CMPXCHG )          \
        X("cmpxchg16b", 1,              (P) aptb1CMPXCH16B )        \
        X("cmpxchg8b",  1,              (P) aptb1CMPXCH8B )         \
        X("comisd",     2,              (P) aptb2COMISD )           \
        X("comiss",     2,              (P) aptb2COMISS )           \
        X("cpuid",      0,              aptb0CPUID )                \
        X("cqo",        0,              aptb0CQO )                  \
        X("crc32",      2,              (P) aptb2CRC32 )            \
        X("cvtdq2pd",   2,              (P) aptb2CVTDQ2PD )         \
        X("cvtdq2ps",   2,              (P) aptb2CVTDQ2PS )         \
        X("cvtpd2dq",   2,              (P) aptb2CVTPD2DQ )         \
        X("cvtpd2pi",   2,              (P) aptb2CVTPD2PI )         \
        X("cvtpd2ps",   2,              (P) aptb2CVTPD2PS )         \
        X("cvtpi2pd",   2,              (P) aptb2CVTPI2PD )         \
        X("cvtpi2ps",   2,              (P) aptb2CVTPI2PS )         \
        X("cvtps2dq",   2,              (P) aptb2CVTPS2DQ )         \
        X("cvtps2pd",   2,              (P) aptb2CVTPS2PD )         \
        X("cvtps2pi",   2,              (P) aptb2CVTPS2PI )         \
        X("cvtsd2si",   2,              (P) aptb2CVTSD2SI )         \
        X("cvtsd2ss",   2,              (P) aptb2CVTSD2SS )         \
        X("cvtsi2sd",   2,              (P) aptb2CVTSI2SD )         \
        X("cvtsi2ss",   2,              (P) aptb2CVTSI2SS )         \
        X("cvtss2sd",   2,              (P) aptb2CVTSS2SD )         \
        X("cvtss2si",   2,              (P) aptb2CVTSS2SI )         \
        X("cvttpd2dq",  2,              (P) aptb2CVTTPD2DQ )        \
        X("cvttpd2pi",  2,              (P) aptb2CVTTPD2PI )        \
        X("cvttps2dq",  2,              (P) aptb2CVTTPS2DQ )        \
        X("cvttps2pi",  2,              (P) aptb2CVTTPS2PI )        \
        X("cvttsd2si",  2,              (P) aptb2CVTTSD2SI )        \
        X("cvttss2si",  2,              (P) aptb2CVTTSS2SI )        \
        X("cwd",        0,              aptb0CWD )                  \
        X("cwde",       0,              aptb0CWDE )                 \
        X("da",         ITaddr | 4,     NULL )                      \
        X("daa",        0,              aptb0DAA )                  \
        X("das",        0,              aptb0DAS )                  \
        X("db",         ITdata | OPdb,  NULL )                      \
        X("dd",         ITdata | OPdd,  NULL )                      \
        X("de",         ITdata | OPde,  NULL )                      \
        X("dec",        1,              (P) aptb1DEC )              \
        X("df",         ITdata | OPdf,  NULL )                      \
        X("di",         ITdata | OPdi,  NULL )                      \
        X("div",        ITopt  | 2,     (P) aptb2DIV )              \
        X("divpd",      2,              (P) aptb2DIVPD )            \
        X("divps",      2,              (P) aptb2DIVPS )            \
        X("divsd",      2,              (P) aptb2DIVSD )            \
        X("divss",      2,              (P) aptb2DIVSS )            \
        X("dl",         ITdata | OPdl,  NULL )                      \
        X("dppd",       3,              (P) aptb3DPPD )             \
        X("dpps",       3,              (P) aptb3DPPS )             \
        X("dq",         ITdata | OPdq,  NULL )                      \
        X("ds",         ITdata | OPds,  NULL )                      \
        X("dt",         ITdata | OPdt,  NULL )                      \
        X("dw",         ITdata | OPdw,  NULL )                      \
        X("emms",       0,              aptb0EMMS )                 \
        X("enter",      2,              (P) aptb2ENTER )            \
        X("extractps",  3,              (P) aptb3EXTRACTPS )        \
        X("f2xm1",      ITfloat | 0,    aptb0F2XM1 )                \
        X("fabs",       ITfloat | 0,    aptb0FABS )                 \
        X("fadd",       ITfloat | 2,    (P) aptb2FADD )             \
        X("faddp",      ITfloat | 2,    (P) aptb2FADDP )            \
        X("fbld",       ITfloat | 1,    (P) aptb1FBLD )             \
        X("fbstp",      ITfloat | 1,    (P) aptb1FBSTP )            \
        X("fchs",       ITfloat | 0,    aptb0FCHS )                 \
        X("fclex",      ITfloat | 0,    aptb0FCLEX )                \
        X("fcmovb",     ITfloat | 2,    (P) aptb2FCMOVB )           \
        X("fcmovbe",    ITfloat | 2,    (P) aptb2FCMOVBE )          \
        X("fcmove",     ITfloat | 2,    (P) aptb2FCMOVE )           \
        X("fcmovnb",    ITfloat | 2,    (P) aptb2FCMOVNB )          \
        X("fcmovnbe",   ITfloat | 2,    (P) aptb2FCMOVNBE )         \
        X("fcmovne",    ITfloat | 2,    (P) aptb2FCMOVNE )          \
        X("fcmovnu",    ITfloat | 2,    (P) aptb2FCMOVNU )          \
        X("fcmovu",     ITfloat | 2,    (P) aptb2FCMOVU )           \
        X("fcom",       ITfloat | 1,    (P) aptb1FCOM )             \
        X("fcomi",      ITfloat | 2,    (P) aptb2FCOMI )            \
        X("fcomip",     ITfloat | 2,    (P) aptb2FCOMIP )           \
        X("fcomp",      ITfloat | 1,    (P) aptb1FCOMP )            \
        X("fcompp",     ITfloat | 0,    aptb0FCOMPP )               \
        X("fcos",       ITfloat | 0,    aptb0FCOS )                 \
        X("fdecstp",    ITfloat | 0,    aptb0FDECSTP )              \
        X("fdisi",      ITfloat | 0,    aptb0FDISI )                \
        X("fdiv",       ITfloat | 2,    (P) aptb2FDIV )             \
        X("fdivp",      ITfloat | 2,    (P) aptb2FDIVP )            \
        X("fdivr",      ITfloat | 2,    (P) aptb2FDIVR )            \
        X("fdivrp",     ITfloat | 2,    (P) aptb2FDIVRP )           \
        X("feni",       ITfloat | 0,    aptb0FENI )                 \
        X("ffree",      ITfloat | 1,    (P) aptb1FFREE )            \
        X("fiadd",      ITfloat | 2,    (P) aptb2FIADD )            \
        X("ficom",      ITfloat | 1,    (P) aptb1FICOM )            \
        X("ficomp",     ITfloat | 1,    (P) aptb1FICOMP )           \
        X("fidiv",      ITfloat | 2,    (P) aptb2FIDIV )            \
        X("fidivr",     ITfloat | 2,    (P) aptb2FIDIVR )           \
        X("fild",       ITfloat | 1,    (P) aptb1FILD )             \
        X("fimul",      ITfloat | 2,    (P) aptb2FIMUL )            \
        X("fincstp",    ITfloat | 0,    aptb0FINCSTP )              \
        X("finit",      ITfloat | 0,    aptb0FINIT )                \
        X("fist",       ITfloat | 1,    (P) aptb1FIST )             \
        X("fistp",      ITfloat | 1,    (P) aptb1FISTP )            \
        X("fisttp",     ITfloat | 1,    (P) aptb1FISTTP )           \
        X("fisub",      ITfloat | 2,    (P) aptb2FISUB )            \
        X("fisubr",     ITfloat | 2,    (P) aptb2FISUBR )           \
        X("fld",        ITfloat | 1,    (P) aptb1FLD )              \
        X("fld1",       ITfloat | 0,    aptb0FLD1 )                 \
        X("fldcw",      ITfloat | 1,    (P) aptb1FLDCW )            \
        X("fldenv",     ITfloat | 1,    (P) aptb1FLDENV )           \
        X("fldl2e",     ITfloat | 0,    aptb0FLDL2E )               \
        X("fldl2t",     ITfloat | 0,    aptb0FLDL2T )               \
        X("fldlg2",     ITfloat | 0,    aptb0FLDLG2 )               \
        X("fldln2",     ITfloat | 0,    aptb0FLDLN2 )               \
        X("fldpi",      ITfloat | 0,    aptb0FLDPI )                \
        X("fldz",       ITfloat | 0,    aptb0FLDZ )                 \
        X("fmul",       ITfloat | 2,    (P) aptb2FMUL )             \
        X("fmulp",      ITfloat | 2,    (P) aptb2FMULP )            \
        X("fnclex",     ITfloat | 0,    aptb0FNCLEX )               \
        X("fndisi",     ITfloat | 0,    aptb0FNDISI )               \
        X("fneni",      ITfloat | 0,    aptb0FNENI )                \
        X("fninit",     ITfloat | 0,    aptb0FNINIT )               \
        X("fnop",       ITfloat | 0,    aptb0FNOP )                 \
        X("fnsave",     ITfloat | 1,    (P) aptb1FNSAVE )           \
        X("fnstcw",     ITfloat | 1,    (P) aptb1FNSTCW )           \
        X("fnstenv",    ITfloat | 1,    (P) aptb1FNSTENV )          \
        X("fnstsw",     1,              (P) aptb1FNSTSW )           \
        X("fpatan",     ITfloat | 0,    aptb0FPATAN )               \
        X("fprem",      ITfloat | 0,    aptb0FPREM )                \
        X("fprem1",     ITfloat | 0,    aptb0FPREM1 )               \
        X("fptan",      ITfloat | 0,    aptb0FPTAN )                \
        X("frndint",    ITfloat | 0,    aptb0FRNDINT )              \
        X("frstor",     ITfloat | 1,    (P) aptb1FRSTOR )           \
        X("fsave",      ITfloat | 1,    (P) aptb1FSAVE )            \
        X("fscale",     ITfloat | 0,    aptb0FSCALE )               \
        X("fsetpm",     ITfloat | 0,    aptb0FSETPM )               \
        X("fsin",       ITfloat | 0,    aptb0FSIN )                 \
        X("fsincos",    ITfloat | 0,    aptb0FSINCOS )              \
        X("fsqrt",      ITfloat | 0,    aptb0FSQRT )                \
        X("fst",        ITfloat | 1,    (P) aptb1FST )              \
        X("fstcw",      ITfloat | 1,    (P) aptb1FSTCW )            \
        X("fstenv",     ITfloat | 1,    (P) aptb1FSTENV )           \
        X("fstp",       ITfloat | 1,    (P) aptb1FSTP )             \
        X("fstsw",      1,              (P) aptb1FSTSW )            \
        X("fsub",       ITfloat | 2,    (P) aptb2FSUB )             \
        X("fsubp",      ITfloat | 2,    (P) aptb2FSUBP )            \
        X("fsubr",      ITfloat | 2,    (P) aptb2FSUBR )            \
        X("fsubrp",     ITfloat | 2,    (P) aptb2FSUBRP )           \
        X("ftst",       ITfloat | 0,    aptb0FTST )                 \
        X("fucom",      ITfloat | 1,    (P) aptb1FUCOM )            \
        X("fucomi",     ITfloat | 2,    (P) aptb2FUCOMI )           \
        X("fucomip",    ITfloat | 2,    (P) aptb2FUCOMIP )          \
        X("fucomp",     ITfloat | 1,    (P) aptb1FUCOMP )           \
        X("fucompp",    ITfloat | 0,    aptb0FUCOMPP )              \
        X("fwait",      ITfloat | 0,    aptb0FWAIT )                \
        X("fxam",       ITfloat | 0,    aptb0FXAM )                 \
        X("fxch",       ITfloat | 1,    (P) aptb1FXCH )             \
        X("fxrstor",    ITfloat | 1,    (P) aptb1FXRSTOR )          \
        X("fxsave",     ITfloat | 1,    (P) aptb1FXSAVE )           \
        X("fxtract",    ITfloat | 0,    aptb0FXTRACT )              \
        X("fyl2x",      ITfloat | 0,    aptb0FYL2X )                \
        X("fyl2xp1",    ITfloat | 0,    aptb0FYL2XP1 )              \
        X("haddpd",     2,              (P) aptb2HADDPD )           \
        X("haddps",     2,              (P) aptb2HADDPS )           \
        X("hlt",        0,              aptb0HLT )                  \
        X("hsubpd",     2,              (P) aptb2HSUBPD )           \
        X("hsubps",     2,              (P) aptb2HSUBPS )           \
        X("idiv",       ITopt | 2,      (P) aptb2IDIV )             \
        X("imul",       ITopt | 3,      (P) aptb3IMUL )             \
        X("in",         2,              (P) aptb2IN )               \
        X("inc",        1,              (P) aptb1INC )              \
        X("ins",        2,              (P) aptb2INS )              \
        X("insb",       0,              aptb0INSB )                 \
        X("insd",       0,              aptb0INSD )                 \
        X("insertps",   3,              (P) aptb3INSERTPS )         \
        X("insw",       0,              aptb0INSW )                 \
        X("int",        ITimmed | 1,    (P) aptb1INT )              \
        X("into",       0,              aptb0INTO )                 \
        X("invd",       0,              aptb0INVD )                 \
        X("invlpg",     1,              (P) aptb1INVLPG )           \
        X("iret",       0,              aptb0IRET )                 \
        X("iretd",      0,              aptb0IRETD )                \
        X("ja",         ITjump | 1,     (P) aptb1JNBE )             \
        X("jae",        ITjump | 1,     (P) aptb1JNB )              \
        X("jb",         ITjump | 1,     (P) aptb1JB )               \
        X("jbe",        ITjump | 1,     (P) aptb1JBE )              \
        X("jc",         ITjump | 1,     (P) aptb1JB )               \
        X("jcxz",       ITjump | 1,     (P) aptb1JCXZ )             \
        X("je",         ITjump | 1,     (P) aptb1JZ )               \
        X("jecxz",      ITjump | 1,     (P) aptb1JECXZ )            \
        X("jg",         ITjump | 1,     (P) aptb1JNLE )             \
        X("jge",        ITjump | 1,     (P) aptb1JNL )              \
        X("jl",         ITjump | 1,     (P) aptb1JL )               \
        X("jle",        ITjump | 1,     (P) aptb1JLE )              \
        X("jmp",        ITjump | 1,     (P) aptb1JMP )              \
        X("jna",        ITjump | 1,     (P) aptb1JBE )              \
        X("jnae",       ITjump | 1,     (P) aptb1JB )               \
        X("jnb",        ITjump | 1,     (P) aptb1JNB )              \
        X("jnbe",       ITjump | 1,     (P) aptb1JNBE )             \
        X("jnc",        ITjump | 1,     (P) aptb1JNB )              \
        X("jne",        ITjump | 1,     (P) aptb1JNZ )              \
        X("jng",        ITjump | 1,     (P) aptb1JLE )              \
        X("jnge",       ITjump | 1,     (P) aptb1JL )               \
        X("jnl",        ITjump | 1,     (P) aptb1JNL )              \
        X("jnle",       ITjump | 1,     (P) aptb1JNLE )             \
        X("jno",        ITjump | 1,     (P) aptb1JNO )              \
        X("jnp",        ITjump | 1,     (P) aptb1JNP )              \
        X("jns",        ITjump | 1,     (P) aptb1JNS )              \
        X("jnz",        ITjump | 1,     (P) aptb1JNZ )              \
        X("jo",         ITjump | 1,     (P) aptb1JO )               \
        X("jp",         ITjump | 1,     (P) aptb1JP )               \
        X("jpe",        ITjump | 1,     (P) aptb1JP )               \
        X("jpo",        ITjump | 1,     (P) aptb1JNP )              \
        X("js",         ITjump | 1,     (P) aptb1JS )               \
        X("jz",         ITjump | 1,     (P) aptb1JZ )               \


#define OPCODETABLE2                                                    \
        X("lahf",           0,              aptb0LAHF )                     \
        X("lar",            2,              (P) aptb2LAR )                  \
        X("lddqu",          2,              (P) aptb2LDDQU )                \
        X("ldmxcsr",        1,              (P) aptb1LDMXCSR )              \
        X("lds",            2,              (P) aptb2LDS )                  \
        X("lea",            2,              (P) aptb2LEA )                  \
        X("leave",          0,              aptb0LEAVE )                    \
        X("les",            2,              (P) aptb2LES )                  \
        X("lfence",         0,              aptb0LFENCE)                    \
        X("lfs",            2,              (P) aptb2LFS )                  \
        X("lgdt",           1,              (P) aptb1LGDT )                 \
        X("lgs",            2,              (P) aptb2LGS )                  \
        X("lidt",           1,              (P) aptb1LIDT )                 \
        X("lldt",           1,              (P) aptb1LLDT )                 \
        X("lmsw",           1,              (P) aptb1LMSW )                 \
        X("lock",           ITprefix | 0,   aptb0LOCK )                     \
        X("lods",           1,              (P) aptb1LODS )                 \
        X("lodsb",          0,              aptb0LODSB )                    \
        X("lodsd",          0,              aptb0LODSD )                    \
        X("lodsq",          0,              aptb0LODSQ )                    \
        X("lodsw",          0,              aptb0LODSW )                    \
        X("loop",           ITjump | 1,     (P) aptb1LOOP )                 \
        X("loope",          ITjump | 1,     (P) aptb1LOOPE )                \
        X("loopne",         ITjump | 1,     (P) aptb1LOOPNE )               \
        X("loopnz",         ITjump | 1,     (P) aptb1LOOPNE )               \
        X("loopz",          ITjump | 1,     (P) aptb1LOOPE )                \
        X("lsl",            2,              (P) aptb2LSL )                  \
        X("lss",            2,              (P) aptb2LSS )                  \
        X("ltr",            1,              (P) aptb1LTR )                  \
        X("maskmovdqu",     2,              (P) aptb2MASKMOVDQU )           \
        X("maskmovq",       2,              (P) aptb2MASKMOVQ )             \
        X("maxpd",          2,              (P) aptb2MAXPD )                \
        X("maxps",          2,              (P) aptb2MAXPS )                \
        X("maxsd",          2,              (P) aptb2MAXSD )                \
        X("maxss",          2,              (P) aptb2MAXSS )                \
        X("mfence",         0,              aptb0MFENCE)                    \
        X("minpd",          2,              (P) aptb2MINPD )                \
        X("minps",          2,              (P) aptb2MINPS )                \
        X("minsd",          2,              (P) aptb2MINSD )                \
        X("minss",          2,              (P) aptb2MINSS )                \
        X("monitor",        0,              (P) aptb0MONITOR )              \
        X("mov",            2,              (P) aptb2MOV )                  \
        X("movapd",         2,              (P) aptb2MOVAPD )               \
        X("movaps",         2,              (P) aptb2MOVAPS )               \
        X("movd",           2,              (P) aptb2MOVD )                 \
        X("movddup",        2,              (P) aptb2MOVDDUP )              \
        X("movdq2q",        2,              (P) aptb2MOVDQ2Q )              \
        X("movdqa",         2,              (P) aptb2MOVDQA )               \
        X("movdqu",         2,              (P) aptb2MOVDQU )               \
        X("movhlps",        2,              (P) aptb2MOVHLPS )              \
        X("movhpd",         2,              (P) aptb2MOVHPD )               \
        X("movhps",         2,              (P) aptb2MOVHPS )               \
        X("movlhps",        2,              (P) aptb2MOVLHPS )              \
        X("movlpd",         2,              (P) aptb2MOVLPD )               \
        X("movlps",         2,              (P) aptb2MOVLPS )               \
        X("movmskpd",       2,              (P) aptb2MOVMSKPD )             \
        X("movmskps",       2,              (P) aptb2MOVMSKPS )             \
        X("movntdq",        2,              (P) aptb2MOVNTDQ )              \
        X("movntdqa",       2,              (P) aptb2MOVNTDQA )             \
        X("movnti",         2,              (P) aptb2MOVNTI )               \
        X("movntpd",        2,              (P) aptb2MOVNTPD )              \
        X("movntps",        2,              (P) aptb2MOVNTPS )              \
        X("movntq",         2,              (P) aptb2MOVNTQ )               \
        X("movq",           2,              (P) aptb2MOVQ )                 \
        X("movq2dq",        2,              (P) aptb2MOVQ2DQ )              \
        X("movs",           2,              (P) aptb2MOVS )                 \
        X("movsb",          0,              aptb0MOVSB )                    \
        X("movsd",          ITopt | 2,      (P) aptb2MOVSD )                \
        X("movshdup",       2,              (P) aptb2MOVSHDUP )             \
        X("movsldup",       2,              (P) aptb2MOVSLDUP )             \
        X("movsq",          0,              aptb0MOVSQ )                    \
        X("movss",          2,              (P) aptb2MOVSS )                \
        X("movsw",          0,              aptb0MOVSW )                    \
        X("movsx",          2,              (P) aptb2MOVSX )                \
        X("movsxd",         2,              (P) aptb2MOVSXD )               \
        X("movupd",         2,              (P) aptb2MOVUPD )               \
        X("movups",         2,              (P) aptb2MOVUPS )               \
        X("movzx",          2,              (P) aptb2MOVZX )                \
        X("mpsadbw",        3,              (P) aptb3MPSADBW )              \
        X("mul",            ITopt | 2,      (P) aptb2MUL )                  \
        X("mulpd",          2,              (P) aptb2MULPD )                \
        X("mulps",          2,              (P) aptb2MULPS )                \
        X("mulsd",          2,              (P) aptb2MULSD )                \
        X("mulss",          2,              (P) aptb2MULSS )                \
        X("mwait",          0,              (P) aptb0MWAIT )                \
        X("neg",            1,              (P) aptb1NEG )                  \
        X("nop",            0,              aptb0NOP )                      \
        X("not",            1,              (P) aptb1NOT )                  \
        X("or",             2,              (P) aptb2OR )                   \
        X("orpd",           2,              (P) aptb2ORPD )                 \
        X("orps",           2,              (P) aptb2ORPS )                 \
        X("out",            2,              (P) aptb2OUT )                  \
        X("outs",           2,              (P) aptb2OUTS )                 \
        X("outsb",          0,              aptb0OUTSB )                    \
        X("outsd",          0,              aptb0OUTSD )                    \
        X("outsw",          0,              aptb0OUTSW )                    \
        X("pabsb",          2,              (P) aptb2PABSB )                \
        X("pabsd",          2,              (P) aptb2PABSD )                \
        X("pabsw",          2,              (P) aptb2PABSW )                \
        X("packssdw",       2,              (P) aptb2PACKSSDW )             \
        X("packsswb",       2,              (P) aptb2PACKSSWB )             \
        X("packusdw",       2,              (P) aptb2PACKUSDW )             \
        X("packuswb",       2,              (P) aptb2PACKUSWB )             \
        X("paddb",          2,              (P) aptb2PADDB )                \
        X("paddd",          2,              (P) aptb2PADDD )                \
        X("paddq",          2,              (P) aptb2PADDQ )                \
        X("paddsb",         2,              (P) aptb2PADDSB )               \
        X("paddsw",         2,              (P) aptb2PADDSW )               \
        X("paddusb",        2,              (P) aptb2PADDUSB )              \
        X("paddusw",        2,              (P) aptb2PADDUSW )              \
        X("paddw",          2,              (P) aptb2PADDW )                \
        X("palignr",        3,              (P) aptb3PALIGNR )              \
        X("pand",           2,              (P) aptb2PAND )                 \
        X("pandn",          2,              (P) aptb2PANDN )                \
        /* X("pause",       0,              aptb0PAUSE) */                  \
        X("pavgb",          2,              (P) aptb2PAVGB )                \
        X("pavgusb",        2,              (P) aptb2PAVGUSB )              \
        X("pavgw",          2,              (P) aptb2PAVGW )                \
        X("pblendvb",       3,              (P) aptb3PBLENDVB )             \
        X("pblendw",        3,              (P) aptb3PBLENDW )              \
        X("pcmpeqb",        2,              (P) aptb2PCMPEQB )              \
        X("pcmpeqd",        2,              (P) aptb2PCMPEQD )              \
        X("pcmpeqq",        2,              (P) aptb2PCMPEQQ )              \
        X("pcmpeqw",        2,              (P) aptb2PCMPEQW )              \
        X("pcmpestri",      3,              (P) aptb3PCMPESTRI )            \
        X("pcmpestrm",      3,              (P) aptb3PCMPESTRM )            \
        X("pcmpgtb",        2,              (P) aptb2PCMPGTB )              \
        X("pcmpgtd",        2,              (P) aptb2PCMPGTD )              \
        X("pcmpgtq",        2,              (P) aptb2PCMPGTQ )              \
        X("pcmpgtw",        2,              (P) aptb2PCMPGTW )              \
        X("pcmpistri",      3,              (P) aptb3PCMPISTRI )            \
        X("pcmpistrm",      3,              (P) aptb3PCMPISTRM )            \
        X("pextrb",         3,              (P) aptb3PEXTRB )               \
        X("pextrd",         3,              (P) aptb3PEXTRD )               \
        X("pextrq",         3,              (P) aptb3PEXTRQ )               \
        X("pextrw",         3,              (P) aptb3PEXTRW )               \
        X("pf2id",          2,              (P) aptb2PF2ID )                \
        X("pfacc",          2,              (P) aptb2PFACC )                \
        X("pfadd",          2,              (P) aptb2PFADD )                \
        X("pfcmpeq",        2,              (P) aptb2PFCMPEQ )              \
        X("pfcmpge",        2,              (P) aptb2PFCMPGE )              \
        X("pfcmpgt",        2,              (P) aptb2PFCMPGT )              \
        X("pfmax",          2,              (P) aptb2PFMAX )                \
        X("pfmin",          2,              (P) aptb2PFMIN )                \
        X("pfmul",          2,              (P) aptb2PFMUL )                \
        X("pfnacc",         2,              (P) aptb2PFNACC )               \
        X("pfpnacc",        2,              (P) aptb2PFPNACC )              \
        X("pfrcp",          2,              (P) aptb2PFRCP )                \
        X("pfrcpit1",       2,              (P) aptb2PFRCPIT1 )             \
        X("pfrcpit2",       2,              (P) aptb2PFRCPIT2 )             \
        X("pfrsqit1",       2,              (P) aptb2PFRSQIT1 )             \
        X("pfrsqrt",        2,              (P) aptb2PFRSQRT )              \
        X("pfsub",          2,              (P) aptb2PFSUB )                \
        X("pfsubr",         2,              (P) aptb2PFSUBR )               \
        X("phaddd",         2,              (P) aptb2PHADDD )               \
        X("phaddsw",        2,              (P) aptb2PHADDSW )              \
        X("phaddw",         2,              (P) aptb2PHADDW )               \
        X("phminposuw",     2,              (P) aptb2PHMINPOSUW )           \
        X("phsubd",         2,              (P) aptb2PHSUBD )               \
        X("phsubsw",        2,              (P) aptb2PHSUBSW )              \
        X("phsubw",         2,              (P) aptb2PHSUBW )               \
        X("pi2fd",          2,              (P) aptb2PI2FD )                \
        X("pinsrb",         3,              (P) aptb3PINSRB )               \
        X("pinsrd",         3,              (P) aptb3PINSRD )               \
        X("pinsrq",         3,              (P) aptb3PINSRQ )               \
        X("pinsrw",         3,              (P) aptb3PINSRW )               \
        X("pmaddubsw",      2,              (P) aptb2PMADDUBSW )            \
        X("pmaddwd",        2,              (P) aptb2PMADDWD )              \
        X("pmaxsb",         2,              (P) aptb2PMAXSB )               \
        X("pmaxsd",         2,              (P) aptb2PMAXSD )               \
        X("pmaxsw",         2,              (P) aptb2PMAXSW )               \
        X("pmaxub",         2,              (P) aptb2PMAXUB )               \
        X("pmaxud",         2,              (P) aptb2PMAXUD )               \
        X("pmaxuw",         2,              (P) aptb2PMAXUW )               \
        X("pminsb",         2,              (P) aptb2PMINSB )               \
        X("pminsd",         2,              (P) aptb2PMINSD )               \
        X("pminsw",         2,              (P) aptb2PMINSW )               \
        X("pminub",         2,              (P) aptb2PMINUB )               \
        X("pminud",         2,              (P) aptb2PMINUD )               \
        X("pminuw",         2,              (P) aptb2PMINUW )               \
        X("pmovmskb",       2,              (P) aptb2PMOVMSKB )             \
        X("pmovsxbd",       2,              (P) aptb2PMOVSXBD )             \
        X("pmovsxbq",       2,              (P) aptb2PMOVSXBQ )             \
        X("pmovsxbw",       2,              (P) aptb2PMOVSXBW )             \
        X("pmovsxdq",       2,              (P) aptb2PMOVSXDQ )             \
        X("pmovsxwd",       2,              (P) aptb2PMOVSXWD )             \
        X("pmovsxwq",       2,              (P) aptb2PMOVSXWQ )             \
        X("pmovzxbd",       2,              (P) aptb2PMOVZXBD )             \
        X("pmovzxbq",       2,              (P) aptb2PMOVZXBQ )             \
        X("pmovzxbw",       2,              (P) aptb2PMOVZXBW )             \
        X("pmovzxdq",       2,              (P) aptb2PMOVZXDQ )             \
        X("pmovzxwd",       2,              (P) aptb2PMOVZXWD )             \
        X("pmovzxwq",       2,              (P) aptb2PMOVZXWQ )             \
        X("pmuldq",         2,              (P) aptb2PMULDQ )               \
        X("pmulhrsw",       2,              (P) aptb2PMULHRSW )             \
        X("pmulhrw",        2,              (P) aptb2PMULHRW )              \
        X("pmulhuw",        2,              (P) aptb2PMULHUW )              \
        X("pmulhw",         2,              (P) aptb2PMULHW )               \
        X("pmulld",         2,              (P) aptb2PMULLD )               \
        X("pmullw",         2,              (P) aptb2PMULLW )               \
        X("pmuludq",        2,              (P) aptb2PMULUDQ )              \
        X("pop",            1,              (P) aptb1POP )                  \
        X("popa",           0,              aptb0POPA )                     \
        X("popad",          0,              aptb0POPAD )                    \
        X("popcnt",         2,              (P) aptb2POPCNT )               \
        X("popf",           0,              aptb0POPF )                     \
        X("popfd",          0,              aptb0POPFD )                    \
        X("popfq",          0,              aptb0POPFQ )                    \
        X("por",            2,              (P) aptb2POR )                  \
        X("prefetchnta",    1,              (P) aptb1PREFETCHNTA )          \
        X("prefetcht0",     1,              (P) aptb1PREFETCHT0 )           \
        X("prefetcht1",     1,              (P) aptb1PREFETCHT1 )           \
        X("prefetcht2",     1,              (P) aptb1PREFETCHT2 )           \
        X("prefetchw",      1,              (P) aptb1PREFETCHW )            \
        X("prefetchwt1",    1,              (P) aptb1PREFETCHWT1 )          \
        X("psadbw",         2,              (P) aptb2PSADBW )               \
        X("pshufb",         2,              (P) aptb2PSHUFB )               \
        X("pshufd",         3,              (P) aptb3PSHUFD )               \
        X("pshufhw",        3,              (P) aptb3PSHUFHW )              \
        X("pshuflw",        3,              (P) aptb3PSHUFLW )              \
        X("pshufw",         3,              (P) aptb3PSHUFW )               \
        X("psignb",         2,              (P) aptb2PSIGNB )               \
        X("psignd",         2,              (P) aptb2PSIGND )               \
        X("psignw",         2,              (P) aptb2PSIGNW )               \
        X("pslld",          2,              (P) aptb2PSLLD )                \
        X("pslldq",         2,              (P) aptb2PSLLDQ )               \
        X("psllq",          2,              (P) aptb2PSLLQ )                \
        X("psllw",          2,              (P) aptb2PSLLW )                \
        X("psrad",          2,              (P) aptb2PSRAD )                \
        X("psraw",          2,              (P) aptb2PSRAW )                \
        X("psrld",          2,              (P) aptb2PSRLD )                \
        X("psrldq",         2,              (P) aptb2PSRLDQ )               \
        X("psrlq",          2,              (P) aptb2PSRLQ )                \
        X("psrlw",          2,              (P) aptb2PSRLW )                \
        X("psubb",          2,              (P) aptb2PSUBB )                \
        X("psubd",          2,              (P) aptb2PSUBD )                \
        X("psubq",          2,              (P) aptb2PSUBQ )                \
        X("psubsb",         2,              (P) aptb2PSUBSB )               \
        X("psubsw",         2,              (P) aptb2PSUBSW )               \
        X("psubusb",        2,              (P) aptb2PSUBUSB )              \
        X("psubusw",        2,              (P) aptb2PSUBUSW )              \
        X("psubw",          2,              (P) aptb2PSUBW )                \
        X("pswapd",         2,              (P) aptb2PSWAPD )               \
        X("ptest",          2,              (P) aptb2PTEST )                \
        X("punpckhbw",      2,              (P) aptb2PUNPCKHBW )            \
        X("punpckhdq",      2,              (P) aptb2PUNPCKHDQ )            \
        X("punpckhqdq",     2,              (P) aptb2PUNPCKHQDQ )           \
        X("punpckhwd",      2,              (P) aptb2PUNPCKHWD )            \
        X("punpcklbw",      2,              (P) aptb2PUNPCKLBW )            \
        X("punpckldq",      2,              (P) aptb2PUNPCKLDQ )            \
        X("punpcklqdq",     2,              (P) aptb2PUNPCKLQDQ )           \
        X("punpcklwd",      2,              (P) aptb2PUNPCKLWD )            \
        X("push",           1,              (P) aptb1PUSH )                 \
        X("pusha",          0,              aptb0PUSHA )                    \
        X("pushad",         0,              aptb0PUSHAD )                   \
        X("pushf",          0,              aptb0PUSHF )                    \
        X("pushfd",         0,              aptb0PUSHFD )                   \
        X("pushfq",         0,              aptb0PUSHFQ )                   \
        X("pxor",           2,              (P) aptb2PXOR )                 \
        X("rcl",            ITshift | 2,    (P) aptb2RCL )                  \
        X("rcpps",          2,              (P) aptb2RCPPS )                \
        X("rcpss",          2,              (P) aptb2RCPSS )                \
        X("rcr",            ITshift | 2,    (P) aptb2RCR )                  \
        X("rdfsbase",       1,              (P) aptb1RDFSBASE )             \
        X("rdgsbase",       1,              (P) aptb1RDGSBASE )             \
        X("rdmsr",          0,              aptb0RDMSR )                    \
        X("rdpmc",          0,              aptb0RDPMC )                    \
        X("rdrand",         1,              (P) aptb1RDRAND )               \
        X("rdtsc",          0,              aptb0RDTSC )                    \
        X("rdtscp",         0,              aptb0RDTSCP )                   \
        X("rep",            ITprefix | 0,   aptb0REP )                      \
        X("repe",           ITprefix | 0,   aptb0REP )                      \
        X("repne",          ITprefix | 0,   aptb0REPNE )                    \
        X("repnz",          ITprefix | 0,   aptb0REPNE )                    \
        X("repz",           ITprefix | 0,   aptb0REP )                      \
        X("ret",            ITopt | 1,      (P) aptb1RET )                  \
        X("retf",           ITopt | 1,      (P) aptb1RETF )                 \
        X("rol",            ITshift | 2,    (P) aptb2ROL )                  \
        X("ror",            ITshift | 2,    (P) aptb2ROR )                  \
        X("roundpd",        3,              (P) aptb3ROUNDPD )              \
        X("roundps",        3,              (P) aptb3ROUNDPS )              \
        X("roundsd",        3,              (P) aptb3ROUNDSD )              \
        X("roundss",        3,              (P) aptb3ROUNDSS )              \
        X("rsm",            0,              aptb0RSM )                      \
        X("rsqrtps",        2,              (P) aptb2RSQRTPS )              \
        X("rsqrtss",        2,              (P) aptb2RSQRTSS )              \
        X("sahf",           0,              aptb0SAHF )                     \
        X("sal",            ITshift | 2,    (P) aptb2SHL )                  \
        X("sar",            ITshift | 2,    (P) aptb2SAR )                  \
        X("sbb",            2,              (P) aptb2SBB )                  \
        X("scas",           1,              (P) aptb1SCAS )                 \
        X("scasb",          0,              aptb0SCASB )                    \
        X("scasd",          0,              aptb0SCASD )                    \
        X("scasq",          0,              aptb0SCASQ )                    \
        X("scasw",          0,              aptb0SCASW )                    \
        X("seta",           1,              (P) aptb1SETNBE )               \
        X("setae",          1,              (P) aptb1SETNB )                \
        X("setb",           1,              (P) aptb1SETB )                 \
        X("setbe",          1,              (P) aptb1SETBE )                \
        X("setc",           1,              (P) aptb1SETB )                 \
        X("sete",           1,              (P) aptb1SETZ )                 \
        X("setg",           1,              (P) aptb1SETNLE )               \
        X("setge",          1,              (P) aptb1SETNL )                \
        X("setl",           1,              (P) aptb1SETL )                 \
        X("setle",          1,              (P) aptb1SETLE )                \
        X("setna",          1,              (P) aptb1SETBE )                \
        X("setnae",         1,              (P) aptb1SETB )                 \
        X("setnb",          1,              (P) aptb1SETNB )                \
        X("setnbe",         1,              (P) aptb1SETNBE )               \
        X("setnc",          1,              (P) aptb1SETNB )                \
        X("setne",          1,              (P) aptb1SETNZ )                \
        X("setng",          1,              (P) aptb1SETLE )                \
        X("setnge",         1,              (P) aptb1SETL )                 \
        X("setnl",          1,              (P) aptb1SETNL )                \
        X("setnle",         1,              (P) aptb1SETNLE )               \
        X("setno",          1,              (P) aptb1SETNO )                \
        X("setnp",          1,              (P) aptb1SETNP )                \
        X("setns",          1,              (P) aptb1SETNS )                \
        X("setnz",          1,              (P) aptb1SETNZ )                \
        X("seto",           1,              (P) aptb1SETO )                 \
        X("setp",           1,              (P) aptb1SETP )                 \
        X("setpe",          1,              (P) aptb1SETP )                 \
        X("setpo",          1,              (P) aptb1SETNP )                \
        X("sets",           1,              (P) aptb1SETS )                 \
        X("setz",           1,              (P) aptb1SETZ )                 \
        X("sfence",         0,              aptb0SFENCE)                    \
        X("sgdt",           1,              (P) aptb1SGDT )                 \
        X("sha1msg1",       2,              (P) aptb2SHA1MSG1 )             \
        X("sha1msg2",       2,              (P) aptb2SHA1MSG2 )             \
        X("sha1nexte",      2,              (P) aptb2SHA1NEXTE )            \
        X("sha1rnds4",      3,              (P) aptb3SHA1RNDS4 )            \
        X("sha256msg1",     2,              (P) aptb2SHA256MSG1 )           \
        X("sha256msg2",     2,              (P) aptb2SHA256MSG2 )           \
        X("sha256rnds2",    2,              (P) aptb2SHA256RNDS2 )          \
        X("shl",            ITshift | 2,    (P) aptb2SHL )                  \
        X("shld",           3,              (P) aptb3SHLD )                 \
        X("shr",            ITshift | 2,    (P) aptb2SHR )                  \
        X("shrd",           3,              (P) aptb3SHRD )                 \
        X("shufpd",         3,              (P) aptb3SHUFPD )               \
        X("shufps",         3,              (P) aptb3SHUFPS )               \
        X("sidt",           1,              (P) aptb1SIDT )                 \
        X("sldt",           1,              (P) aptb1SLDT )                 \
        X("smsw",           1,              (P) aptb1SMSW )                 \
        X("sqrtpd",         2,              (P) aptb2SQRTPD )               \
        X("sqrtps",         2,              (P) aptb2SQRTPS )               \
        X("sqrtsd",         2,              (P) aptb2SQRTSD )               \
        X("sqrtss",         2,              (P) aptb2SQRTSS )               \
        X("stc",            0,              aptb0STC )                      \
        X("std",            0,              aptb0STD )                      \
        X("sti",            0,              aptb0STI )                      \
        X("stmxcsr",        1,              (P) aptb1STMXCSR )              \
        X("stos",           1,              (P) aptb1STOS )                 \
        X("stosb",          0,              aptb0STOSB )                    \
        X("stosd",          0,              aptb0STOSD )                    \
        X("stosq",          0,              aptb0STOSQ )                    \
        X("stosw",          0,              aptb0STOSW )                    \
        X("str",            1,              (P) aptb1STR )                  \
        X("sub",            2,              (P) aptb2SUB )                  \
        X("subpd",          2,              (P) aptb2SUBPD )                \
        X("subps",          2,              (P) aptb2SUBPS )                \
        X("subsd",          2,              (P) aptb2SUBSD )                \
        X("subss",          2,              (P) aptb2SUBSS )                \
        X("syscall",        0,              aptb0SYSCALL )                  \
        X("sysenter",       0,              aptb0SYSENTER )                 \
        X("sysexit",        0,              aptb0SYSEXIT )                  \
        X("sysret",         0,              aptb0SYSRET )                   \
        X("test",           2,              (P) aptb2TEST )                 \
        X("ucomisd",        2,              (P) aptb2UCOMISD )              \
        X("ucomiss",        2,              (P) aptb2UCOMISS )              \
        X("ud2",            0,              aptb0UD2 )                      \
        X("unpckhpd",       2,              (P) aptb2UNPCKHPD )             \
        X("unpckhps",       2,              (P) aptb2UNPCKHPS )             \
        X("unpcklpd",       2,              (P) aptb2UNPCKLPD )             \
        X("unpcklps",       2,              (P) aptb2UNPCKLPS )             \


#define OPCODETABLE3 \
        X("vaddpd",         3,              (P) aptb3VADDPD )               \
        X("vaddps",         3,              (P) aptb3VADDPS )               \
        X("vaddsd",         3,              (P) aptb3VADDSD )               \
        X("vaddss",         3,              (P) aptb3VADDSS )               \
        X("vaddsubpd",      3,              (P) aptb3VADDSUBPD )            \
        X("vaddsubps",      3,              (P) aptb3VADDSUBPS )            \
        X("vaesdec",        3,              (P) aptb3VAESDEC )              \
        X("vaesdeclast",    3,              (P) aptb3VAESDECLAST )          \
        X("vaesenc",        3,              (P) aptb3VAESENC )              \
        X("vaesenclast",    3,              (P) aptb3VAESENCLAST )          \
        X("vaesimc",        2,              (P) aptb2VAESIMC )              \
        X("vaeskeygenassist", 3,            (P) aptb3VAESKEYGENASSIST )     \
        X("vandnpd",        3,              (P) aptb3VANDNPD )              \
        X("vandnps",        3,              (P) aptb3VANDNPS )              \
        X("vandpd",         3,              (P) aptb3VANDPD )               \
        X("vandps",         3,              (P) aptb3VANDPS )               \
        X("vblendpd",       4,              (P) aptb4VBLENDPD )             \
        X("vblendps",       4,              (P) aptb4VBLENDPS )             \
        X("vblendvpd",      4,              (P) aptb4VBLENDVPD )            \
        X("vblendvps",      4,              (P) aptb4VBLENDVPS )            \
        X("vbroadcastf128", 2,              (P) aptb2VBROADCASTF128 )       \
        X("vbroadcastsd",   2,              (P) aptb2VBROADCASTSD )         \
        X("vbroadcastss",   2,              (P) aptb2VBROADCASTSS )         \
        X("vcmppd",         4,              (P) aptb4VCMPPD )               \
        X("vcmpps",         4,              (P) aptb4VCMPPS )               \
        X("vcmpsd",         4,              (P) aptb4VCMPSD )               \
        X("vcmpss",         4,              (P) aptb4VCMPSS )               \
        X("vcomisd",        2,              (P) aptb2VCOMISD )              \
        X("vcomiss",        2,              (P) aptb2VCOMISS )              \
        X("vcvtdq2pd",      2,              (P) aptb2VCVTDQ2PD )            \
        X("vcvtdq2ps",      2,              (P) aptb2VCVTDQ2PS )            \
        X("vcvtpd2dq",      2,              (P) aptb2VCVTPD2DQ )            \
        X("vcvtpd2ps",      2,              (P) aptb2VCVTPD2PS )            \
        X("vcvtph2ps",      2,              (P) aptb2VCVTPH2PS )            \
        X("vcvtps2dq",      2,              (P) aptb2VCVTPS2DQ )            \
        X("vcvtps2pd",      2,              (P) aptb2VCVTPS2PD )            \
        X("vcvtps2ph",      3,              (P) aptb3VCVTPS2PH )            \
        X("vcvtsd2si",      2,              (P) aptb2VCVTSD2SI )            \
        X("vcvtsd2ss",      3,              (P) aptb3VCVTSD2SS )            \
        X("vcvtsi2sd",      3,              (P) aptb3VCVTSI2SD )            \
        X("vcvtsi2ss",      3,              (P) aptb3VCVTSI2SS )            \
        X("vcvtss2sd",      3,              (P) aptb3VCVTSS2SD )            \
        X("vcvtss2si",      2,              (P) aptb2VCVTSS2SI )            \
        X("vcvttpd2dq",     2,              (P) aptb2VCVTTPD2DQ )           \
        X("vcvttps2dq",     2,              (P) aptb2VCVTTPS2DQ )           \
        X("vcvttsd2si",     2,              (P) aptb2VCVTTSD2SI )           \
        X("vcvttss2si",     2,              (P) aptb2VCVTTSS2SI )           \
        X("vdivpd",         3,              (P) aptb3VDIVPD )               \
        X("vdivps",         3,              (P) aptb3VDIVPS )               \
        X("vdivsd",         3,              (P) aptb3VDIVSD )               \
        X("vdivss",         3,              (P) aptb3VDIVSS )               \
        X("vdppd",          4,              (P) aptb4VDPPD )                \
        X("vdpps",          4,              (P) aptb4VDPPS )                \
        X("verr",           1,              (P) aptb1VERR )                 \
        X("verw",           1,              (P) aptb1VERW )                 \
        X("vextractf128",   3,              (P) aptb3VEXTRACTF128 )         \
        X("vextractps",     3,              (P) aptb3VEXTRACTPS )           \
        X("vfmadd132pd",    3,              (P) aptb3VFMADD132PD )          \
        X("vfmadd132ps",    3,              (P) aptb3VFMADD132PS )          \
        X("vfmadd132sd",    3,              (P) aptb3VFMADD132SD )          \
        X("vfmadd132ss",    3,              (P) aptb3VFMADD132SS )          \
        X("vfmadd213pd",    3,              (P) aptb3VFMADD213PD )          \
        X("vfmadd213ps",    3,              (P) aptb3VFMADD213PS )          \
        X("vfmadd213sd",    3,              (P) aptb3VFMADD213SD )          \
        X("vfmadd213ss",    3,              (P) aptb3VFMADD213SS )          \
        X("vfmadd231pd",    3,              (P) aptb3VFMADD231PD )          \
        X("vfmadd231ps",    3,              (P) aptb3VFMADD231PS )          \
        X("vfmadd231sd",    3,              (P) aptb3VFMADD231SD )          \
        X("vfmadd231ss",    3,              (P) aptb3VFMADD231SS )          \
        X("vfmaddsub132pd", 3,              (P) aptb3VFMADDSUB132PD )       \
        X("vfmaddsub132ps", 3,              (P) aptb3VFMADDSUB132PS )       \
        X("vfmaddsub213pd", 3,              (P) aptb3VFMADDSUB213PD )       \
        X("vfmaddsub213ps", 3,              (P) aptb3VFMADDSUB213PS )       \
        X("vfmaddsub231pd", 3,              (P) aptb3VFMADDSUB231PD )       \
        X("vfmaddsub231ps", 3,              (P) aptb3VFMADDSUB231PS )       \
        X("vfmsub132pd",    3,              (P) aptb3VFMSUB132PD )          \
        X("vfmsub132ps",    3,              (P) aptb3VFMSUB132PS )          \
        X("vfmsub132sd",    3,              (P) aptb3VFMSUB132SD )          \
        X("vfmsub132ss",    3,              (P) aptb3VFMSUB132SS )          \
        X("vfmsub213pd",    3,              (P) aptb3VFMSUB213PD )          \
        X("vfmsub213ps",    3,              (P) aptb3VFMSUB213PS )          \
        X("vfmsub213sd",    3,              (P) aptb3VFMSUB213SD )          \
        X("vfmsub213ss",    3,              (P) aptb3VFMSUB213SS )          \
        X("vfmsub231pd",    3,              (P) aptb3VFMSUB231PD )          \
        X("vfmsub231ps",    3,              (P) aptb3VFMSUB231PS )          \
        X("vfmsub231sd",    3,              (P) aptb3VFMSUB231SD )          \
        X("vfmsub231ss",    3,              (P) aptb3VFMSUB231SS )          \
        X("vfmsubadd132pd", 3,              (P) aptb3VFMSUBADD132PD )       \
        X("vfmsubadd132ps", 3,              (P) aptb3VFMSUBADD132PS )       \
        X("vfmsubadd213pd", 3,              (P) aptb3VFMSUBADD213PD )       \
        X("vfmsubadd213ps", 3,              (P) aptb3VFMSUBADD213PS )       \
        X("vfmsubadd231pd", 3,              (P) aptb3VFMSUBADD231PD )       \
        X("vfmsubadd231ps", 3,              (P) aptb3VFMSUBADD231PS )       \
        X("vhaddpd",        3,              (P) aptb3VHADDPD )              \
        X("vhaddps",        3,              (P) aptb3VHADDPS )              \
        X("vinsertf128",    4,              (P) aptb4VINSERTF128 )          \
        X("vinsertps",      4,              (P) aptb4VINSERTPS )            \
        X("vlddqu",         2,              (P) aptb2VLDDQU )               \
        X("vldmxcsr",       1,              (P) aptb1VLDMXCSR )             \
        X("vmaskmovdqu",    2,              (P) aptb2VMASKMOVDQU )          \
        X("vmaskmovpd",     3,              (P) aptb3VMASKMOVPD )           \
        X("vmaskmovps",     3,              (P) aptb3VMASKMOVPS )           \
        X("vmaxpd",         3,              (P) aptb3VMAXPD )               \
        X("vmaxps",         3,              (P) aptb3VMAXPS )               \
        X("vmaxsd",         3,              (P) aptb3VMAXSD )               \
        X("vmaxss",         3,              (P) aptb3VMAXSS )               \
        X("vminpd",         3,              (P) aptb3VMINPD )               \
        X("vminps",         3,              (P) aptb3VMINPS )               \
        X("vminsd",         3,              (P) aptb3VMINSD )               \
        X("vminss",         3,              (P) aptb3VMINSS )               \
        X("vmovapd",        2,              (P) aptb2VMOVAPD )              \
        X("vmovaps",        2,              (P) aptb2VMOVAPS )              \
        X("vmovd",          2,              (P) aptb2VMOVD )                \
        X("vmovddup",       2,              (P) aptb2VMOVDDUP )             \
        X("vmovdqa",        2,              (P) aptb2VMOVDQA )              \
        X("vmovdqu",        2,              (P) aptb2VMOVDQU )              \
        X("vmovhlps",       3,              (P) aptb3VMOVLHPS )             \
        X("vmovhpd",        ITopt | 3,      (P) aptb3VMOVHPD )              \
        X("vmovhps",        ITopt | 3,      (P) aptb3VMOVHPS )              \
        X("vmovlhps",       3,              (P) aptb3VMOVHLPS )             \
        X("vmovlpd",        ITopt | 3,      (P) aptb3VMOVLPD )              \
        X("vmovlps",        ITopt | 3,      (P) aptb3VMOVLPS )              \
        X("vmovmskpd",      2,              (P) aptb2VMOVMSKPD )            \
        X("vmovmskps",      2,              (P) aptb2VMOVMSKPS )            \
        X("vmovntdq",       2,              (P) aptb2VMOVNTDQ )             \
        X("vmovntdqa",      2,              (P) aptb2VMOVNTDQA )            \
        X("vmovntpd",       2,              (P) aptb2VMOVNTPD )             \
        X("vmovntps",       2,              (P) aptb2VMOVNTPS )             \
        X("vmovq",          2,              (P) aptb2VMOVQ )                \
        X("vmovsd",         ITopt | 3,      (P) aptb3VMOVSD )               \
        X("vmovshdup",      2,              (P) aptb2VMOVSHDUP )            \
        X("vmovsldup",      2,              (P) aptb2VMOVSLDUP )            \
        X("vmovss",         ITopt | 3,      (P) aptb3VMOVSS )               \
        X("vmovupd",        2,              (P) aptb2VMOVUPD )              \
        X("vmovups",        2,              (P) aptb2VMOVUPS )              \
        X("vmpsadbw",       4,              (P) aptb4VMPSADBW )             \
        X("vmulpd",         3,              (P) aptb3VMULPD )               \
        X("vmulps",         3,              (P) aptb3VMULPS )               \
        X("vmulsd",         3,              (P) aptb3VMULSD )               \
        X("vmulss",         3,              (P) aptb3VMULSS )               \
        X("vorpd",          3,              (P) aptb3VORPD )                \
        X("vorps",          3,              (P) aptb3VORPS )                \
        X("vpabsb",         2,              (P) aptb2VPABSB )               \
        X("vpabsd",         2,              (P) aptb2VPABSD )               \
        X("vpabsw",         2,              (P) aptb2VPABSW )               \
        X("vpackssdw",      3,              (P) aptb3VPACKSSDW )            \
        X("vpacksswb",      3,              (P) aptb3VPACKSSWB )            \
        X("vpackusdw",      3,              (P) aptb3VPACKUSDW )            \
        X("vpackuswb",      3,              (P) aptb3VPACKUSWB )            \
        X("vpaddb",         3,              (P) aptb3VPADDB )               \
        X("vpaddd",         3,              (P) aptb3VPADDD )               \
        X("vpaddq",         3,              (P) aptb3VPADDQ )               \
        X("vpaddsb",        3,              (P) aptb3VPADDSB )              \
        X("vpaddsw",        3,              (P) aptb3VPADDSW )              \
        X("vpaddusb",       3,              (P) aptb3VPADDUSB )             \
        X("vpaddusw",       3,              (P) aptb3VPADDUSW )             \
        X("vpaddw",         3,              (P) aptb3VPADDW )               \
        X("vpalignr",       4,              (P) aptb4VPALIGNR )             \
        X("vpand",          3,              (P) aptb3VPAND )               \
        X("vpandn",         3,              (P) aptb3VPANDN )               \
        X("vpavgb",         3,              (P) aptb3VPAVGB )               \
        X("vpavgw",         3,              (P) aptb3VPAVGW )               \
        X("vpblendvb",      4,              (P) aptb4VPBLENDVB )            \
        X("vpblendw",       4,              (P) aptb4VPBLENDW )             \
        X("vpclmulqdq",     4,              (P) aptb4VPCLMULQDQ )           \
        X("vpcmpeqb",       3,              (P) aptb3VPCMPEQB )             \
        X("vpcmpeqd",       3,              (P) aptb3VPCMPEQD )             \
        X("vpcmpeqq",       3,              (P) aptb3VPCMPEQQ )             \
        X("vpcmpeqw",       3,              (P) aptb3VPCMPEQW )             \
        X("vpcmpestri",     3,              (P) aptb3VPCMPESTRI )           \
        X("vpcmpestrm",     3,              (P) aptb3VPCMPESTRM )           \
        X("vpcmpgtb",       3,              (P) aptb3VPCMPGTB )             \
        X("vpcmpgtd",       3,              (P) aptb3VPCMPGTD )             \
        X("vpcmpgtq",       3,              (P) aptb3VPCMPGTQ )             \
        X("vpcmpgtw",       3,              (P) aptb3VPCMPGTW )             \
        X("vpcmpistri",     3,              (P) aptb3VPCMPISTRI )           \
        X("vpcmpistrm",     3,              (P) aptb3VPCMPISTRM )           \
        X("vperm2f128",     4,              (P) aptb3VPERM2F128 )           \
        X("vpermilpd",      3,              (P) aptb3VPERMILPD )            \
        X("vpermilps",      3,              (P) aptb3VPERMILPS )            \
        X("vpextrb",        3,              (P) aptb3VPEXTRB )              \
        X("vpextrd",        3,              (P) aptb3VPEXTRD )              \
        X("vpextrq",        3,              (P) aptb3VPEXTRQ )              \
        X("vpextrw",        3,              (P) aptb3VPEXTRW )              \
        X("vphaddd",        3,              (P) aptb3VPHADDD )              \
        X("vphaddsw",       3,              (P) aptb3VPHADDSW )             \
        X("vphaddw",        3,              (P) aptb3VPHADDW )              \
        X("vphminposuw",    2,              (P) aptb2VPHMINPOSUW )          \
        X("vphsubd",        3,              (P) aptb3VPHSUBD )              \
        X("vphsubsw",       3,              (P) aptb3VPHSUBSW )             \
        X("vphsubw",        3,              (P) aptb3VPHSUBW )              \
        X("vpinsrb",        4,              (P) aptb4VPINSRB )              \
        X("vpinsrd",        4,              (P) aptb4VPINSRD )              \
        X("vpinsrq",        4,              (P) aptb4VPINSRQ )              \
        X("vpinsrw",        4,              (P) aptb4VPINSRW )              \
        X("vpmaddubsw",     3,              (P) aptb3VPMADDUBSW )           \
        X("vpmaddwd",       3,              (P) aptb3VPMADDWD )             \
        X("vpmaxsb",        3,              (P) aptb3VPMAXSB )              \
        X("vpmaxsd",        3,              (P) aptb3VPMAXSD )              \
        X("vpmaxsw",        3,              (P) aptb3VPMAXSW )              \
        X("vpmaxub",        3,              (P) aptb3VPMAXUB )              \
        X("vpmaxud",        3,              (P) aptb3VPMAXUD )              \
        X("vpmaxuw",        3,              (P) aptb3VPMAXUW )              \
        X("vpminsb",        3,              (P) aptb3VPMINSB )              \
        X("vpminsd",        3,              (P) aptb3VPMINSD )              \
        X("vpminsw",        3,              (P) aptb3VPMINSW )              \
        X("vpminub",        3,              (P) aptb3VPMINUB )              \
        X("vpminud",        3,              (P) aptb3VPMINUD )              \
        X("vpminuw",        3,              (P) aptb3VPMINUW )              \
        X("vpmovmskb",      2,              (P) aptb2VPMOVMSKB )            \
        X("vpmovsxbd",      2,              (P) aptb2VPMOVSXBD )            \
        X("vpmovsxbq",      2,              (P) aptb2VPMOVSXBQ )            \
        X("vpmovsxbw",      2,              (P) aptb2VPMOVSXBW )            \
        X("vpmovsxdq",      2,              (P) aptb2VPMOVSXDQ )            \
        X("vpmovsxwd",      2,              (P) aptb2VPMOVSXWD )            \
        X("vpmovsxwq",      2,              (P) aptb2VPMOVSXWQ )            \
        X("vpmovzxbd",      2,              (P) aptb2VPMOVZXBD )            \
        X("vpmovzxbq",      2,              (P) aptb2VPMOVZXBQ )            \
        X("vpmovzxbw",      2,              (P) aptb2VPMOVZXBW )            \
        X("vpmovzxdq",      2,              (P) aptb2VPMOVZXDQ )            \
        X("vpmovzxwd",      2,              (P) aptb2VPMOVZXWD )            \
        X("vpmovzxwq",      2,              (P) aptb2VPMOVZXWQ )            \
        X("vpmuldq",        3,              (P) aptb3VPMULDQ )              \
        X("vpmulhrsw",      3,              (P) aptb3VPMULHRSW )            \
        X("vpmulhuw",       3,              (P) aptb3VPMULHUW )             \
        X("vpmulhw",        3,              (P) aptb3VPMULHW )              \
        X("vpmulld",        3,              (P) aptb3VPMULLD )              \
        X("vpmullw",        3,              (P) aptb3VPMULLW )              \
        X("vpmuludq",       3,              (P) aptb3VPMULUDQ )             \
        X("vpor",           3,              (P) aptb3VPOR )                 \
        X("vpsadbw",        3,              (P) aptb3VPSADBW )              \
        X("vpshufb",        3,              (P) aptb3VPSHUFB )              \
        X("vpshufd",        3,              (P) aptb3VPSHUFD )              \
        X("vpshufhw",       3,              (P) aptb3VPSHUFHW )             \
        X("vpshuflw",       3,              (P) aptb3VPSHUFLW )              \
        X("vpsignb",        3,              (P) aptb3VPSIGNB )              \
        X("vpsignd",        3,              (P) aptb3VPSIGND )              \
        X("vpsignw",        3,              (P) aptb3VPSIGNW )              \
        X("vpslld",         3,              (P) aptb3VPSLLD )               \
        X("vpslldq",        3,              (P) aptb3VPSLLDQ )              \
        X("vpsllq",         3,              (P) aptb3VPSLLQ )               \
        X("vpsllw",         3,              (P) aptb3VPSLLW )               \
        X("vpsrad",         3,              (P) aptb3VPSRAD )               \
        X("vpsraw",         3,              (P) aptb3VPSRAW )               \
        X("vpsrld",         3,              (P) aptb3VPSRLD )               \
        X("vpsrldq",        3,              (P) aptb3VPSRLDQ )              \
        X("vpsrlq",         3,              (P) aptb3VPSRLQ )               \
        X("vpsrlw",         3,              (P) aptb3VPSRLW )               \
        X("vpsubb",         3,              (P) aptb3VPSUBB )               \
        X("vpsubd",         3,              (P) aptb3VPSUBD )               \
        X("vpsubq",         3,              (P) aptb3VPSUBQ )               \
        X("vpsubsb",        3,              (P) aptb3VPSUBSB )              \
        X("vpsubsw",        3,              (P) aptb3VPSUBSW )              \
        X("vpsubusb",       3,              (P) aptb3VPSUBUSB )             \
        X("vpsubusw",       3,              (P) aptb3VPSUBUSW )             \
        X("vpsubw",         3,              (P) aptb3VPSUBW )               \
        X("vptest",         2,              (P) aptb2VPTEST )               \
        X("vpunpckhbw",     3,              (P) aptb3VPUNPCKHBW )           \
        X("vpunpckhdq",     3,              (P) aptb3VPUNPCKHDQ )           \
        X("vpunpckhqdq",    3,              (P) aptb3VPUNPCKHQDQ )          \
        X("vpunpckhwd",     3,              (P) aptb3VPUNPCKHWD )           \
        X("vpunpcklbw",     3,              (P) aptb3VPUNPCKLBW )           \
        X("vpunpckldq",     3,              (P) aptb3VPUNPCKLDQ )           \
        X("vpunpcklqdq",    3,              (P) aptb3VPUNPCKLQDQ )          \
        X("vpunpcklwd",     3,              (P) aptb3VPUNPCKLWD )           \
        X("vpxor",          3,              (P) aptb3VPXOR )                \
        X("vrcpps",         2,              (P) aptb2VRCPPS )               \
        X("vrcpss",         3,              (P) aptb3VRCPSS )               \
        X("vroundpd",       3,              (P) aptb3VROUNDPD )             \
        X("vroundps",       3,              (P) aptb3VROUNDPS )             \
        X("vroundsd",       4,              (P) aptb4VROUNDSD )             \
        X("vroundss",       4,              (P) aptb4VROUNDSS )             \
        X("vshufpd",        4,              (P) aptb4VSHUFPD )              \
        X("vshufps",        4,              (P) aptb4VSHUFPS )              \
        X("vsqrtpd",        2,              (P) aptb2VSQRTPD )              \
        X("vsqrtps",        2,              (P) aptb2VSQRTPS )              \
        X("vsqrtsd",        3,              (P) aptb3VSQRTSD )              \
        X("vsqrtss",        3,              (P) aptb3VSQRTSS )              \
        X("vstmxcsr",       1,              (P) aptb1VSTMXCSR )             \
        X("vsubpd",         3,              (P) aptb3VSUBPD )               \
        X("vsubps",         3,              (P) aptb3VSUBPS )               \
        X("vsubsd",         3,              (P) aptb3VSUBSD )               \
        X("vsubss",         3,              (P) aptb3VSUBSS )               \
        X("vucomisd",       2,              (P) aptb2VUCOMISD )             \
        X("vucomiss",       2,              (P) aptb2VUCOMISS )             \
        X("vunpckhpd",      3,              (P) aptb3VUNPCKHPD )            \
        X("vunpckhps",      3,              (P) aptb3VUNPCKHPS )            \
        X("vunpcklpd",      3,              (P) aptb3VUNPCKLPD )            \
        X("vunpcklps",      3,              (P) aptb3VUNPCKLPS )            \
        X("vxorpd",         3,              (P) aptb3VXORPD )               \
        X("vxorps",         3,              (P) aptb3VXORPS )               \
        X("vzeroall",       0,              aptb0VZEROALL )                 \
        X("vzeroupper",     0,              aptb0VZEROUPPER )               \
        X("wait",           0,              aptb0WAIT )                     \
        X("wbinvd",         0,              aptb0WBINVD )                   \
        X("wrfsbase",       1,              (P) aptb1WRFSBASE )             \
        X("wrgsbase",       1,              (P) aptb1WRGSBASE )             \
        X("wrmsr",          0,              aptb0WRMSR )                    \
        X("xadd",           2,              (P) aptb2XADD )                 \
        X("xchg",           2,              (P) aptb2XCHG )                 \
        X("xgetbv",         0,              aptb0XGETBV)                    \
        X("xlat",           ITopt | 1,      (P) aptb1XLAT )                 \
        X("xlatb",          0,              aptb0XLATB )                    \
        X("xor",            2,              (P) aptb2XOR )                  \
        X("xorpd",          2,              (P) aptb2XORPD )                \
        X("xorps",          2,              (P) aptb2XORPS )                \
        X("xrstor",         ITfloat | 1,    (P) aptb1XRSTOR )               \
        X("xrstor64",       ITfloat | 1,    (P) aptb1XRSTOR64 )             \
        X("xsave",          ITfloat | 1,    (P) aptb1XSAVE )                \
        X("xsave64",        ITfloat | 1,    (P) aptb1XSAVE64 )              \
        X("xsaveopt",       ITfloat | 1,    (P) aptb1XSAVEOPT )             \
        X("xsaveopt64",     ITfloat | 1,    (P) aptb1XSAVEOPT64 )           \
        X("xsetbv",         0,              aptb0XSETBV)                    \

#endif

static const char *opcodestr[] =
{
    #define X(a,b,c)    a,
        OPCODETABLE1
        OPCODETABLE2
        OPCODETABLE3
    #undef X
};

static OP optab[] =
{
    #define X(a,b,c)    b,c,
        OPCODETABLE1
        OPCODETABLE2
        OPCODETABLE3
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
    int i;
    char szBuf[20];

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
