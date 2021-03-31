/**
 * Instruction tables for inline assembler.
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/ptrntab.d, backend/ptrntab.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_ptrntab.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/ptrntab.d
 */

module dmd.backend.ptrntab;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.stdio;
import core.stdc.string;

version (SCPP) extern (C) char* strlwr(return char* s);

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code_x86;
import dmd.backend.iasm;
import dmd.backend.oper;
import dmd.backend.code;
import dmd.backend.global;
import dmd.backend.xmm;

import dmd.backend.cdef;
import dmd.backend.dlist;
import dmd.backend.ty;

nothrow:
@safe:

//
// NOTE: For 0 operand instructions, the opcode is taken from
// the first entry and no subsequent entries are required.
// for instructions with operands, a NULL entry is required at the end
// as a terminator
//
// 0 Operand instructions
//

immutable
{

template OPTABLE0(opcode_t op, opflag_t mod)
{
    immutable PTRNTAB0[1] OPTABLE0 = [ { op, mod }, ];
}

alias aptb0AAA = OPTABLE0!(     0x37  ,_i64_bit | _modax);
alias aptb0AAD = OPTABLE0!(     0xd50a,_i64_bit | _modax);
alias aptb0AAM = OPTABLE0!(     0xd40a,_i64_bit | _modax);
alias aptb0AAS = OPTABLE0!(     0x3f,  _i64_bit | _modax);
alias aptb0CBW = OPTABLE0!(     0x98,_16_bit | _modax);
alias aptb0CWDE = OPTABLE0!(    0x98,_32_bit | _I386 | _modax);
alias aptb0CDQE = OPTABLE0!(    0x98,_64_bit | _modax);
alias aptb0CLC = OPTABLE0!(     0xf8,0);
alias aptb0CLD = OPTABLE0!(     0xfc,0);
alias aptb0CLI = OPTABLE0!(     0xfa,0);
alias aptb0CLTS = OPTABLE0!(    0x0f06,0);
alias aptb0CMC = OPTABLE0!(     0xf5,0);
alias aptb0CMPSB = OPTABLE0!(   0xa6,_modsidi);
alias aptb0CMPSW = OPTABLE0!(   0xa7,_16_bit | _modsidi);
//alias aptb0CMPSD = OPTABLE0!( 0xa7,_32_bit | _I386 | _modsidi);
alias aptb0CMPSQ = OPTABLE0!(   0xa7,_64_bit | _modsidi);
alias aptb0CWD = OPTABLE0!(     0x99, _16_bit | _modaxdx);
alias aptb0CDQ = OPTABLE0!(     0x99,_32_bit | _I386 | _modaxdx);
alias aptb0CQO = OPTABLE0!(     0x99, _64_bit | _modaxdx);
alias aptb0DAA = OPTABLE0!(     0x27,_i64_bit | _modax );
alias aptb0DAS = OPTABLE0!(     0x2f,_i64_bit | _modax );
alias aptb0HLT = OPTABLE0!(     0xf4,0);
alias aptb0INSB = OPTABLE0!(    0x6c,_I386 | _modsi);
alias aptb0INSW = OPTABLE0!(    0x6d,_16_bit | _I386 | _modsi);
alias aptb0INSD = OPTABLE0!(    0x6d,_32_bit | _I386 | _modsi);
alias aptb0INTO = OPTABLE0!(    0xce,_i64_bit);
alias aptb0INVD = OPTABLE0!(    0x0f08,_I386);               // Actually a 486 only instruction
alias aptb0IRET = OPTABLE0!(    0xcf,_16_bit);
alias aptb0IRETD = OPTABLE0!(   0xcf,_32_bit | _I386);
alias aptb0IRETQ = OPTABLE0!(   0xcf,_64_bit | _I386);
alias aptb0LAHF = OPTABLE0!(    0x9f,_modax);
alias aptb0LEAVE = OPTABLE0!(   0xc9,_I386);
alias aptb0LOCK = OPTABLE0!(    0xf0,0);
alias aptb0LODSB = OPTABLE0!(   0xac,_modsiax);
alias aptb0LODSW = OPTABLE0!(   0xad,_16_bit | _modsiax);
alias aptb0LODSD = OPTABLE0!(   0xad,_32_bit | _I386 | _modsiax);
alias aptb0LODSQ = OPTABLE0!(   0xad,_64_bit | _modsiax);
alias aptb0MOVSB = OPTABLE0!(   0xa4, _modsidi);
alias aptb0MOVSW = OPTABLE0!(   0xa5, _16_bit | _modsidi);
alias aptb0MOVSQ = OPTABLE0!(   0xa5, _64_bit | _modsidi);
alias aptb0NOP = OPTABLE0!(     0x90, 0);
alias aptb0OUTSB = OPTABLE0!(   0x6e, _I386 | _modsi);
alias aptb0OUTSW = OPTABLE0!(   0x6f, _16_bit | _I386 | _modsi);
alias aptb0OUTSD = OPTABLE0!(   0x6f, _32_bit | _I386 | _modsi);
alias aptb0POPA = OPTABLE0!(    0x61,_i64_bit | _16_bit | _I386 | _modall);
alias aptb0POPAD = OPTABLE0!(   0x61,_i64_bit | _32_bit | _I386 | _modall);
alias aptb0POPF = OPTABLE0!(    0x9d,           _16_bit);
alias aptb0POPFD = OPTABLE0!(   0x9d,_i64_bit | _32_bit | _I386);
alias aptb0POPFQ = OPTABLE0!(   0x9d, _64_bit);
alias aptb0PUSHA = OPTABLE0!(   0x60,_i64_bit | _16_bit | _I386);
alias aptb0PUSHAD = OPTABLE0!(  0x60,_i64_bit | _32_bit | _I386);
alias aptb0PUSHF = OPTABLE0!(   0x9c,           _16_bit);
alias aptb0PUSHFD = OPTABLE0!(  0x9c,_i64_bit | _32_bit | _I386);
alias aptb0PUSHFQ = OPTABLE0!(  0x9c, _64_bit);                // TODO REX_W override is implicit
alias aptb0REP = OPTABLE0!(     0xf3, _modcx);
alias aptb0REPNE = OPTABLE0!(   0xf2, _modcx);
alias aptb0SAHF = OPTABLE0!(    0x9e, 0);
alias aptb0SCASB = OPTABLE0!(   0xAE, _moddi);
alias aptb0SCASW = OPTABLE0!(   0xAF, _16_bit | _moddi);
alias aptb0SCASD = OPTABLE0!(   0xAF, _32_bit | _I386 | _moddi);
alias aptb0SCASQ = OPTABLE0!(   0xAF, _64_bit | _moddi);
alias aptb0STC = OPTABLE0!(     0xf9, 0);
alias aptb0STD = OPTABLE0!(     0xfd, 0);
alias aptb0STI = OPTABLE0!(     0xfb, 0);
alias aptb0STOSB = OPTABLE0!(   0xaa, _moddi);
alias aptb0STOSW = OPTABLE0!(   0xAB, _16_bit | _moddi);
alias aptb0STOSD = OPTABLE0!(   0xAB, _32_bit | _I386 | _moddi);
alias aptb0STOSQ = OPTABLE0!(   0xAB, _64_bit | _moddi);
alias aptb0WAIT = OPTABLE0!(    0x9B, 0);
alias aptb0WBINVD = OPTABLE0!(  0x0f09, _I386);                        // Really a 486 opcode
alias aptb0XLATB = OPTABLE0!(   0xd7, _modax);
alias aptb0CPUID = OPTABLE0!(   0x0fa2, _I386 | _modall);
alias aptb0RDMSR = OPTABLE0!(   0x0f32, _I386 | _modaxdx);
alias aptb0RDPMC = OPTABLE0!(   0x0f33, _I386 | _modaxdx);
alias aptb0RDTSC = OPTABLE0!(   0x0f31, _I386 | _modaxdx);
alias aptb0RDTSCP = OPTABLE0!(  0x0f01f9, _I386 | _modaxdx | _modcx);
alias aptb0WRMSR = OPTABLE0!(   0x0f30, _I386);
alias aptb0RSM = OPTABLE0!(     0x0faa,_i64_bit | _I386);

//
// Now come the one operand instructions
// These will prove to be a little more challenging than the 0
// operand instructions
//
PTRNTAB1[3] aptb1BSWAP = /* BSWAP */ [
                                // Really is a 486 only instruction
        { 0x0fc8,   _I386, _plus_r | _r32 },
        { 0x0fc8, _64_bit, _plus_r | _r64 },
        { ASM_END }
];

PTRNTAB1[13] aptb1CALL = /* CALL */ [
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
];

PTRNTAB1[7] aptb1DEC = /* DEC */ [
        { 0xfe, _1,                        _rm8 },
        { 0x48, _rw | _i64_bit | _16_bit,  _r16 | _plus_r },
        { 0x48, _rd | _i64_bit | _32_bit,  _r32 | _plus_r },
        { 0xff, _1  |            _16_bit,  _rm16 },
        { 0xff, _1  |            _32_bit,  _rm32 },
        { 0xff, _1  |            _64_bit,  _rm64 },
        { ASM_END }
];

PTRNTAB1[7] aptb1INC = /* INC */ [
        { 0xfe, _0,                        _rm8 },
        { 0x40, _rw | _i64_bit | _16_bit,  _r16 | _plus_r },
        { 0x40, _rd | _i64_bit | _32_bit,  _r32 | _plus_r },
        { 0xff, _0  |            _16_bit,  _rm16 },
        { 0xff, _0  |            _32_bit,  _rm32 },
        { 0xff, _0  |            _64_bit,  _rm64 },
        { ASM_END }
];
// INT and INT 3
PTRNTAB1[3] aptb1INT= /* INT */ [
        { 0xcc, 3,              0 },    // The ulFlags here are meant to
                                        // be the value of the immediate
                                        // operand
        { 0xcd, 0,              _imm8 },
        { ASM_END }
];
PTRNTAB1[2] aptb1INVLPG = /* INVLPG */ [         // 486 only instruction
        { 0x0f01,       _I386|_7, _m48_32_16_8 },
        { ASM_END }
];


template OPTABLE_J(opcode_t op)
{
    immutable PTRNTAB1[4] OPTABLE_J =
    [
        { 0x70|op,   _cb,         _rel8 },
        { 0x0f80|op, _cw|_i64_bit,_rel16 },
        { 0x0f80|op, _cd,         _rel32 },
        { ASM_END }
    ];
}

alias aptb1JO   = OPTABLE_J!(0);
alias aptb1JNO  = OPTABLE_J!(1);
alias aptb1JB   = OPTABLE_J!(2);
alias aptb1JNB  = OPTABLE_J!(3);
alias aptb1JZ   = OPTABLE_J!(4);
alias aptb1JNZ  = OPTABLE_J!(5);
alias aptb1JBE  = OPTABLE_J!(6);
alias aptb1JNBE = OPTABLE_J!(7);
alias aptb1JS   = OPTABLE_J!(8);
alias aptb1JNS  = OPTABLE_J!(9);
alias aptb1JP   = OPTABLE_J!(0xA);
alias aptb1JNP  = OPTABLE_J!(0xB);
alias aptb1JL   = OPTABLE_J!(0xC);
alias aptb1JNL  = OPTABLE_J!(0xD);
alias aptb1JLE  = OPTABLE_J!(0xE);
alias aptb1JNLE = OPTABLE_J!(0xF);

PTRNTAB1[2] aptb1JCXZ = /* JCXZ */ [
        { 0xe3, _cb | _i64_bit | _16_bit_addr, _rel8 },
        { ASM_END }
];
PTRNTAB1[2] aptb1JECXZ = /* JECXZ */ [
        { 0xe3, _cb | _32_bit_addr | _I386,_rel8 },
        { ASM_END }
];
PTRNTAB1[11] aptb1JMP = /* JMP */ [
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
];
PTRNTAB1[2] aptb1LGDT = /* LGDT */ [
        { 0x0f01,       _2,     _m48 },
        { ASM_END }
];
PTRNTAB1[2] aptb1LIDT = /* LIDT */ [
        { 0x0f01,       _3,     _m48 },
        { ASM_END }
];
PTRNTAB1[2] aptb1LLDT = /* LLDT */ [
        { 0x0f00,       _2|_modnot1,    _rm16 },
        { ASM_END }
];
PTRNTAB1[2] aptb1LMSW = /* LMSW */ [
        { 0x0f01,       _6|_modnot1,    _rm16 },
        { ASM_END }
];
PTRNTAB1[4] aptb1LODS = /* LODS */ [
        { 0xac, _modax,_m8 },
        { 0xad, _16_bit | _modax,_m16 },
        { 0xad, _32_bit | _I386 | _modax,_m32 },
        { ASM_END }
];
PTRNTAB1[2] aptb1LOOP = /* LOOP */ [
        { 0xe2, _cb | _modcx,_rel8 },
        { ASM_END }
];
PTRNTAB1[2] aptb1LOOPE = /* LOOPE/LOOPZ */ [
        { 0xe1, _cb | _modcx,_rel8 },
        { ASM_END }
];
PTRNTAB1[2] aptb1LOOPNE = /* LOOPNE/LOOPNZ */ [
        { 0xe0, _cb | _modcx,_rel8 },
        { ASM_END }
];
PTRNTAB1[2] aptb1LTR = /* LTR */ [
        { 0x0f00,       _3|_modnot1,    _rm16 },
        { ASM_END }
];
PTRNTAB1[5] aptb1NEG = /* NEG */ [
        { 0xf6, _3,     _rm8 },
        { 0xf7, _3 | _16_bit,   _rm16 },
        { 0xf7, _3 | _32_bit,   _rm32 },
        { 0xf7, _3 | _64_bit,   _rm64 },
        { ASM_END }
];
PTRNTAB1[5] aptb1NOT = /* NOT */ [
        { 0xf6, _2,     _rm8 },
        { 0xf7, _2 | _16_bit,   _rm16 },
        { 0xf7, _2 | _32_bit,   _rm32 },
        { 0xf7, _2 | _64_bit,   _rm64 },
        { ASM_END }
];
PTRNTAB1[12] aptb1POP = /* POP */ [
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
];
PTRNTAB1[18] aptb1PUSH = /* PUSH */ [
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
];
PTRNTAB1[3] aptb1RET = /* RET */ [
        { 0xc3, 0,      0 },
        { 0xc2, _iw,    _imm16 },
        { ASM_END }
];
PTRNTAB1[3] aptb1RETF = /* RETF */ [
        { 0xcb, 0, 0 },
        { 0xca, _iw, _imm16 },
        { ASM_END }
];
PTRNTAB1[4] aptb1SCAS = /* SCAS */ [
        { 0xae, _moddi, _m8 },
        { 0xaf, _16_bit | _moddi, _m16 },
        { 0xaf, _32_bit | _moddi, _m32 },
        { ASM_END }
];

template OPTABLE_SET(opcode_t op)
{
    immutable PTRNTAB1[2] OPTABLE_SET =
    [
        { 0xf90|op, _cb, _rm8 },
        { ASM_END }
    ];
}

alias aptb1SETO   = OPTABLE_SET!(0);
alias aptb1SETNO  = OPTABLE_SET!(1);
alias aptb1SETB   = OPTABLE_SET!(2);
alias aptb1SETNB  = OPTABLE_SET!(3);
alias aptb1SETZ   = OPTABLE_SET!(4);
alias aptb1SETNZ  = OPTABLE_SET!(5);
alias aptb1SETBE  = OPTABLE_SET!(6);
alias aptb1SETNBE = OPTABLE_SET!(7);
alias aptb1SETS   = OPTABLE_SET!(8);
alias aptb1SETNS  = OPTABLE_SET!(9);
alias aptb1SETP   = OPTABLE_SET!(0xA);
alias aptb1SETNP  = OPTABLE_SET!(0xB);
alias aptb1SETL   = OPTABLE_SET!(0xC);
alias aptb1SETNL  = OPTABLE_SET!(0xD);
alias aptb1SETLE  = OPTABLE_SET!(0xE);
alias aptb1SETNLE = OPTABLE_SET!(0xF);


PTRNTAB1[2]  aptb1SGDT= /* SGDT */ [
        { 0xf01, _0, _m48 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1SIDT = /* SIDT */ [
        { 0xf01, _1, _m48 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1SLDT = /* SLDT */ [
        { 0xf00, _0, _rm16 },
        { ASM_END }
];
PTRNTAB1[3]  aptb1SMSW = /* SMSW */ [
        { 0xf01, _4, _rm16 },
        { 0xf01, _4, _r32 },
        { ASM_END }
];
PTRNTAB1[4]  aptb1STOS = /* STOS */ [
        { 0xaa, _moddi, _m8 },
        { 0xab, _16_bit | _moddi, _m16 },
        { 0xab, _32_bit | _moddi, _m32 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1STR = /* STR */ [
        { 0xf00, _1, _rm16 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1VERR = /* VERR */ [
        { 0xf00, _4|_modnot1, _rm16 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1VERW = /* VERW */ [
        { 0xf00, _5|_modnot1, _rm16 },
        { ASM_END }
];
PTRNTAB1[3]  aptb1XLAT = /* XLAT */ [
        { 0xd7, _modax, 0 },
        { 0xd7, _modax, _m8 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1CMPXCHG8B = /* CMPXCHG8B */ [
    { 0x0fc7, _1 | _modaxdx | _I386, _m64 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1CMPXCHG16B = /* CMPXCHG16B */ [
    { 0x0fc7, _1 | _modaxdx | _64_bit, _m128 },
        { ASM_END }
];

template OPTABLE_ARITH(opcode_t op, uint rr, uint m)
{
    immutable PTRNTAB2[20] OPTABLE_ARITH =
    [
        { op+4,  _ib|m,               _al,        _imm8 },
        { 0x83, rr|_ib|_16_bit|m,     _rm16,      _imm8 },
        { op+5, _iw|_16_bit|m,        _ax,        _imm16 },
        { 0x83, rr|_ib|_32_bit|m,     _rm32,      _imm8 },
        { 0x83, rr|_ib|_64_bit|m,     _rm64,      _imm8 },
        { op+5, _id|_32_bit|m,        _eax,       _imm32 },
        { op+5, _id|_64_bit|m,        _rax,       _imm32 },
        { 0x80, rr|_ib|m,             _rm8,       _imm8 },
        { 0x81, rr|_iw|_16_bit|m,     _rm16,      _imm16 },
        { 0x81, rr|_id|_32_bit|m,     _rm32,      _imm32 },
        { 0x81, rr|_id|_64_bit|m,     _rm64,      _imm32 },
        { op+0, _r|m,                 _rm8,       _r8 },
        { op+1, _r|_16_bit|m,         _rm16,      _r16 },
        { op+1, _r|_32_bit|m,         _rm32,      _r32 },
        { op+1, _r|_64_bit|m,         _rm64,      _r64 },
        { op+2, _r|m,                 _r8,        _rm8 },
        { op+3, _r|_16_bit|m,         _r16,       _rm16 },
        { op+3, _r|_32_bit|m,         _r32,       _rm32 },
        { op+3, _r|_64_bit|m,         _r64,       _rm64 },
        { ASM_END }
    ];
}

alias aptb2ADD = OPTABLE_ARITH!(0x00,_0,0);
alias aptb2OR  = OPTABLE_ARITH!( 0x08,_1,0);
alias aptb2ADC = OPTABLE_ARITH!(0x10,_2,0);
alias aptb2SBB = OPTABLE_ARITH!(0x18,_3,0);
alias aptb2AND = OPTABLE_ARITH!(0x20,_4,0);
alias aptb2SUB = OPTABLE_ARITH!(0x28,_5,0);
alias aptb2XOR = OPTABLE_ARITH!(0x30,_6,0);
alias aptb2CMP = OPTABLE_ARITH!(0x38,_7,_modnot1);


PTRNTAB2[2]  aptb2ARPL = /* ARPL */ [
        { 0x63, _r|_i64_bit,               _rm16, _r16 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2BOUND = /* BOUND */ [
        { 0x62, _r|_i64_bit|_16_bit|_modnot1,_r16,_m16 },// Should really b3 _m16_16
        { 0x62, _r|_i64_bit|_32_bit|_modnot1,_r32,_m32 },// Should really be _m32_32
        { ASM_END }
];
PTRNTAB2[4]  aptb2BSF = /* BSF */ [
        { 0x0fbc,       _cw | _16_bit,          _r16,   _rm16 },
        { 0x0fbc,       _cd|_32_bit,            _r32,   _rm32 },
        { 0x0fbc,       _cq|_64_bit,            _r64,   _rm64 },
        { ASM_END }
];
PTRNTAB2[4]  aptb2BSR = /* BSR */ [
        { 0x0fbd,       _cw|_16_bit,            _r16,   _rm16 },
        { 0x0fbd,       _cd|_32_bit,            _r32,   _rm32 },
        { 0x0fbd,       _cq|_64_bit,            _r64,   _rm64 },
        { ASM_END }
];
PTRNTAB2[7]  aptb2BT = /* BT */ [
        { 0x0fa3,       _cw|_16_bit|_modnot1,           _rm16,  _r16 },
        { 0x0fa3,       _cd|_32_bit|_modnot1,           _rm32,  _r32 },
        { 0x0fa3,       _cq|_64_bit|_modnot1,           _rm64,  _r64 },
        { 0x0fba,       _4|_ib|_16_bit|_modnot1,        _rm16,  _imm8 },
        { 0x0fba,       _4|_ib|_32_bit|_modnot1,        _rm32,  _imm8 },
        { 0x0fba,       _4|_ib|_64_bit|_modnot1,        _rm64,  _imm8 },
        { ASM_END }
];
PTRNTAB2[7]  aptb2BTC = /* BTC */ [
        { 0x0fbb,       _cw|_16_bit,            _rm16,  _r16 },
        { 0x0fbb,       _cd|_32_bit,            _rm32,  _r32 },
        { 0x0fbb,       _cq|_64_bit,            _rm64,  _r64 },
        { 0x0fba,       _7|_ib|_16_bit, _rm16,  _imm8 },
        { 0x0fba,       _7|_ib|_32_bit, _rm32,  _imm8 },
        { 0x0fba,       _7|_ib|_64_bit, _rm64,  _imm8 },
        { ASM_END }
];
PTRNTAB2[7]  aptb2BTR = /* BTR */ [
        { 0x0fb3,       _cw|_16_bit,            _rm16,  _r16 },
        { 0x0fb3,       _cd|_32_bit,            _rm32,  _r32 },
        { 0x0fb3,       _cq|_64_bit,            _rm64,  _r64 },
        { 0x0fba,       _6|_ib|_16_bit,         _rm16,  _imm8 },
        { 0x0fba,       _6|_ib|_32_bit,         _rm32,  _imm8 },
        { 0x0fba,       _6|_ib|_64_bit,         _rm64,  _imm8 },
        { ASM_END }
];
PTRNTAB2[7]  aptb2BTS = /* BTS */ [
        { 0x0fab,       _cw|_16_bit,            _rm16,  _r16 },
        { 0x0fab,       _cd|_32_bit,            _rm32,  _r32 },
        { 0x0fab,       _cq|_64_bit,            _rm64,  _r64 },
        { 0x0fba,       _5|_ib|_16_bit,         _rm16,  _imm8 },
        { 0x0fba,       _5|_ib|_32_bit,         _rm32,  _imm8 },
        { 0x0fba,       _5|_ib|_64_bit,         _rm64,  _imm8 },
        { ASM_END }
];
PTRNTAB2[4]  aptb2CMPS = /* CMPS */ [
        { 0xa6, _modsidi,               _m8,    _m8 },
        { 0xa7, _modsidi,       _m16,   _m16 },
        { 0xa7, _modsidi,       _m32,   _m32 },
        { ASM_END }
];
PTRNTAB2[5]  aptb2CMPXCHG = /* CMPXCHG */ [
        { 0xfb0, _I386 | _cb|_mod2,     _rm8,   _r8 },
                                                // This is really a 486 only
                                                // instruction
        { 0xfb1, _I386 | _cw | _16_bit|_mod2,   _rm16,  _r16 },
        { 0xfb1, _I386 | _cd | _32_bit|_mod2,   _rm32,  _r32 },
        { 0xfb1, _I386 | _cq | _64_bit|_mod2,   _rm64,  _r64 },
        { ASM_END }
];
PTRNTAB2[9]  aptb2DIV = /* DIV */ [
        { 0xf6, _6,                             _al,            _rm8 },
        { 0xf7, _6 | _16_bit | _moddx,          _ax,            _rm16 },
        { 0xf7, _6 | _32_bit | _moddx,          _eax,           _rm32 },
        { 0xf7, _6 | _64_bit | _moddx,          _rax,           _rm64 },
        { 0xf6, _6 | _modax,                    _rm8,           0 },
        { 0xf7, _6 | _16_bit | _modaxdx,        _rm16,          0 },
        { 0xf7, _6 | _32_bit | _modaxdx,        _rm32,          0 },
        { 0xf7, _6 | _64_bit | _modaxdx,        _rm64,          0 },
        { ASM_END }
];
PTRNTAB2[2]  aptb2ENTER = /* ENTER */ [
        { 0xc8, _iw|_ib,        _imm16, _imm8 },
        { ASM_END }
];
PTRNTAB2[9]  aptb2IDIV = /* IDIV */ [
        { 0xf6, _7,                     _al,            _rm8 },
        { 0xf7, _7|_16_bit|_moddx,      _ax,            _rm16 },
        { 0xf7, _7|_32_bit|_moddx,      _eax,           _rm32 },
        { 0xf7, _7|_64_bit|_moddx,      _rax,           _rm64 },
        { 0xf6, _7 | _modax,            _rm8,           0 },
        { 0xf7, _7|_16_bit|_modaxdx,    _rm16,          0 },
        { 0xf7, _7|_32_bit|_modaxdx,    _rm32,          0 },
        { 0xf7, _7|_64_bit|_modaxdx,    _rm64,          0 },
        { ASM_END }
];
PTRNTAB2[7]  aptb2IN = /* IN */ [
        { 0xe4, _ib,        _al,                _imm8 },
        { 0xe5, _ib|_16_bit,_ax,                _imm8 },
        { 0xe5, _ib|_32_bit,_eax,       _imm8 },
        { 0xec, 0,          _al,                _dx },
        { 0xed, _16_bit,    _ax,                _dx },
        { 0xed, _32_bit,    _eax,       _dx },
        { ASM_END }
];
PTRNTAB2[4]  aptb2INS = /* INS */ [
        { 0x6c, _modsi, _rm8, _dx },
        { 0x6d, _modsi|_16_bit, _rm16, _dx },
        { 0x6d, _32_bit|_modsi, _rm32, _dx },
        { ASM_END }
];

PTRNTAB2[3]  aptb2LAR = /* LAR */ [
        { 0x0f02,       _r|_16_bit,                     _r16,   _rm16 },
        { 0x0f02,       _r|_32_bit,                     _r32,   _rm32 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2LDS = /* LDS */ [
        { 0xc5, _r|_i64_bit|_16_bit,                    _r16,   _m32 },
        { 0xc5, _r|_i64_bit|_32_bit,                    _r32,   _m48 },
        { ASM_END }
];

PTRNTAB2[7]  aptb2LEA = /* LEA */ [
        { 0x8d, _r|_16_bit,             _r16,   _m48_32_16_8 },
        { 0x8d, _r|_32_bit,             _r32,   _m48_32_16_8 },
        { 0x8d, _r|_64_bit,             _r64,   _m64_48_32_16_8 },
        { 0x8d, _r|_16_bit,             _r16,   _rel16 },
        { 0x8d, _r|_32_bit,             _r32,   _rel32 },
        { 0x8d, _r|_64_bit,             _r64,   _rel32 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2LES = /* LES */ [
        { 0xc4, _r|_i64_bit|_16_bit|_modes,             _r16,   _m32 },
        { 0xc4, _r|_i64_bit|_32_bit|_modes,             _r32,   _m48 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2LFS = /* LFS */ [
        { 0x0fb4,       _r|_16_bit,                     _r16,   _m32 },
        { 0x0fb4,       _r|_32_bit,                     _r32,   _m48 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2LGS = /* LGS */ [
        { 0x0fb5,       _r|_16_bit,                     _r16,   _m32  },
        { 0x0fb5,       _r|_32_bit,                     _r32,   _m48 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2LSS = /* LSS */ [
        { 0x0fb2,       _r|_16_bit,                     _r16,   _m32 },
        { 0x0fb2,       _r|_32_bit,                     _r32,   _m48 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2LSL = /* LSL */ [
        { 0x0f03,       _r|_16_bit,                     _r16,   _rm16 },
        { 0x0f03,       _r|_32_bit,                     _r32,   _rm32 },
        { ASM_END }
];

PTRNTAB2[26] aptb2MOV = /* MOV */ [
/+ // Let pinholeopt() do this
        { 0xa0, 0,              _al,            _moffs8         },
        { 0xa1, _16_bit,        _ax,            _moffs16        },
        { 0xa1, _32_bit,        _eax,           _moffs32        },
        { 0xa2, 0,              _moffs8,        _al             },
        { 0xa3, _16_bit,        _moffs16,       _ax             },
        { 0xa3, _32_bit,        _moffs32,       _eax            },
+/
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
/+ // Let pinholeopt() do this
        { 0xc6, _cb,            _moffs8,        _imm8           },
        { 0xc7, _cw|_16_bit,    _moffs16,       _imm16          },
        { 0xc7, _cd|_32_bit,    _moffs32,       _imm32          },
+/
        { 0x0f20,       _r,     _r32,           _special | _crn },
        { 0x0f22,       _r,     _special|_crn,  _r32            },
        { 0x0f20,       _r,     _r64,           _special | _crn },
        { 0x0f22,       _r,     _special|_crn,  _r64            },
        { 0x0f21,       _r,     _r32,           _special | _drn },
        { 0x0f23,       _r,     _special|_drn,  _r32            },
        { 0x0f24,       _r,     _r32,           _special | _trn },
        { 0x0f26,       _r,     _special|_trn,  _r32            },
        { ASM_END }
];

PTRNTAB2[4]  aptb2MOVS = /* MOVS */ [
        { 0xa4, _modsidi ,              _m8,    _m8 },
        { 0xa5, _modsidi | _16_bit,     _m16,   _m16 },
        { 0xa5, _modsidi | _32_bit,     _m32,   _m32 },
        { ASM_END }
];
PTRNTAB2[7]  aptb2MOVSX = /* MOVSX */ [
        { MOVSXb,       _r|_16_bit,             _r16,   _rm8 },
        { MOVSXb,       _r|_32_bit,             _r32,   _rm8 },
        { MOVSXb,       _r|_64_bit,             _r64,   _rm8 },  // TODO: REX_W override is implicit
        { MOVSXw,       _r|_16_bit,             _r16,   _rm16 },
        { MOVSXw,       _r|_32_bit,             _r32,   _rm16 },
        { MOVSXw,       _r|_64_bit,             _r64,   _rm16 }, // TODO: REX_W override is implicit
        { ASM_END }
];
PTRNTAB2[2]  aptb2MOVSXD = /* MOVSXD */ [
        { 0x63,         _r|_64_bit,             _r64,   _rm32 }, // TODO: REX_W override is implicit
        { ASM_END }
];
PTRNTAB2[7]  aptb2MOVZX = /* MOVZX */ [
        { MOVZXb,       _r|_16_bit,             _r16,   _rm8 },
        { MOVZXb,       _r|_32_bit,             _r32,   _rm8 },
        { MOVZXb,       _r|_64_bit,             _r64,   _rm8 },  // TODO: REX_W override is implicit
        { MOVZXw,       _r|_16_bit,             _r16,   _rm16 },
        { MOVZXw,       _r|_32_bit,             _r32,   _rm16 },
        { MOVZXw,       _r|_64_bit,             _r64,   _rm16 }, // TODO: REX_W override is implicit
        { ASM_END }
];
PTRNTAB2[9]  aptb2MUL = /* MUL */ [
        { 0xf6, _4,                     _al,    _rm8 },
        { 0xf7, _4|_16_bit|_moddx,      _ax,    _rm16 },
        { 0xf7, _4|_32_bit|_moddx,      _eax,   _rm32 },
        { 0xf7, _4|_64_bit|_moddx,      _rax,   _rm64 },
        { 0xf6, _4|_modax,              _rm8,   0 },
        { 0xf7, _4|_16_bit|_modaxdx,    _rm16,  0 },
        { 0xf7, _4|_32_bit|_modaxdx,    _rm32,  0 },
        { 0xf7, _4|_64_bit|_modaxdx,    _rm64,  0 },
        { ASM_END }
];
PTRNTAB2[4]  aptb2TZCNT = /* TZCNT */ [
        { 0xf30fbc,       _cw|_16_bit,            _r16,   _rm16 },
        { 0xf30fbc,       _cd|_32_bit,            _r32,   _rm32 },
        { 0xf30fbc,       _cq|_64_bit,            _r64,   _rm64 },
        { ASM_END }
];
PTRNTAB2[4]  aptb2LZCNT = /* LZCNT */ [
        { 0xf30fbd,       _cw|_16_bit,            _r16,   _rm16 },
        { 0xf30fbd,       _cd|_32_bit,            _r32,   _rm32 },
        { 0xf30fbd,       _cq|_64_bit,            _r64,   _rm64 },
        { ASM_END }
];
PTRNTAB2[7]  aptb2OUT = /* OUT */ [
        { 0xe6, _ib,            _imm8,  _al },
        { 0xe7, _ib|_16_bit,            _imm8,  _ax },
        { 0xe7, _ib|_32_bit,            _imm8,  _eax },
        { 0xee, _modnot1,               _dx,            _al },
        { 0xef, _16_bit|_modnot1,               _dx,            _ax },
        { 0xef, _32_bit|_modnot1,               _dx,            _eax },
        { ASM_END }
];
PTRNTAB2[4]  aptb2OUTS = /* OUTS */ [
        { 0x6e, _modsinot1,             _dx,            _rm8 },
        { 0x6f, _16_bit | _I386 |_modsinot1,    _dx,            _rm16 },
        { 0x6f, _32_bit | _I386| _modsinot1,    _dx,            _rm32 },
        { ASM_END }
];


template OPTABLE_SHIFT(opcode_t op)
{
    immutable PTRNTAB2[9] OPTABLE_SHIFT =
    [
        { 0xd2, op,             _rm8,   _cl },
        { 0xc0, op|_ib,         _rm8,   _imm8 },
        { 0xd3, op|_16_bit,     _rm16,  _cl },
        { 0xc1, op|_ib|_16_bit, _rm16,  _imm8 },
        { 0xd3, op|_32_bit,     _rm32,  _cl },
        { 0xc1, op|_ib|_32_bit, _rm32,  _imm8, },
        { 0xd3, op|_64_bit,     _rm64,  _cl },
        { 0xc1, op|_ib|_64_bit, _rm64,  _imm8, },
        { ASM_END }
    ];
}

alias aptb2ROL = OPTABLE_SHIFT!(_0);
alias aptb2ROR = OPTABLE_SHIFT!(_1);
alias aptb2RCL = OPTABLE_SHIFT!(_2);
alias aptb2RCR = OPTABLE_SHIFT!(_3);
alias aptb2SHL = OPTABLE_SHIFT!(_4);
alias aptb2SHR = OPTABLE_SHIFT!(_5);
alias aptb2SAR = OPTABLE_SHIFT!(_7);


PTRNTAB2[13]  aptb2TEST = /* TEST */ [
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
];
PTRNTAB2[5]  aptb2XADD = /* XADD */ [                    // 486 only instruction
//      { 0x0fc0,       _ib | _I386|_mod2, _rm8, _r8 },
//      { 0x0fc1,       _iw | _I386|_16_bit|_mod2, _rm16, _r16 },
//      { 0x0fc1,       _id | _I386|_32_bit|_mod2, _rm32, _r32 },
        { 0x0fc0,       _r | _I386|_mod2, _rm8, _r8 },
        { 0x0fc1,       _r | _I386|_16_bit|_mod2, _rm16, _r16 },
        { 0x0fc1,       _r | _I386|_32_bit|_mod2, _rm32, _r32 },
        { 0x0fc1,       _r | _64_bit|_mod2, _rm64, _r64 },
        { ASM_END }
];
PTRNTAB2[13]  aptb2XCHG = /* XCHG */ [
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
];


template OPTABLE_CMOV(opcode_t op)
{
    immutable PTRNTAB2[4] OPTABLE_CMOV =
    [
        { 0x0F40|op, _r|_16_bit,   _r16,   _rm16 },
        { 0x0F40|op, _r|_32_bit,   _r32,   _rm32 },
        { 0x0F40|op, _r|_64_bit,   _r64,   _rm64 },
        { ASM_END }
    ];
}

alias aptb2CMOVO   = OPTABLE_CMOV!(0);
alias aptb2CMOVNO  = OPTABLE_CMOV!(1);
alias aptb2CMOVB   = OPTABLE_CMOV!(2);
alias aptb2CMOVNB  = OPTABLE_CMOV!(3);
alias aptb2CMOVZ   = OPTABLE_CMOV!(4);
alias aptb2CMOVNZ  = OPTABLE_CMOV!(5);
alias aptb2CMOVBE  = OPTABLE_CMOV!(6);
alias aptb2CMOVNBE = OPTABLE_CMOV!(7);
alias aptb2CMOVS   = OPTABLE_CMOV!(8);
alias aptb2CMOVNS  = OPTABLE_CMOV!(9);
alias aptb2CMOVP   = OPTABLE_CMOV!(0xA);
alias aptb2CMOVNP  = OPTABLE_CMOV!(0xB);
alias aptb2CMOVL   = OPTABLE_CMOV!(0xC);
alias aptb2CMOVNL  = OPTABLE_CMOV!(0xD);
alias aptb2CMOVLE  = OPTABLE_CMOV!(0xE);
alias aptb2CMOVNLE = OPTABLE_CMOV!(0xF);


PTRNTAB3[19]  aptb3IMUL = /* IMUL */ [
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
];
PTRNTAB3[7]  aptb3SHLD = /* SHLD */ [
        { 0x0fa4,       _cw|_16_bit, _rm16, _r16, _imm8 },
        { 0x0fa4,       _cd|_32_bit, _rm32, _r32, _imm8 },
        { 0x0fa4,       _cq|_64_bit, _rm64, _r64, _imm8 },
        { 0x0fa5,       _cw|_16_bit, _rm16, _r16, _cl },
        { 0x0fa5,       _cd|_32_bit, _rm32, _r32, _cl },
        { 0x0fa5,       _cq|_64_bit, _rm64, _r64, _cl },
        { ASM_END }
];
PTRNTAB3[7]  aptb3SHRD = /* SHRD */ [
        { 0x0fac,       _cw|_16_bit, _rm16, _r16, _imm8 },
        { 0x0fac,       _cd|_32_bit, _rm32, _r32, _imm8 },
        { 0x0fac,       _cq|_64_bit, _rm64, _r64, _imm8 },
        { 0x0fad,       _cw|_16_bit, _rm16, _r16, _cl },
        { 0x0fad,       _cd|_32_bit, _rm32, _r32, _cl },
        { 0x0fad,       _cq|_64_bit, _rm64, _r64, _cl },
        { ASM_END }
];
//
// Floating point instructions which have entirely different flag
// interpretations
//

alias aptb0F2XM1 = OPTABLE0!(    0xd9f0,0);
alias aptb0FABS = OPTABLE0!(     0xd9e1,0);
alias aptb0FCHS = OPTABLE0!(     0xd9e0,0);
alias aptb0FCLEX = OPTABLE0!(    0xdbe2,_fwait);
alias aptb0FNCLEX = OPTABLE0!(   0xdbe2, _nfwait);
alias aptb0FCOMPP = OPTABLE0!(   0xded9, 0);
alias aptb0FCOS = OPTABLE0!(     0xd9ff, 0);
alias aptb0FUCOMPP = OPTABLE0!(  0xdae9, 0);
alias aptb0FDECSTP = OPTABLE0!(  0xd9f6, 0);
alias aptb0FINCSTP = OPTABLE0!(  0xd9f7, 0);
alias aptb0FINIT = OPTABLE0!(    0xdbe3, _fwait);
alias aptb0FNINIT = OPTABLE0!(   0xdbe3, _nfwait);
alias aptb0FENI = OPTABLE0!(     0xdbe0, _fwait);
alias aptb0FNENI = OPTABLE0!(    0xdbe0, _nfwait);
alias aptb0FDISI = OPTABLE0!(    0xdbe1, _fwait);
alias aptb0FNDISI = OPTABLE0!(   0xdbe1, _nfwait);
alias aptb0FLD1 = OPTABLE0!(     0xd9e8, 0);
alias aptb0FLDL2T = OPTABLE0!(   0xd9e9, 0);
alias aptb0FLDL2E = OPTABLE0!(   0xd9ea, 0);
alias aptb0FLDPI = OPTABLE0!(    0xd9eb, 0);
alias aptb0FLDLG2 = OPTABLE0!(   0xd9ec, 0);
alias aptb0FLDLN2 = OPTABLE0!(   0xd9ed, 0);
alias aptb0FLDZ = OPTABLE0!(     0xd9ee, 0);
alias aptb0FNOP = OPTABLE0!(     0xd9d0, 0);
alias aptb0FPATAN = OPTABLE0!(   0xd9f3, 0);
alias aptb0FPREM = OPTABLE0!(    0xd9f8, 0);
alias aptb0FPREM1 = OPTABLE0!(   0xd9f5, 0);
alias aptb0FPTAN = OPTABLE0!(    0xd9f2, 0);
alias aptb0FRNDINT = OPTABLE0!(  0xd9fc, 0);
alias aptb0FSCALE = OPTABLE0!(   0xd9fd, 0);
alias aptb0FSETPM = OPTABLE0!(   0xdbe4, 0);
alias aptb0FSIN = OPTABLE0!(     0xd9fe, 0);
alias aptb0FSINCOS = OPTABLE0!(  0xd9fb, 0);
alias aptb0FSQRT = OPTABLE0!(    0xd9fa, 0);
alias aptb0FTST = OPTABLE0!(     0xd9e4, 0);
alias aptb0FWAIT = OPTABLE0!(    0x9b, 0);
alias aptb0FXAM = OPTABLE0!(     0xd9e5, 0);
alias aptb0FXTRACT = OPTABLE0!(  0xd9f4, 0);
alias aptb0FYL2X = OPTABLE0!(    0xd9f1, 0);
alias aptb0FYL2XP1 = OPTABLE0!(  0xd9f9, 0);
//
// Floating point instructions which have entirely different flag
// interpretations but they overlap, only asm_determine_operator
// flags needs to know the difference
//      1 operand floating point instructions follow
//
PTRNTAB1[2]  aptb1FBLD = /* FBLD */ [
        { 0xdf, _4, _fm80 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1FBSTP = /* FBSTP */ [
        { 0xdf, _6, _fm80 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FCMOVB = /* FCMOVB */ [
        { 0xdac0, 0, _st, _sti | _plus_r },
        { 0xdac1, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FCMOVE = /* FCMOVE */ [
        { 0xdac8, 0, _st, _sti | _plus_r },
        { 0xdac9, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FCMOVBE = /* FCMOVBE */ [
        { 0xdad0, 0, _st, _sti | _plus_r },
        { 0xdad1, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FCMOVU = /* FCMOVU */ [
        { 0xdad8, 0, _st, _sti | _plus_r },
        { 0xdad9, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FCMOVNB = /* FCMOVNB */ [
        { 0xdbc0, 0, _st, _sti | _plus_r },
        { 0xdbc1, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FCMOVNE = /* FCMOVNE */ [
        { 0xdbc8, 0, _st, _sti | _plus_r },
        { 0xdbc9, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FCMOVNBE = /* FCMOVNBE */ [
        { 0xdbd0, 0, _st, _sti | _plus_r },
        { 0xdbd1, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FCMOVNU = /* FCMOVNU */ [
        { 0xdbd8, 0, _st, _sti | _plus_r },
        { 0xdbd9, 0, 0 },
        { ASM_END }
];
PTRNTAB1[5]  aptb1FCOM = /* FCOM */ [
        { 0xd8, _2, _m32 },
        { 0xdc, _2, _fm64 },
        { 0xd8d0, 0, _sti | _plus_r },
        { 0xd8d1, 0, 0 },
        { ASM_END }
];

PTRNTAB2[4]  aptb2FCOMI = /* FCOMI */ [
        { 0xdbf0, 0, _st, _sti | _plus_r },
        { 0xdbf0, 0, _sti | _plus_r, 0 },
        { 0xdbf1, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[4]  aptb2FCOMIP = /* FCOMIP */ [
        { 0xdff0, 0, _st, _sti | _plus_r },
        { 0xdff0, 0, _sti | _plus_r, 0 },
        { 0xdff1, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[4]  aptb2FUCOMI = /* FUCOMI */ [
        { 0xdbe8, 0, _st, _sti | _plus_r },
        { 0xdbe8, 0, _sti | _plus_r, 0 },
        { 0xdbe9, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[4]  aptb2FUCOMIP = /* FUCOMIP */ [
        { 0xdfe8, 0, _st, _sti | _plus_r },
        { 0xdfe8, 0, _sti | _plus_r, 0 },
        { 0xdfe9, 0, 0, 0 },
        { ASM_END }
];

PTRNTAB1[5]  aptb1FCOMP = /* FCOMP */ [
        { 0xd8, _3, _m32 },
        { 0xdc, _3, _fm64 },
        { 0xd8d8, 0, _sti | _plus_r },
        { 0xd8d9, 0, 0 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FFREE = /* FFREE */ [
        { 0xddc0,       0,      _sti | _plus_r },
        { ASM_END }
];
PTRNTAB1[3]  aptb1FICOM = /* FICOM */ [
        { 0xde, _2, _m16 },
        { 0xda, _2, _m32 },
        { ASM_END }
];
PTRNTAB1[3]  aptb1FICOMP = /* FICOMP */ [
        { 0xde, _3, _m16 },
        { 0xda, _3, _m32 },
        { ASM_END }
];
PTRNTAB1[4]  aptb1FILD = /* FILD */ [
        { 0xdf, _0, _m16 },
        { 0xdb, _0, _m32 },
        { 0xdf, _5, _fm64 },
        { ASM_END }
];
PTRNTAB1[3]  aptb1FIST = /* FIST */ [
        { 0xdf, _2, _m16 },
        { 0xdb, _2, _m32 },
        { ASM_END }
];
PTRNTAB1[4]  aptb1FISTP = /* FISTP */ [
        { 0xdf, _3, _m16 },
        { 0xdb, _3, _m32 },
        { 0xdf, _7, _fm64 },
        { ASM_END }
];
PTRNTAB1[5]  aptb1FLD = /* FLD */ [
        { 0xd9, _0, _m32 },
        { 0xdd, _0, _fm64 },
        { 0xdb, _5, _fm80 },
        { 0xd9c0, 0, _sti | _plus_r },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FLDCW = /* FLDCW */ [
        { 0xd9, _5, _m16 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FLDENV = /* FLDENV */ [
        { 0xd9, _4, _m112 | _m224 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FRSTOR = /* FRSTOR */ [
        { 0xdd, _4, _m112 | _m224 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FSAVE = /* FSAVE */ [
        { 0xdd, _6 | _fwait, _m112 | _m224 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FNSAVE = /* FNSAVE */ [
        { 0xdd, _6 | _nfwait, _m112 | _m224 },
        { ASM_END }
];
PTRNTAB1[4]  aptb1FST = /* FST */ [
        { 0xd9, _2, _m32 },
        { 0xdd, _2, _fm64 },
        { 0xddd0, 0, _sti | _plus_r },
        { ASM_END }
];

PTRNTAB1[5]  aptb1FSTP = /* FSTP */ [
        { 0xd9, _3, _m32 },
        { 0xdd, _3, _fm64 },
        { 0xdb, _7, _fm80 },
        { 0xddd8, 0, _sti | _plus_r },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FSTCW = /* FSTCW */ [
        { 0xd9, _7 | _fwait , _m16 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FNSTCW = /* FNSTCW */ [
        { 0xd9, _7 | _nfwait , _m16 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FSTENV = /* FSTENV */ [
        { 0xd9, _6 | _fwait, _m112 | _m224 },
        { ASM_END }
];
PTRNTAB1[2]  aptb1FNSTENV = /* FNSTENV */ [
        { 0xd9, _6 | _nfwait, _m112 | _m224 },
        { ASM_END }
];
PTRNTAB1[3]  aptb1FSTSW = /* FSTSW */ [
        { 0xdd, _7 | _fwait, _m16 },
        { 0xdfe0, _fwait | _modax, _ax },
        { ASM_END }
];
PTRNTAB1[3]  aptb1FNSTSW = /* FNSTSW */ [
        { 0xdd, _7 | _nfwait, _m16 },
        { 0xdfe0, _nfwait | _modax, _ax },
        { ASM_END }
];
PTRNTAB1[3]  aptb1FUCOM = /* FUCOM */ [
        { 0xdde0, 0, _sti | _plus_r },
        { 0xdde1, 0, 0 },
        { ASM_END }
];
PTRNTAB1[3]  aptb1FUCOMP = /* FUCOMP */ [
        { 0xdde8, 0, _sti | _plus_r },
        { 0xdde9, 0, 0 },
        { ASM_END }
];
PTRNTAB1[3]  aptb1FXCH = /* FXCH */ [
        { 0xd9c8, 0, _sti | _plus_r },
        { 0xd9c9, 0, 0 },
        { ASM_END }
];
//
// Floating point instructions which have entirely different flag
// interpretations but they overlap, only asm_determine_operator
// flags needs to know the difference
//      2 operand floating point instructions follow
//
PTRNTAB2[6]  aptb2FADD = /* FADD */ [
        { 0xd8, _0, _m32, 0 },
        { 0xdc, _0, _fm64, 0 },
        { 0xd8c0, 0, _st, _sti | _plus_r },
        { 0xdcc0, 0, _sti | _plus_r, _st },
        { 0xdec1, 0, 0, 0 },
        { ASM_END }
];

PTRNTAB2[3]  aptb2FADDP = /* FADDP */ [
        { 0xdec0, 0, _sti | _plus_r, _st },
        { 0xdec1, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FIADD = /* FIADD */ [
        { 0xda, _0, _m32, 0 },
        { 0xde, _0, _m16, 0 },
        { ASM_END }
];
PTRNTAB2[6]  aptb2FDIV = /* FDIV */ [
        { 0xd8, _6, _m32, 0 },
        { 0xdc, _6, _fm64, 0 },
        { 0xd8f0, 0, _st, _sti | _plus_r },
        { 0xdcf8, 0, _sti | _plus_r, _st },
        { 0xdef9, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FDIVP = /* FDIVP */ [
        { 0xdef9, 0, 0, 0 },
        { 0xdef8, 0, _sti | _plus_r, _st },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FIDIV = /* FIDIV */ [
        { 0xda, _6,  _m32, 0 },
        { 0xde, _6,  _m16, 0 },
        { ASM_END }
];
PTRNTAB2[6]  aptb2FDIVR = /* FDIVR */ [
        { 0xd8, _7, _m32, 0 },
        { 0xdc, _7, _fm64, 0 },
        { 0xd8f8, 0, _st, _sti | _plus_r },
        { 0xdcf0, 0, _sti | _plus_r, _st },
        { 0xdef1, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FDIVRP = /* FDIVRP */ [
        { 0xdef1, 0, 0, 0 },
        { 0xdef0, 0, _sti | _plus_r, _st },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FIDIVR = /* FIDIVR */ [
        { 0xda, _7,  _m32, 0 },
        { 0xde, _7,  _m16, 0 },
        { ASM_END }
];
PTRNTAB2[6]  aptb2FMUL = /* FMUL */ [
        { 0xd8, _1, _m32, 0 },
        { 0xdc, _1, _fm64, 0 },
        { 0xd8c8, 0, _st, _sti | _plus_r },
        { 0xdcc8, 0, _sti | _plus_r, _st },
        { 0xdec9, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FMULP = /* FMULP */ [
        { 0xdec8, 0, _sti | _plus_r, _st },
        { 0xdec9, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FIMUL = /* FIMUL */ [
        { 0xda, _1, _m32, 0 },
        { 0xde, _1, _m16, 0 },
        { ASM_END }
];
PTRNTAB2[6]  aptb2FSUB = /* FSUB */ [
        { 0xd8, _4, _m32, 0 },
        { 0xdc, _4, _fm64, 0 },
        { 0xd8e0, 0, _st, _sti | _plus_r },
        { 0xdce8, 0, _sti | _plus_r, _st },
        { 0xdee9, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FSUBP = /* FSUBP */ [
        { 0xdee8, 0, _sti | _plus_r, _st },
        { 0xdee9, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FISUB = /* FISUB */ [
        { 0xda, _4, _m32, 0 },
        { 0xde, _4, _m16, 0 },
        { ASM_END }
];
PTRNTAB2[6]  aptb2FSUBR = /* FSUBR */ [
        { 0xd8, _5, _m32, 0 },
        { 0xdc, _5, _fm64, 0 },
        { 0xd8e8, 0, _st, _sti | _plus_r },
        { 0xdce0, 0, _sti | _plus_r, _st },
        { 0xdee1, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FSUBRP = /* FSUBRP */ [
        { 0xdee0, 0, _sti | _plus_r, _st },
        { 0xdee1, 0, 0, 0 },
        { ASM_END }
];
PTRNTAB2[3]  aptb2FISUBR = /* FISUBR */ [
        { 0xda, _5, _m32, 0 },
        { 0xde, _5, _m16, 0 },
        { ASM_END }
];

///////////////////////////// MMX Extensions /////////////////////////

PTRNTAB0[1] aptb0EMMS = /* EMMS */ [
        { 0x0F77, 0 }
];

PTRNTAB2[5] aptb2MOVD = /* MOVD */ [
        { 0x0F6E,_r,_mm,_rm32 },
        { 0x0F7E,_r,_rm32,_mm },
        { LODD,_r,_xmm,_rm32 },
        { STOD,_r,_rm32,_xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVD = /* VMOVD */ [
        { VEX_128_WIG(LODD), _r, _xmm, _rm32 },
        { VEX_128_WIG(STOD), _r, _rm32, _xmm },
        { ASM_END }
];

PTRNTAB2[9] aptb2MOVQ = /* MOVQ */ [
        { 0x0F6F,_r,_mm,_mmm64 },
        { 0x0F7F,_r,_mmm64,_mm },
        { LODQ,_r,_xmm,_xmm_m64 },
        { STOQ,_r,_xmm_m64,_xmm },
        { 0x0F6E,  _r|_64_bit,_mm,  _rm64 },
        { 0x0F7E,  _r|_64_bit,_rm64,_mm   },
        { LODD,_r|_64_bit,_xmm, _rm64 },
        { STOD,_r|_64_bit,_rm64,_xmm  },
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVQ = /* VMOVQ */ [
        { VEX_128_W1(LODD), _r, _xmm, _rm64 },
        { VEX_128_W1(STOD), _r, _rm64, _xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2PACKSSDW = /* PACKSSDW */ [
        { 0x0F6B, _r,_mm,_mmm64 },
        { PACKSSDW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPACKSSDW = /* VPACKSSDW */ [
        { VEX_NDS_128_WIG(PACKSSDW), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PACKSSWB = /* PACKSSWB */ [
        { 0x0F63, _r,_mm,_mmm64 },
        { PACKSSWB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPACKSSWB = /* VPACKSSWB */ [
        { VEX_NDS_128_WIG(PACKSSWB), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PACKUSWB = /* PACKUSWB */ [
        { 0x0F67, _r,_mm,_mmm64 },
        { PACKUSWB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPACKUSWB = /* VPACKUSWB */ [
        { VEX_NDS_128_WIG(PACKUSWB), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PADDB = /* PADDB */ [
        { 0x0FFC, _r,_mm,_mmm64 },
        { PADDB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPADDB = /* VPADDB */ [
        { VEX_NDS_128_WIG(PADDB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PADDD = /* PADDD */ [
        { 0x0FFE, _r,_mm,_mmm64 },
        { PADDD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPADDD = /* VPADDD */ [
        { VEX_NDS_128_WIG(PADDD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PADDSB = /* PADDSB */ [
        { 0x0FEC, _r,_mm,_mmm64 },
        { PADDSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPADDSB = /* VPADDSB */ [
        { VEX_NDS_128_WIG(PADDSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PADDSW = /* PADDSW */ [
        { 0x0FED, _r,_mm,_mmm64 },
        { PADDSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPADDSW = /* VPADDSW */ [
        { VEX_NDS_128_WIG(PADDSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PADDUSB = /* PADDUSB */ [
        { 0x0FDC, _r,_mm,_mmm64 },
        { PADDUSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPADDUSB = /* VPADDUSB */ [
        { VEX_NDS_128_WIG(PADDUSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PADDUSW = /* PADDUSW */ [
        { 0x0FDD, _r,_mm,_mmm64 },
        { PADDUSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPADDUSW = /* VPADDUSW */ [
        { VEX_NDS_128_WIG(PADDUSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PADDW = /* PADDW */ [
        { 0x0FFD, _r,_mm,_mmm64 },
        { PADDW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPADDW = /* VPADDW */ [
        { VEX_NDS_128_WIG(PADDW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PAND = /* PAND */ [
        { 0x0FDB, _r,_mm,_mmm64 },
        { PAND, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPAND = /* VPAND */ [
        { VEX_NDS_128_WIG(PAND), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PANDN = /* PANDN */ [
        { 0x0FDF, _r,_mm,_mmm64 },
        { PANDN, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPANDN = /* VPANDN */ [
        { VEX_NDS_128_WIG(PANDN), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PCMPEQB = /* PCMPEQB */ [
        { 0x0F74, _r,_mm,_mmm64 },
        { PCMPEQB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPEQB = /* VPCMPEQB */ [
        { VEX_NDS_128_WIG(PCMPEQB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PCMPEQD = /* PCMPEQD */ [
        { 0x0F76, _r,_mm,_mmm64 },
        { PCMPEQD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPEQD = /* VPCMPEQD */ [
        { VEX_NDS_128_WIG(PCMPEQD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PCMPEQW = /* PCMPEQW */ [
        { 0x0F75, _r,_mm,_mmm64 },
        { PCMPEQW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPEQW = /* VPCMPEQW */ [
        { VEX_NDS_128_WIG(PCMPEQW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PCMPGTB = /* PCMPGTB */ [
        { 0x0F64, _r,_mm,_mmm64 },
        { PCMPGTB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPGTB = /* VPCMPGTB */ [
        { VEX_NDS_128_WIG(PCMPGTB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PCMPGTD = /* PCMPGTD */ [
        { 0x0F66, _r,_mm,_mmm64 },
        { PCMPGTD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPGTD = /* VPCMPGTD */ [
        { VEX_NDS_128_WIG(PCMPGTD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PCMPGTW = /* PCMPGTW */ [
        { 0x0F65, _r,_mm,_mmm64 },
        { PCMPGTW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPGTW = /* VPCMPGTW */ [
        { VEX_NDS_128_WIG(PCMPGTW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMADDWD = /* PMADDWD */ [
        { 0x0FF5, _r,_mm,_mmm64 },
        { PMADDWD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMADDWD = /* VPMADDWD */ [
        { VEX_NDS_128_WIG(PMADDWD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[5] aptb2PSLLW = /* PSLLW */ [
        { 0x0FF1, _r,_mm,_mmm64 },
        { 0x0F71, _6,_mm,_imm8 },
        { PSLLW, _r,_xmm,_xmm_m128 },
        { 0x660F71, _6,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VPSLLW = /* VPSLLW */ [
        { VEX_NDS_128_WIG(PSLLW), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F71), _6, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[5] aptb2PSLLD = /* PSLLD */ [
        { 0x0FF2, _r,_mm,_mmm64 },
        { 0x0F72, _6,_mm,_imm8 },
        { PSLLD, _r,_xmm,_xmm_m128 },
        { 0x660F72, _6,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VPSLLD = /* VPSLLD */ [
        { VEX_NDS_128_WIG(PSLLD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F72), _6, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[5] aptb2PSLLQ = /* PSLLQ */ [
        { 0x0FF3, _r,_mm,_mmm64 },
        { 0x0F73, _6,_mm,_imm8 },
        { PSLLQ, _r,_xmm,_xmm_m128 },
        { PSLLDQ & 0xFFFFFF, _6,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VPSLLQ = /* VPSLLQ */ [
        { VEX_NDS_128_WIG(PSLLQ), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG((PSLLDQ & 0xFFFFFF)), _6, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[5] aptb2PSRAW = /* PSRAW */ [
        { 0x0FE1, _r,_mm,_mmm64 },
        { 0x0F71, _4,_mm,_imm8 },
        { PSRAW, _r,_xmm,_xmm_m128 },
        { 0x660F71, _4,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VPSRAW = /* VPSRAW */ [
        { VEX_NDS_128_WIG(PSRAW), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F71), _4, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[5] aptb2PSRAD = /* PSRAD */ [
        { 0x0FE2, _r,_mm,_mmm64 },
        { 0x0F72, _4,_mm,_imm8 },
        { PSRAD, _r,_xmm,_xmm_m128 },
        { 0x660F72, _4,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VPSRAD = /* VPSRAD */ [
        { VEX_NDS_128_WIG(PSRAD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F72), _4, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[5] aptb2PSRLW = /* PSRLW */ [
        { 0x0FD1, _r,_mm,_mmm64 },
        { 0x0F71, _2,_mm,_imm8 },
        { PSRLW, _r,_xmm,_xmm_m128 },
        { 0x660F71, _2,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VPSRLW = /* VPSRLW */ [
        { VEX_NDS_128_WIG(PSRLW), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F71), _2, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[5] aptb2PSRLD = /* PSRLD */ [
        { 0x0FD2, _r,_mm,_mmm64 },
        { 0x0F72, _2,_mm,_imm8 },
        { PSRLD, _r,_xmm,_xmm_m128 },
        { 0x660F72, _2,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VPSRLD = /* VPSRLD */ [
        { VEX_NDS_128_WIG(PSRLD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG(0x660F72), _2, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[5] aptb2PSRLQ = /* PSRLQ */ [
        { 0x0FD3, _r,_mm,_mmm64 },
        { 0x0F73, _2,_mm,_imm8 },
        { PSRLQ, _r,_xmm,_xmm_m128 },
        { (PSLLDQ & 0xFFFFFF), _2,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VPSRLQ = /* VPSRLQ */ [
        { VEX_NDS_128_WIG(PSRLQ), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDD_128_WIG((PSLLDQ & 0xFFFFFF)), _2, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSUBB = /* PSUBB */ [
        { 0x0FF8, _r,_mm,_mmm64 },
        { PSUBB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSUBB = /* VPSUBB */ [
        { VEX_NDS_128_WIG(PSUBB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSUBD = /* PSUBD */ [
        { 0x0FFA, _r,_mm,_mmm64 },
        { PSUBD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSUBD = /* VPSUBD */ [
        { VEX_NDS_128_WIG(PSUBD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSUBSB = /* PSUBSB */ [
        { 0x0FE8, _r,_mm,_mmm64 },
        { PSUBSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSUBSB  = /* VPSUBSB  */ [
        { VEX_NDS_128_WIG(PSUBSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSUBSW = /* PSUBSW */ [
        { 0x0FE9, _r,_mm,_mmm64 },
        { PSUBSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSUBSW = /* VPSUBSW */ [
        { VEX_NDS_128_WIG(PSUBSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSUBUSB = /* PSUBUSB */ [
        { 0x0FD8, _r,_mm,_mmm64 },
        { PSUBUSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSUBUSB = /* VPSUBUSB */ [
        { VEX_NDS_128_WIG(PSUBUSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSUBUSW = /* PSUBUSW */ [
        { 0x0FD9, _r,_mm,_mmm64 },
        { PSUBUSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSUBUSW = /* VPSUBUSW */ [
        { VEX_NDS_128_WIG(PSUBUSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];


PTRNTAB2[3] aptb2PSUBW = /* PSUBW */ [
        { 0x0FF9, _r,_mm,_mmm64 },
        { PSUBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSUBW = /* VPSUBW */ [
        { VEX_NDS_128_WIG(PSUBW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PUNPCKHBW = /* PUNPCKHBW */ [
        { 0x0F68, _r,_mm,_mmm64 },
        { PUNPCKHBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPUNPCKHBW = /* VPUNPCKHBW */ [
        { VEX_NDS_128_WIG(PUNPCKHBW), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PUNPCKHDQ = /* PUNPCKHDQ */ [
        { 0x0F6A, _r,_mm,_mmm64 },
        { PUNPCKHDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPUNPCKHDQ = /* VPUNPCKHDQ */ [
        { VEX_NDS_128_WIG(PUNPCKHDQ), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PUNPCKHWD = /* PUNPCKHWD */ [
        { 0x0F69, _r,_mm,_mmm64 },
        { PUNPCKHWD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPUNPCKHWD = /* VPUNPCKHWD */ [
        { VEX_NDS_128_WIG(PUNPCKHWD), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PUNPCKLBW = /* PUNPCKLBW */ [
        { 0x0F60, _r,_mm,_mmm64 },
        { PUNPCKLBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPUNPCKLBW = /* VPUNPCKLBW */ [
        { VEX_NDS_128_WIG(PUNPCKLBW), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PUNPCKLDQ = /* PUNPCKLDQ */ [
        { 0x0F62, _r,_mm,_mmm64 },
        { PUNPCKLDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPUNPCKLDQ = /* VPUNPCKLDQ */ [
        { VEX_NDS_128_WIG(PUNPCKLDQ), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PUNPCKLWD = /* PUNPCKLWD */ [
        { 0x0F61, _r,_mm,_mmm64 },
        { PUNPCKLWD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPUNPCKLWD = /* VPUNPCKLWD */ [
        { VEX_NDS_128_WIG(PUNPCKLWD), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PXOR = /* PXOR */ [
        { 0x0FEF, _r,_mm,_mmm64 },
        { PXOR, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPXOR = /* VPXOR */ [
        { VEX_NDS_128_WIG(PXOR), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

////////////////////// New Opcodes /////////////////////////////

PTRNTAB0[1] aptb0PAUSE =  /* PAUSE */ [
        { PAUSE, 0 }            // same as REP NOP sequene
];

PTRNTAB0[1] aptb0SYSCALL =  /* SYSCALL */ [
        { 0x0f05, _modcxr11 }
];

PTRNTAB0[1] aptb0SYSRET =  /* SYSRET */ [
        { 0x0f07, 0 }
];

PTRNTAB0[1] aptb0SYSENTER =  /* SYSENTER */ [
        { 0x0f34, 0 }
];

PTRNTAB0[1] aptb0SYSEXIT =  /* SYSEXIT */ [
        { 0x0f35, 0 }
];

PTRNTAB0[1] aptb0UD2 =  /* UD2 */ [
        { 0x0f0b, 0 }
];

PTRNTAB0[1] aptb0LFENCE = /* LFENCE */ [
        { 0x0FAEE8,     0 }
];

PTRNTAB0[1] aptb0MFENCE = /* MFENCE */ [
        { 0x0FAEF0,     0 }
];

PTRNTAB0[1] aptb0SFENCE = /* SFENCE */ [
        { 0x0FAEF8,     0 }
];

PTRNTAB1[2]  aptb1FXSAVE = /* FXSAVE */ [
        { 0x0FAE, _0, _m512 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1FXRSTOR = /* FXRSTOR */ [
        { 0x0FAE, _1, _m512 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1LDMXCSR = /* LDMXCSR */ [
        { 0x0FAE, _2, _m32 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1VLDMXCSR = /* VLDMXCSR */ [
        { VEX_128_WIG(0x0FAE), _2, _m32 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1STMXCSR = /* STMXCSR */ [
        { 0x0FAE, _3, _m32 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1VSTMXCSR = /* VSTMXCSR */ [
        { VEX_128_WIG(0x0FAE), _3, _m32 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1CLFLUSH = /* CLFLUSH */ [
        { 0x0FAE, _7, _m8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2ADDPS = /* ADDPS */ [
        { ADDPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VADDPS = /* VADDPS */ [
        { VEX_NDS_128_WIG(ADDPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(ADDPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
];

PTRNTAB2[2] aptb2ADDPD = /* ADDPD */ [
        { ADDPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VADDPD = /* VADDPD */ [
        { VEX_NDS_128_WIG(ADDPD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(ADDPD), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2ADDSD = /* ADDSD */ [
        { ADDSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VADDSD = /* VADDSD */ [
        { VEX_NDS_128_WIG(ADDSD), _r, _xmm, _xmm, _xmm_m64, },
        { ASM_END }
];

PTRNTAB2[2] aptb2ADDSS = /* ADDSS */ [
        { ADDSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VADDSS = /* VADDSS */ [
        { VEX_NDS_128_WIG(ADDSS), _r, _xmm, _xmm, _xmm_m32, },
        { ASM_END }
];

PTRNTAB2[2] aptb2ANDPD = /* ANDPD */ [
        { ANDPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VANDPD = /* VANDPD */ [
        { VEX_NDS_128_WIG(ANDPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ANDPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2ANDPS = /* ANDPS */ [
        { ANDPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VANDPS = /* VANDPS */ [
        { VEX_NDS_128_WIG(ANDPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ANDPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2ANDNPD = /* ANDNPD */ [
        { ANDNPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VANDNPD = /* VANDNPD */ [
        { VEX_NDS_128_WIG(ANDNPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ANDNPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2ANDNPS = /* ANDNPS */ [
        { ANDNPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VANDNPS = /* VANDNPS */ [
        { VEX_NDS_128_WIG(ANDNPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ANDNPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB3[2] aptb3CMPPS = /* CMPPS */ [
        { CMPPS, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB4[3] aptb4VCMPPS = /* VCMPPS */ [
        { VEX_NDS_128_WIG(CMPPS), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(CMPPS), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3CMPPD = /* CMPPD */ [
        { CMPPD, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB4[3] aptb4VCMPPD = /* VCMPPD */ [
        { VEX_NDS_128_WIG(CMPPD), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(CMPPD), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3CMPSD = /* CMPSD */ [
        { 0xa7, _32_bit | _I386 | _modsidi },
        { CMPSD, _r,_xmm,_xmm_m64,_imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VCMPSD = /* VCMPSD */ [
        { VEX_NDS_128_WIG(CMPSD), _r, _xmm, _xmm, _xmm_m64, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3CMPSS = /* CMPSS */ [
        { CMPSS, _r,_xmm,_xmm_m32,_imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VCMPSS = /* VCMPSS */ [
        { VEX_NDS_128_WIG(CMPSS), _r, _xmm, _xmm, _xmm_m32, _imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2COMISD = /* COMISD */ [
        { COMISD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VCOMISD = /* VCOMISD */ [
        { VEX_128_WIG(COMISD), _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2COMISS = /* COMISS */ [
        { COMISS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VCOMISS = /* VCOMISS */ [
        { VEX_128_WIG(COMISS), _r, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTDQ2PD = /* CVTDQ2PD */ [
        { CVTDQ2PD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTDQ2PD = /* VCVTDQ2PD */ [
        { VEX_128_WIG(CVTDQ2PD), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTDQ2PD), _r, _ymm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTDQ2PS = /* CVTDQ2PS */ [
        { CVTDQ2PS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTDQ2PS = /* VCVTDQ2PS */ [
        { VEX_128_WIG(CVTDQ2PS), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTDQ2PS), _r, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTPD2DQ = /* CVTPD2DQ */ [
        { CVTPD2DQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTPD2DQ = /* VCVTPD2DQ */ [
        { VEX_128_WIG(CVTPD2DQ), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTPD2DQ), _r, _xmm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTPD2PI = /* CVTPD2PI */ [
        { CVTPD2PI, _r,_mm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTPD2PS = /* CVTPD2PS */ [
        { CVTPD2PS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTPD2PS = /* VCVTPD2PS */ [
        { VEX_128_WIG(CVTPD2PS), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTPD2PS), _r, _xmm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTPI2PD = /* CVTPI2PD */ [
        { CVTPI2PD, _r,_xmm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTPI2PS = /* CVTPI2PS */ [
        { CVTPI2PS, _r,_xmm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTPS2DQ = /* CVTPS2DQ */ [
        { CVTPS2DQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTPS2DQ = /* VCVTPS2DQ */ [
        { VEX_128_WIG(CVTPS2DQ), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTPS2DQ), _r, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTPS2PD = /* CVTPS2PD */ [
        { CVTPS2PD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTPS2PD = /* VCVTPS2PD */ [
        { VEX_128_WIG(CVTPS2PD), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTPS2PD), _r, _ymm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTPS2PI = /* CVTPS2PI */ [
        { CVTPS2PI, _r,_mm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTSD2SI = /* CVTSD2SI */ [
        { CVTSD2SI, _r,_r32,_xmm_m64 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTSD2SI = /* VCVTSD2SI */ [
        { VEX_128_WIG(CVTSD2SI), _r, _r32, _xmm_m64 },
        { VEX_128_W1(CVTSD2SI), _r, _r64, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTSD2SS = /* CVTSD2SS */ [
        { CVTSD2SS, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VCVTSD2SS = /* VCVTSD2SS */ [
        { VEX_NDS_128_WIG(CVTSD2SS), _r, _xmm, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTSI2SD = /* CVTSI2SD */ [
        { CVTSI2SD, _r,_xmm,_rm32 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VCVTSI2SD = /* VCVTSI2SD */ [
        { VEX_NDS_128_WIG(CVTSI2SD), _r, _xmm, _xmm, _rm32 },
        { VEX_NDS_128_W1(CVTSI2SD), _r, _xmm, _xmm, _rm64 }, // implicit REX_W
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTSI2SS = /* CVTSI2SS */ [
        { CVTSI2SS, _r,_xmm,_rm32 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VCVTSI2SS = /* VCVTSI2SS */ [
        { VEX_NDS_128_WIG(CVTSI2SS), _r, _xmm, _xmm, _rm32 },
        { VEX_NDS_128_W1(CVTSI2SS), _r, _xmm, _xmm, _rm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTSS2SD = /* CVTSS2SD */ [
        { CVTSS2SD, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VCVTSS2SD = /* VCVTSS2SD */ [
        { VEX_NDS_128_WIG(CVTSS2SD), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTSS2SI = /* CVTSS2SI */ [
        { CVTSS2SI, _r,_r32,_xmm_m32 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTSS2SI = /* VCVTSS2SI */ [
        { VEX_128_WIG(CVTSS2SI), _r, _r32, _xmm_m32 },
        { VEX_128_W1(CVTSS2SI), _r, _r64, _xmm_m32 }, // implicit REX_W
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTTPD2PI = /* CVTTPD2PI */ [
        { CVTTPD2PI, _r,_mm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTTPD2DQ = /* CVTTPD2DQ */ [
        { CVTTPD2DQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTTPD2DQ = /* VCVTTPD2DQ */ [
        { VEX_128_WIG(CVTTPD2DQ), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTTPD2DQ), _r, _xmm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTTPS2DQ = /* CVTTPS2DQ */ [
        { CVTTPS2DQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTTPS2DQ = /* VCVTTPS2DQ */ [
        { VEX_128_WIG(CVTTPS2DQ), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(CVTTPS2DQ), _r, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTTPS2PI = /* CVTTPS2PI */ [
        { CVTTPS2PI, _r,_mm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTTSD2SI = /* CVTTSD2SI */ [
        { CVTTSD2SI, _r,_r32,_xmm_m64 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTTSD2SI = /* VCVTTSD2SI */ [
        { VEX_128_WIG(CVTTSD2SI), _r, _r32, _xmm_m64 },
        { VEX_128_W1(CVTTSD2SI), _r, _r64, _xmm_m64 }, // implicit REX_W
        { ASM_END }
];

PTRNTAB2[2] aptb2CVTTSS2SI = /* CVTTSS2SI */ [
        { CVTTSS2SI, _r,_r32,_xmm_m32 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VCVTTSS2SI = /* VCVTTSS2SI */ [
        { VEX_128_WIG(CVTTSS2SI), _r, _r32, _xmm_m64 },
        { VEX_128_W1(CVTTSS2SI), _r, _r64, _xmm_m64 }, // implicit REX_W
        { ASM_END }
];

PTRNTAB2[2] aptb2DIVPD = /* DIVPD */ [
        { DIVPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VDIVPD  = /* VDIVPD  */ [
        { VEX_NDS_128_WIG(DIVPD), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(DIVPD), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
];

PTRNTAB2[2] aptb2DIVPS = /* DIVPS */ [
        { DIVPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VDIVPS  = /* VDIVPS  */ [
        { VEX_NDS_128_WIG(DIVPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(DIVPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
];

PTRNTAB2[2] aptb2DIVSD = /* DIVSD */ [
        { DIVSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VDIVSD  = /* VDIVSD  */ [
        { VEX_NDS_128_WIG(DIVSD), _r, _xmm, _xmm, _xmm_m64, },
        { ASM_END }
];

PTRNTAB2[2] aptb2DIVSS = /* DIVSS */ [
        { DIVSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VDIVSS  = /* VDIVSS  */ [
        { VEX_NDS_128_WIG(DIVSS), _r, _xmm, _xmm, _xmm_m32, },
        { ASM_END }
];

PTRNTAB2[2] aptb2MASKMOVDQU = /* MASKMOVDQU */ [
        { MASKMOVDQU, _r,_xmm,_xmm },
        { ASM_END }
];

PTRNTAB2[2] aptb2VMASKMOVDQU = /* VMASKMOVDQU */ [
        { VEX_128_WIG(MASKMOVDQU), _r, _xmm, _xmm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MASKMOVQ = /* MASKMOVQ */ [
        { MASKMOVQ, _r,_mm,_mm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MAXPD = /* MAXPD */ [
        { MAXPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMAXPD = /* VMAXPD */ [
        { VEX_NDS_128_WIG(MAXPD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(MAXPD), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MAXPS = /* MAXPS */ [
        { MAXPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMAXPS = /* VMAXPS */ [
        { VEX_NDS_128_WIG(MAXPS), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(MAXPS), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MAXSD = /* MAXSD */ [
        { MAXSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VMAXSD = /* VMAXSD */ [
        { VEX_NDS_128_WIG(MAXSD), _r, _xmm, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MAXSS = /* MAXSS */ [
        { MAXSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VMAXSS = /* VMAXSS */ [
        { VEX_NDS_128_WIG(MAXSS), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MINPD = /* MINPD */ [
        { MINPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMINPD = /* VMINPD */ [
        { VEX_NDS_128_WIG(MINPD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(MINPD), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MINPS = /* MINPS */ [
        { MINPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMINPS = /* VMINPS */ [
        { VEX_NDS_128_WIG(MINPS), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(MINPS), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MINSD = /* MINSD */ [
        { MINSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VMINSD = /* VMINSD */ [
        { VEX_NDS_128_WIG(MINSD), _r, _xmm, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MINSS = /* MINSS */ [
        { MINSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VMINSS = /* VMINSS */ [
        { VEX_NDS_128_WIG(MINSS), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVAPD = /* MOVAPD */ [
        { LODAPD, _r,_xmm,_xmm_m128 },
        { STOAPD, _r,_xmm_m128,_xmm },
        { ASM_END }
];

PTRNTAB2[5] aptb2VMOVAPD = /* VMOVAPD */ [
        { VEX_128_WIG(LODAPD), _r, _xmm, _xmm_m128 },
        { VEX_128_WIG(STOAPD), _r, _xmm_m128, _xmm },
        { VEX_256_WIG(LODAPD), _r, _ymm, _ymm_m256 },
        { VEX_256_WIG(STOAPD), _r, _ymm_m256, _ymm },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVAPS = /* MOVAPS */ [
        { LODAPS, _r,_xmm,_xmm_m128 },
        { STOAPS, _r,_xmm_m128,_xmm },
        { ASM_END }
];

PTRNTAB2[5] aptb2VMOVAPS  = /* VMOVAPS */ [
        { VEX_128_WIG(LODAPS), _r, _xmm, _xmm_m128, },
        { VEX_128_WIG(STOAPS), _r, _xmm_m128, _xmm, },
        { VEX_256_WIG(LODAPS), _r, _ymm, _ymm_m256, },
        { VEX_256_WIG(STOAPS), _r, _ymm_m256, _ymm, },
        { ASM_END },
];

PTRNTAB2[3] aptb2MOVDQA = /* MOVDQA */ [
        { LODDQA, _r,_xmm,_xmm_m128 },
        { STODQA, _r,_xmm_m128,_xmm },
        { ASM_END }
];

PTRNTAB2[5] aptb2VMOVDQA = /* VMOVDQA */ [
        { VEX_128_WIG(LODDQA), _r, _xmm, _xmm_m128 },
        { VEX_128_WIG(STODQA), _r, _xmm_m128, _xmm },
        { VEX_256_WIG(LODDQA), _r, _ymm, _ymm_m256 },
        { VEX_256_WIG(STODQA), _r, _ymm_m256, _ymm },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVDQU = /* MOVDQU */ [
        { LODDQU, _r,_xmm,_xmm_m128 },
        { STODQU, _r,_xmm_m128,_xmm },
        { ASM_END }
];

PTRNTAB2[5] aptb2VMOVDQU = /* VMOVDQU */ [
        { VEX_128_WIG(LODDQU), _r, _xmm, _xmm_m128 },
        { VEX_128_WIG(STODQU), _r, _xmm_m128, _xmm },
        { VEX_256_WIG(LODDQU), _r, _ymm, _ymm_m256 },
        { VEX_256_WIG(STODQU), _r, _ymm_m256, _ymm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVDQ2Q = /* MOVDQ2Q */ [
        { MOVDQ2Q, _r,_mm,_xmm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVHLPS = /* MOVHLPS */ [
        { MOVHLPS, _r,_xmm,_xmm },
        { ASM_END }
];

PTRNTAB3[2] aptb3VMOVHLPS = /* VMOVHLPS */ [
        { VEX_NDS_128_WIG(MOVHLPS), _r, _xmm, _xmm, _xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVHPD = /* MOVHPD */ [
        { LODHPD, _r,_xmm,_xmm_m64 },
        { STOHPD, _r,_xmm_m64,_xmm },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMOVHPD = /* VMOVHPD */ [
        { VEX_NDS_128_WIG(LODHPD), _r, _xmm, _xmm, _m64 },
        { VEX_128_WIG(STOHPD), _r, _m64, _xmm, 0 },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVHPS = /* MOVHPS */ [
        { LODHPS, _r,_xmm,_xmm_m64 },
        { STOHPS, _r,_xmm_m64,_xmm },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMOVHPS = /* VMOVHPS */ [
        { VEX_NDS_128_WIG(LODHPS), _r, _xmm, _xmm, _m64 },
        { VEX_128_WIG(STOHPS), _r, _m64, _xmm, 0 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVLHPS = /* MOVLHPS */ [
        { MOVLHPS, _r,_xmm,_xmm },
        { ASM_END }
];

PTRNTAB3[2] aptb3VMOVLHPS = /* VMOVLHPS */ [
        { VEX_NDS_128_WIG(MOVLHPS), _r, _xmm, _xmm, _xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVLPD = /* MOVLPD */ [
        { LODLPD, _r,_xmm,_xmm_m64 },
        { STOLPD, _r,_xmm_m64,_xmm },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMOVLPD = /* VMOVLPD */ [
        { VEX_NDS_128_WIG(LODLPD), _r, _xmm, _xmm, _m64 },
        { VEX_128_WIG(STOLPD), _r, _m64, _xmm, 0 },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVLPS = /* MOVLPS */ [
        { LODLPS, _r,_xmm,_xmm_m64 },
        { STOLPS, _r,_xmm_m64,_xmm },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMOVLPS = /* VMOVLPS */ [
        { VEX_NDS_128_WIG(LODLPS), _r, _xmm, _xmm, _m64 },
        { VEX_128_WIG(STOLPS), _r, _m64, _xmm, 0 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVMSKPD = /* MOVMSKPD */ [
        { MOVMSKPD, _r,_r32,_xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVMSKPD  = /* VMOVMSKPD */ [
        { VEX_128_WIG(MOVMSKPD), _r, _r32, _xmm },
        { VEX_256_WIG(MOVMSKPD), _r, _r32, _ymm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVMSKPS = /* MOVMSKPS */ [
        { MOVMSKPS, _r,_r32,_xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVMSKPS  = /* VMOVMSKPS */ [
        { VEX_128_WIG(MOVMSKPS), _r, _r32, _xmm },
        { VEX_256_WIG(MOVMSKPS), _r, _r32, _ymm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVNTDQ = /* MOVNTDQ */ [
        { MOVNTDQ, _r,_m128,_xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVNTDQ = /* VMOVNTDQ */ [
        { VEX_128_WIG(MOVNTDQ), _r, _m128, _xmm },
        { VEX_256_WIG(MOVNTDQ), _r, _m256, _ymm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVNTI = /* MOVNTI */ [
        { MOVNTI, _r,_m32,_r32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVNTPD = /* MOVNTPD */ [
        { MOVNTPD, _r,_m128,_xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVNTPD = /* VMOVNTPD */ [
        { VEX_128_WIG(MOVNTPD), _r, _m128, _xmm },
        { VEX_256_WIG(MOVNTPD), _r, _m256, _ymm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVNTPS = /* MOVNTPS */ [
        { MOVNTPS, _r,_m128,_xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVNTPS = /* VMOVNTPS */ [
        { VEX_128_WIG(MOVNTPS), _r, _m128, _xmm },
        { VEX_256_WIG(MOVNTPS), _r, _m256, _ymm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVNTQ = /* MOVNTQ */ [
        { MOVNTQ, _r,_m64,_mm },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVQ2DQ = /* MOVQ2DQ */ [
        { MOVQ2DQ, _r,_xmm,_mm },
        { ASM_END }
];

PTRNTAB2[4] aptb2MOVSD =  /* MOVSD */ [
        { 0xa5, _32_bit | _I386 | _modsidi },
        { LODSD, _r, _xmm, _xmm_m64 },
        { STOSD, _r, _xmm_m64, _xmm },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMOVSD = /* VMOVSD */ [
        { VEX_NDS_128_WIG(LODSD), _r, _xmm, _xmm, _xmm },
        { VEX_128_WIG(STOSD), _r, _m64, _xmm, 0 },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVSS =  /* MOVSS */ [
        { LODSS, _r,_xmm,_xmm_m32 },
        { STOSS, _r,_xmm_m32,_xmm },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMOVSS = /* VMOVSS */ [
        { VEX_NDS_128_WIG(LODSS), _r, _xmm, _xmm, _xmm },
        { VEX_128_WIG(STOSS), _r, _m32, _xmm, 0 },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVUPD = /* MOVUPD */ [
        { LODUPD, _r,_xmm,_xmm_m128 },
        { STOUPD, _r,_xmm_m128,_xmm },
        { ASM_END }
];

PTRNTAB2[5] aptb2VMOVUPD = /* VMOVUPD */ [
        { VEX_128_WIG(LODUPD), _r, _xmm, _xmm_m128 },
        { VEX_128_WIG(STOUPD), _r, _xmm_m128, _xmm },
        { VEX_256_WIG(LODUPD), _r, _ymm, _ymm_m256 },
        { VEX_256_WIG(STOUPD), _r, _ymm_m256, _ymm },
        { ASM_END }
];

PTRNTAB2[3] aptb2MOVUPS = /* MOVUPS */ [
        { LODUPS, _r,_xmm,_xmm_m128 },
        { STOUPS, _r,_xmm_m128,_xmm },
        { ASM_END }
];

PTRNTAB2[5] aptb2VMOVUPS  = /* VMOVUPS */ [
        { VEX_128_WIG(LODUPS), _r, _xmm, _xmm_m128, },
        { VEX_128_WIG(STOUPS), _r, _xmm_m128, _xmm, },
        { VEX_256_WIG(LODUPS), _r, _ymm, _ymm_m256, },
        { VEX_256_WIG(STOUPS), _r, _ymm_m256, _ymm, },
        { ASM_END }
];

PTRNTAB2[2] aptb2MULPD = /* MULPD */ [
        { MULPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMULPD  = /* VMULPD  */ [
        { VEX_NDS_128_WIG(MULPD), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(MULPD), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
];

PTRNTAB2[2] aptb2MULPS = /* MULPS */ [
        { MULPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VMULPS  = /* VMULPS  */ [
        { VEX_NDS_128_WIG(MULPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(MULPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
];

PTRNTAB2[2] aptb2MULSD = /* MULSD */ [
        { MULSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VMULSD  = /* VMULSD  */ [
        { VEX_NDS_128_WIG(MULSD), _r, _xmm, _xmm, _xmm_m64, },
        { ASM_END }
];

PTRNTAB2[2] aptb2MULSS = /* MULSS */ [
        { MULSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VMULSS  = /* VMULSS  */ [
        { VEX_NDS_128_WIG(MULSS), _r, _xmm, _xmm, _xmm_m32, },
        { ASM_END }
];

PTRNTAB2[2] aptb2ORPD = /* ORPD */ [
        { ORPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VORPD = /* VORPD */ [
        { VEX_NDS_128_WIG(ORPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ORPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2ORPS = /* ORPS */ [
        { ORPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VORPS = /* VORPS */ [
        { VEX_NDS_128_WIG(ORPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(ORPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PADDQ = /* PADDQ */ [
        { 0x0FD4, _r,_mm,_mmm64 },
        { PADDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPADDQ = /* VPADDQ */ [
        { VEX_NDS_128_WIG(PADDQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PAVGB = /* PAVGB */ [
        { 0x0FE0, _r,_mm,_mmm64 },
        { PAVGB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPAVGB = /* VPAVGB */ [
        { VEX_NDS_128_WIG(PAVGB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PAVGW = /* PAVGW */ [
        { 0x0FE3, _r,_mm,_mmm64 },
        { PAVGW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPAVGW = /* VPAVGW */ [
        { VEX_NDS_128_WIG(PAVGW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[6] aptb3PEXTRW = /* PEXTRW */ [
        { 0x0FC5, _r,_r32,_mm,_imm8 },
        { 0x0FC5, _r,_r64,_mm,_imm8 },
        { 0x660FC5, _r,_r32,_xmm,_imm8 },
        { 0x660FC5, _r,_r64,_xmm,_imm8 },
        { 0x660F3A15, _r,_m16,_xmm,_imm8 },    // synonym for r32/r64
        { ASM_END }
];

PTRNTAB3[4] aptb3VPEXTRW = /* VPEXTRW */ [
        { VEX_128_WIG(0x660FC5), _r,_r32,_xmm,_imm8 },
        { VEX_128_WIG(0x660FC5), _r,_r64,_xmm,_imm8 },
        { VEX_128_WIG(0x660F3A15), _r,_m16,_xmm,_imm8 },    // synonym for r32/r64
        { ASM_END }
];

PTRNTAB3[3] aptb3PINSRW = /* PINSRW */ [
        { 0x0FC4, _r,_mm,_r32m16,_imm8 },
        { PINSRW, _r,_xmm,_r32m16,_imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VPINSRW = /* VPINSRW */ [
        { VEX_NDS_128_WIG(PINSRW), _r, _xmm, _xmm, _r32m16, _imm8 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMAXSW = /* PMAXSW */ [
        { 0x0FEE, _r,_mm,_mmm64 },
        { PMAXSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMAXSW = /* VPMAXSW */ [
        { VEX_NDS_128_WIG(PMAXSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMAXUB = /* PMAXUB */ [
        { 0x0FDE, _r,_mm,_mmm64 },
        { PMAXUB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMAXUB = /* VPMAXUB */ [
        { VEX_NDS_128_WIG(PMAXUB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMINSW = /* PMINSW */ [
        { 0x0FEA, _r,_mm,_mmm64 },
        { PMINSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMINSW = /* VPMINSW */ [
        { VEX_NDS_128_WIG(PMINSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMINUB = /* PMINUB */ [
        { 0x0FDA, _r,_mm,_mmm64 },
        { PMINUB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMINUB = /* VPMINUB */ [
        { VEX_NDS_128_WIG(PMINUB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[4] aptb2PMOVMSKB = /* PMOVMSKB */ [
        { 0x0FD7, _r,_r32,_mm },
        { PMOVMSKB, _r, _r32, _xmm },
        { PMOVMSKB, _r|_64_bit, _r64, _xmm },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVMSKB = /* VPMOVMSKB */ [
        { VEX_128_WIG(PMOVMSKB), _r, _r32, _xmm },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMULHUW = /* PMULHUW */ [
        { 0x0FE4, _r,_mm,_mmm64 },
        { PMULHUW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMULHUW = /* VPMULHUW */ [
        { VEX_NDS_128_WIG(PMULHUW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMULHW = /* PMULHW */ [
        { 0x0FE5, _r,_mm,_mmm64 },
        { PMULHW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMULHW = /* VPMULHW */ [
        { VEX_NDS_128_WIG(PMULHW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMULLW = /* PMULLW */ [
        { 0x0FD5, _r,_mm,_mmm64 },
        { PMULLW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMULLW = /* VPMULLW */ [
        { VEX_NDS_128_WIG(PMULLW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMULUDQ = /* PMULUDQ */ [
        { 0x0FF4, _r,_mm,_mmm64 },
        { PMULUDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMULUDQ = /* VPMULUDQ */ [
        { VEX_NDS_128_WIG(PMULUDQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2POR = /* POR */ [
        { 0x0FEB, _r,_mm,_mmm64 },
        { POR, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPOR = /* VPOR */ [
        { VEX_NDS_128_WIG(POR), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB1[2] aptb1PREFETCHNTA = /* PREFETCHNTA */ [
        { PREFETCH, _0,_m8 },
        { ASM_END }
];

PTRNTAB1[2] aptb1PREFETCHT0 = /* PREFETCHT0 */ [
        { PREFETCH, _1,_m8 },
        { ASM_END }
];

PTRNTAB1[2] aptb1PREFETCHT1 = /* PREFETCHT1 */ [
        { PREFETCH, _2,_m8 },
        { ASM_END }
];

PTRNTAB1[2] aptb1PREFETCHT2 = /* PREFETCHT2 */ [
        { PREFETCH, _3,_m8 },
        { ASM_END }
];

PTRNTAB1[2] aptb1PREFETCHW = /* PREFETCHW */ [
        { 0x0F0D, _1,_m8 },
        { ASM_END }
];

PTRNTAB1[2] aptb1PREFETCHWT1 = /* PREFETCHWT1 */ [
        { 0x0F0D, _2,_m8 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSADBW = /* PSADBW */ [
        { 0x0FF6, _r,_mm,_mmm64 },
        { PSADBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSADBW = /* VPSADBW */ [
        { VEX_NDS_128_WIG(PSADBW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];


PTRNTAB3[2] aptb3PSHUFD = /* PSHUFD */ [
        { PSHUFD, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSHUFD = /* VPSHUFD */ [
        { VEX_128_WIG(PSHUFD), _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PSHUFHW = /* PSHUFHW */ [
        { PSHUFHW, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSHUFHW = /* VPSHUFHW */ [
        { VEX_128_WIG(PSHUFHW), _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PSHUFLW = /* PSHUFLW */ [
        { PSHUFLW, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSHUFLW = /* VPSHUFLW */ [
        { VEX_128_WIG(PSHUFLW), _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PSHUFW = /* PSHUFW */ [
        { PSHUFW, _r,_mm,_mmm64,_imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PSLLDQ = /* PSLLDQ */ [
        { (PSLLDQ & 0xFFFFFF), _7,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSLLDQ = /* VPSLLDQ */ [
        { VEX_NDD_128_WIG((PSLLDQ & 0xFFFFFF)), _7, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PSRLDQ = /* PSRLDQ */ [
        { PSRLDQ & 0xFFFFFF, _3,_xmm,_imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSRLDQ = /* VPSRLDQ */ [
        { VEX_NDD_128_WIG((PSRLDQ & 0xFFFFFF)), _3, _xmm, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSUBQ = /* PSUBQ */ [
        { 0x0FFB, _r,_mm,_mmm64 },
        { PSUBQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSUBQ = /* VPSUBQ */ [
        { VEX_NDS_128_WIG(PSUBQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PUNPCKHQDQ = /* PUNPCKHQDQ */ [
        { PUNPCKHQDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPUNPCKHQDQ = /* VPUNPCKHQDQ */ [
        { VEX_NDS_128_WIG(PUNPCKHQDQ), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PUNPCKLQDQ = /* PUNPCKLQDQ */ [
        { PUNPCKLQDQ, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPUNPCKLQDQ = /* VPUNPCKLQDQ */ [
        { VEX_NDS_128_WIG(PUNPCKLQDQ), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2RCPPS = /* RCPPS */ [
        { RCPPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VRCPPS = /* VRCPPS */ [
        { VEX_128_WIG(RCPPS), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(RCPPS), _r, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2RCPSS = /* RCPSS */ [
        { RCPSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VRCPSS = /* VRCPSS */ [
        { VEX_NDS_128_WIG(RCPSS), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2RSQRTPS = /* RSQRTPS */ [
        { RSQRTPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2RSQRTSS = /* RSQRTSS */ [
        { RSQRTSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3SHUFPD = /* SHUFPD */ [
        { SHUFPD, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB4[3] aptb4VSHUFPD = /* VSHUFPD */ [
        { VEX_NDS_128_WIG(SHUFPD), _r,_xmm,_xmm,_xmm_m128,_imm8 },
        { VEX_NDS_256_WIG(SHUFPD), _r,_ymm,_ymm,_ymm_m256,_imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3SHUFPS = /* SHUFPS */ [
        { SHUFPS, _r,_xmm,_xmm_m128,_imm8 },
        { ASM_END }
];

PTRNTAB4[3] aptb4VSHUFPS = /* VSHUFPS */ [
        { VEX_NDS_128_WIG(SHUFPS), _r,_xmm,_xmm,_xmm_m128,_imm8 },
        { VEX_NDS_256_WIG(SHUFPS), _r,_ymm,_ymm,_ymm_m256,_imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SQRTPD = /* SQRTPD */ [
        { SQRTPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VSQRTPD = /* VSQRTPD */ [
        { VEX_128_WIG(SQRTPD), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(SQRTPD), _r, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SQRTPS = /* SQRTPS */ [
        { SQRTPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VSQRTPS = /* VSQRTPS */ [
        { VEX_128_WIG(SQRTPS), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(SQRTPS), _r, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SQRTSD = /* SQRTSD */ [
        { SQRTSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VSQRTSD = /* VSQRTSD */ [
        { VEX_NDS_128_WIG(SQRTSD), _r, _xmm, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SQRTSS = /* SQRTSS */ [
        { SQRTSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VSQRTSS = /* VSQRTSS */ [
        { VEX_NDS_128_WIG(SQRTSS), _r, _xmm, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SUBPD = /* SUBPD */ [
        { SUBPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VSUBPD  = /* VSUBPD  */ [
        { VEX_NDS_128_WIG(SUBPD), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(SUBPD), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
];

PTRNTAB2[2] aptb2SUBPS = /* SUBPS */ [
        { SUBPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VSUBPS  = /* VSUBPS  */ [
        { VEX_NDS_128_WIG(SUBPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(SUBPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
];

PTRNTAB2[2] aptb2SUBSD = /* SUBSD */ [
        { SUBSD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VSUBSD = /* VSUBSD */ [
        { VEX_NDS_128_WIG(SUBSD), _r, _xmm, _xmm, _xmm_m64, },
        { ASM_END }
];

PTRNTAB2[2] aptb2SUBSS = /* SUBSS */ [
        { SUBSS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VSUBSS = /* VSUBSS */ [
        { VEX_NDS_128_WIG(SUBSS), _r, _xmm, _xmm, _xmm_m32, },
        { ASM_END }
];

PTRNTAB2[2] aptb2UCOMISD = /* UCOMISD */ [
        { UCOMISD, _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VUCOMISD = /* VUCOMISD */ [
        { VEX_128_WIG(UCOMISD), _r,_xmm,_xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2UCOMISS = /* UCOMISS */ [
        { UCOMISS, _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VUCOMISS = /* VUCOMISS */ [
        { VEX_128_WIG(UCOMISS), _r,_xmm,_xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2UNPCKHPD = /* UNPCKHPD */ [
        { UNPCKHPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VUNPCKHPD = /* VUNPCKHPD */ [
        { VEX_NDS_128_WIG(UNPCKHPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(UNPCKHPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2UNPCKHPS = /* UNPCKHPS */ [
        { UNPCKHPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VUNPCKHPS = /* VUNPCKHPS */ [
        { VEX_NDS_128_WIG(UNPCKHPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(UNPCKHPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2UNPCKLPD = /* UNPCKLPD */ [
        { UNPCKLPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VUNPCKLPD = /* VUNPCKLPD */ [
        { VEX_NDS_128_WIG(UNPCKLPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(UNPCKLPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2UNPCKLPS = /* UNPCKLPS */ [
        { UNPCKLPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VUNPCKLPS = /* VUNPCKLPS */ [
        { VEX_NDS_128_WIG(UNPCKLPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(UNPCKLPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2XORPD = /* XORPD */ [
        { XORPD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VXORPD = /* VXORPD */ [
        { VEX_NDS_128_WIG(XORPD), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(XORPD), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2XORPS = /* XORPS */ [
        { XORPS, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VXORPS = /* VXORPS */ [
        { VEX_NDS_128_WIG(XORPS), _r,_xmm,_xmm,_xmm_m128 },
        { VEX_NDS_256_WIG(XORPS), _r,_ymm,_ymm,_ymm_m256 },
        { ASM_END }
];

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

PTRNTAB2[2] aptb2PAVGUSB = /* PAVGUSB */ [
        { 0x0F0FBF, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PF2ID = /* PF2ID */ [
        { 0x0F0F1D, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFACC = /* PFACC */ [
        { 0x0F0FAE, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFADD = /* PFADD */ [
        { 0x0F0F9E, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFCMPEQ = /* PFCMPEQ */ [
        { 0x0F0FB0, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFCMPGE = /* PFCMPGE */ [
        { 0x0F0F90, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFCMPGT = /* PFCMPGT */ [
        { 0x0F0FA0, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFMAX = /* PFMAX */ [
        { 0x0F0FA4, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFMIN = /* PFMIN */ [
        { 0x0F0F94, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFMUL = /* PFMUL */ [
        { 0x0F0FB4, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFNACC = /* PFNACC */ [
        { 0x0F0F8A, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFPNACC = /* PFPNACC */ [
        { 0x0F0F8E, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFRCP = /* PFRCP */ [
        { 0x0F0F96, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFRCPIT1 = /* PFRCPIT1 */ [
        { 0x0F0FA6, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFRCPIT2 = /* PFRCPIT2 */ [
        { 0x0F0FB6, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFRSQIT1 = /* PFRSQIT1 */ [
        { 0x0F0FA7, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFRSQRT = /* PFRSQRT */ [
        { 0x0F0F97, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFSUB = /* PFSUB */ [
        { 0x0F0F9A, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PFSUBR = /* PFSUBR */ [
        { 0x0F0FAA, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PI2FD = /* PI2FD */ [
        { 0x0F0F0D, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMULHRW = /* PMULHRW */ [
        { 0x0F0FB7, _r,_mm,_mmm64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PSWAPD = /* PSWAPD */ [
        { 0x0F0FBB, _r,_mm,_mmm64 },
        { ASM_END }
];

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

PTRNTAB1[4]  aptb1FISTTP = /* FISTTP */ [
        { 0xdf, _1, _m16 },
        { 0xdb, _1, _m32 },
        { 0xdd, _1, _fm64 },
        { ASM_END }
];

PTRNTAB0[1] aptb0MONITOR =  /* MONITOR */ [
        { MONITOR, 0 }
];

PTRNTAB0[1] aptb0MWAIT =  /* MWAIT */ [
        { MWAIT, 0 }
];

PTRNTAB2[2] aptb2ADDSUBPD = /* ADDSUBPD */ [
        { ADDSUBPD, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
];

PTRNTAB3[3]  aptb3VADDSUBPD = /* VADDSUBPD */ [
        { VEX_NDS_128_WIG(ADDSUBPD), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(ADDSUBPD), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
];

PTRNTAB2[2] aptb2ADDSUBPS = /* ADDSUBPS */ [
        { ADDSUBPS, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
];

PTRNTAB3[3]  aptb3VADDSUBPS = /* VADDSUBPS */ [
        { VEX_NDS_128_WIG(ADDSUBPS), _r, _xmm, _xmm, _xmm_m128, },
        { VEX_NDS_256_WIG(ADDSUBPS), _r, _ymm, _ymm, _ymm_m256, },
        { ASM_END }
];

PTRNTAB2[2] aptb2HADDPD = /* HADDPD */ [
        { HADDPD, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
];

PTRNTAB3[3] aptb3VHADDPD = /* VHADDPD */ [
        { VEX_NDS_128_WIG(HADDPD), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(HADDPD), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2HADDPS = /* HADDPS */ [
        { HADDPS, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
];

PTRNTAB3[3] aptb3VHADDPS = /* VHADDPS */ [
        { VEX_NDS_128_WIG(HADDPS), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(HADDPS), _r, _ymm, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2HSUBPD = /* HSUBPD */ [
        { HSUBPD, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
];

PTRNTAB2[2] aptb2HSUBPS = /* HSUBPS */ [
        { HSUBPS, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
];

PTRNTAB2[2] aptb2LDDQU = /* LDDQU */ [
        { LDDQU, _r,_xmm,_m128 },            // xmm1,mem
        { ASM_END }
];

PTRNTAB2[3] aptb2VLDDQU = /* VLDDQU */ [
        { VEX_128_WIG(LDDQU), _r, _xmm, _m128 },
        { VEX_256_WIG(LDDQU), _r, _ymm, _m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVDDUP = /* MOVDDUP */ [
        { MOVDDUP, _r,_xmm,_xmm_m64 },         // xmm1,xmm2/m64
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVDDUP = /* VMOVDDUP */ [
        { VEX_128_WIG(MOVDDUP), _r,_xmm,_xmm_m64 },
        { VEX_256_WIG(MOVDDUP), _r,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVSHDUP = /* MOVSHDUP */ [
        { MOVSHDUP, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVSHDUP = /* VMOVSHDUP */ [
        { VEX_128_WIG(MOVSHDUP), _r,_xmm,_xmm_m128 },
        { VEX_256_WIG(MOVSHDUP), _r,_ymm,_ymm_m256 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVSLDUP = /* MOVSLDUP */ [
        { MOVSLDUP, _r,_xmm,_xmm_m128 },        // xmm1,xmm2/m128
        { ASM_END }
];

PTRNTAB2[3] aptb2VMOVSLDUP = /* VMOVSLDUP */ [
        { VEX_128_WIG(MOVSLDUP), _r,_xmm,_xmm_m128 },
        { VEX_256_WIG(MOVSLDUP), _r,_ymm,_ymm_m256 },
        { ASM_END }
];

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

PTRNTAB3[3] aptb3PALIGNR = /* PALIGNR */ [
        { 0x0F3A0F, _r,_mm,_mmm64, _imm8 },
        { PALIGNR, _r,_xmm,_xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VPALIGNR = /* VPALIGNR */ [
        { VEX_NDS_128_WIG(PALIGNR), _r,_xmm,_xmm,_xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PHADDD = /* PHADDD */ [
        { 0x0F3802, _r,_mm,_mmm64 },
        { PHADDD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPHADDD = /* VPHADDD */ [
        { VEX_NDS_128_WIG(PHADDD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PHADDW = /* PHADDW */ [
        { 0x0F3801, _r,_mm,_mmm64 },
        { PHADDW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPHADDW = /* VPHADDW */ [
        { VEX_NDS_128_WIG(PHADDW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PHADDSW = /* PHADDSW */ [
        { 0x0F3803, _r,_mm,_mmm64 },
        { PHADDSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPHADDSW = /* VPHADDSW */ [
        { VEX_NDS_128_WIG(PHADDSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PHSUBD = /* PHSUBD */ [
        { 0x0F3806, _r,_mm,_mmm64 },
        { PHSUBD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPHSUBD = /* VPHSUBD */ [
        { VEX_NDS_128_WIG(PHSUBD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PHSUBW = /* PHSUBW */ [
        { 0x0F3805, _r,_mm,_mmm64 },
        { PHSUBW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPHSUBW = /* VPHSUBW */ [
        { VEX_NDS_128_WIG(PHSUBW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PHSUBSW = /* PHSUBSW */ [
        { 0x0F3807, _r,_mm,_mmm64 },
        { PHSUBSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPHSUBSW = /* VPHSUBSW */ [
        { VEX_NDS_128_WIG(PHSUBSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMADDUBSW = /* PMADDUBSW */ [
        { 0x0F3804, _r,_mm,_mmm64 },
        { PMADDUBSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMADDUBSW = /* VPMADDUBSW */ [
        { VEX_NDS_128_WIG(PMADDUBSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PMULHRSW = /* PMULHRSW */ [
        { 0x0F380B, _r,_mm,_mmm64 },
        { PMULHRSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMULHRSW = /* VPMULHRSW */ [
        { VEX_NDS_128_WIG(PMULHRSW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSHUFB = /* PSHUFB */ [
        { 0x0F3800, _r,_mm,_mmm64 },
        { PSHUFB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSHUFB = /* VPSHUFB */ [
        { VEX_NDS_128_WIG(PSHUFB), _r,_xmm,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PABSB = /* PABSB */ [
        { 0x0F381C, _r,_mm,_mmm64 },
        { PABSB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPABSB  = /* VPABSB */ [
        { VEX_128_WIG(PABSB), _r, _xmm, _xmm_m128 },
        { ASM_END }
];


PTRNTAB2[3] aptb2PABSD = /* PABSD */ [
        { 0x0F381E, _r,_mm,_mmm64 },
        { PABSD, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPABSD  = /* VPABSD  */ [
        { VEX_128_WIG(PABSD), _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PABSW = /* PABSW */ [
        { 0x0F381D, _r,_mm,_mmm64 },
        { PABSW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPABSW  = /* VPABSW */ [
        { VEX_128_WIG(PABSW), _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSIGNB = /* PSIGNB */ [
        { 0x0F3808, _r,_mm,_mmm64 },
        { PSIGNB, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSIGNB = /* VPSIGNB */ [
        { VEX_NDS_128_WIG(PSIGNB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSIGND = /* PSIGND */ [
        { 0x0F380A, _r,_mm,_mmm64 },
        { PSIGND, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSIGND = /* VPSIGND */ [
        { VEX_NDS_128_WIG(PSIGND), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2PSIGNW = /* PSIGNW */ [
        { 0x0F3809, _r,_mm,_mmm64 },
        { PSIGNW, _r,_xmm,_xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPSIGNW = /* VPSIGNW */ [
        { VEX_NDS_128_WIG(PSIGNW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

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

PTRNTAB3[2] aptb3BLENDPD = /* BLENDPD */ [
        { BLENDPD, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB4[3] aptb4VBLENDPD = /* VBLENDPD */ [
        { VEX_NDS_128_WIG(BLENDPD), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(BLENDPD), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3BLENDPS = /* BLENDPS */ [
        { BLENDPS, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB4[3] aptb4VBLENDPS = /* VBLENDPS */ [
        { VEX_NDS_128_WIG(BLENDPS), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(BLENDPS), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3BLENDVPD = /* BLENDVPD */ [
        { BLENDVPD, _r, _xmm, _xmm_m128, _xmm0 },
        { ASM_END }
];

PTRNTAB4[3] aptb4VBLENDVPD = /* VBLENDVPD */ [
        { VEX_NDS_128_WIG(0x660F3A4B), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(0x660F3A4B), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3BLENDVPS = /* BLENDVPS */ [
        { BLENDVPS, _r, _xmm, _xmm_m128, _xmm0 },
        { ASM_END }
];

PTRNTAB4[3] aptb4VBLENDVPS = /* VBLENDVPS */ [
        { VEX_NDS_128_WIG(0x660F3A4A), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(0x660F3A4A), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3DPPD = /* DPPD */ [
        { DPPD, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB4[2]  aptb4VDPPD = /* VDPPD */ [
        { VEX_NDS_128_WIG(DPPD), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3DPPS = /* DPPS */ [
        { DPPS, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB4[3]  aptb4VDPPS = /* VDPPS */ [
        { VEX_NDS_128_WIG(DPPS), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { VEX_NDS_256_WIG(DPPS), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3EXTRACTPS = /* EXTRACTPS */ [
        { EXTRACTPS, _r, _rm32, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VEXTRACTPS = /* VEXTRACTPS */ [
        { VEX_128_WIG(EXTRACTPS), _r, _rm32, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3INSERTPS = /* INSERTPS */ [
        { INSERTPS, _r, _xmm, _xmm_m32, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VINSERTPS = /* VINSERTPS */ [
        { VEX_NDS_128_WIG(INSERTPS), _r, _xmm, _xmm, _xmm_m32, _imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2MOVNTDQA = /* MOVNTDQA */ [
        { MOVNTDQA, _r, _xmm, _m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VMOVNTDQA = /* VMOVNTDQA */ [
        { VEX_128_WIG(MOVNTDQA), _r, _xmm, _m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3MPSADBW = /* MPSADBW */ [
        { MPSADBW, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VMPSADBW  = /* VMPSADBW */ [
        { VEX_NDS_128_WIG(MPSADBW), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PACKUSDW = /* PACKUSDW */ [
        { PACKUSDW, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPACKUSDW = /* VPACKUSDW */ [
        { VEX_NDS_128_WIG(PACKUSDW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PBLENDVB = /* PBLENDVB */ [
        { PBLENDVB, _r, _xmm, _xmm_m128, _xmm0 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VPBLENDVB = /* VPBLENDVB */ [
        { VEX_NDS_128_WIG(0x660F3A4C), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PBLENDW = /* PBLENDW */ [
        { PBLENDW, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VPBLENDW = /* VPBLENDW */ [
        { VEX_NDS_128_WIG(PBLENDW), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PCMPEQQ = /* PCMPEQQ */ [
        { PCMPEQQ, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPEQQ = /* VPCMPEQQ */ [
        { VEX_NDS_128_WIG(PCMPEQQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PEXTRB = /* PEXTRB */ [
        { PEXTRB, _r, _regm8, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPEXTRB = /* VPEXTRB */ [
        { VEX_128_WIG(PEXTRB), _r, _regm8, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PEXTRD = /* PEXTRD */ [
        { PEXTRD, _r, _rm32, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPEXTRD = /* VPEXTRD */ [
        { VEX_128_WIG(PEXTRD), _r, _rm32, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PEXTRQ = /* PEXTRQ */ [
        { PEXTRQ, _r|_64_bit, _rm64, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPEXTRQ = /* VPEXTRQ */ [
        { VEX_128_W1(PEXTRD), _r, _rm64, _xmm, _imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PHMINPOSUW = /* PHMINPOSUW  */ [
        { PHMINPOSUW, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPHMINPOSUW = /* VPHMINPOSUW */ [
        { VEX_128_WIG(PHMINPOSUW), _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[3] aptb3PINSRB = /* PINSRB */ [
        { PINSRB, _r, _xmm, _r32, _imm8 },
        { PINSRB, _r, _xmm, _rm8, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VPINSRB = /* VPINSRB */ [
        { VEX_NDS_128_WIG(PINSRB), _r, _xmm, _xmm, _r32m8, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PINSRD = /* PINSRD */ [
        { PINSRD, _r, _xmm, _rm32, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VPINSRD = /* VPINSRD */ [
        { VEX_NDS_128_WIG(PINSRD), _r, _xmm, _xmm, _rm32, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PINSRQ = /* PINSRQ */ [
        { PINSRQ, _r|_64_bit, _xmm, _rm64, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VPINSRQ = /* VPINSRQ */ [
        { VEX_NDS_128_W1(PINSRD), _r, _xmm, _xmm, _rm64, _imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMAXSB = /* PMAXSB */ [
        { PMAXSB, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMAXSB = /* VPMAXSB */ [
        { VEX_NDS_128_WIG(PMAXSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMAXSD = /* PMAXSD */ [
        { PMAXSD, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMAXSD = /* VPMAXSD */ [
        { VEX_NDS_128_WIG(PMAXSD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMAXUD = /* PMAXUD */ [
        { PMAXUD, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMAXUD = /* VPMAXUD */ [
        { VEX_NDS_128_WIG(PMAXUD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMAXUW = /* PMAXUW */ [
        { PMAXUW, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMAXUW = /* VPMAXUW */ [
        { VEX_NDS_128_WIG(PMAXUW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMINSB = /* PMINSB */ [
        { PMINSB, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMINSB = /* VPMINSB */ [
        { VEX_NDS_128_WIG(PMINSB), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMINSD = /* PMINSD */ [
        { PMINSD, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMINSD = /* VPMINSD */ [
        { VEX_NDS_128_WIG(PMINSD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMINUD = /* PMINUD */ [
        { PMINUD, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMINUD = /* VPMINUD */ [
        { VEX_NDS_128_WIG(PMINUD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMINUW = /* PMINUW */ [
        { PMINUW, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMINUW = /* VPMINUW */ [
        { VEX_NDS_128_WIG(PMINUW), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVSXBW = /* PMOVSXBW */ [
        { PMOVSXBW, _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVSXBW = /* VPMOVSXBW */ [
        { VEX_128_WIG(PMOVSXBW), _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVSXBD = /* PMOVSXBD */ [
        { PMOVSXBD, _r, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVSXBD = /* VPMOVSXBD */ [
        { VEX_128_WIG(PMOVSXBD), _r, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVSXBQ = /* PMOVSXBQ */ [
        { PMOVSXBQ, _r, _xmm, _xmm_m16 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVSXBQ = /* VPMOVSXBQ */ [
        { VEX_128_WIG(PMOVSXBQ), _r, _xmm, _xmm_m16 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVSXWD = /* PMOVSXWD */ [
        { PMOVSXWD, _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVSXWD = /* VPMOVSXWD */ [
        { VEX_128_WIG(PMOVSXWD), _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVSXWQ = /* PMOVSXWQ */ [
        { PMOVSXWQ, _r, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVSXWQ = /* VPMOVSXWQ */ [
        { VEX_128_WIG(PMOVSXWQ), _r, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVSXDQ = /* PMOVSXDQ */ [
        { PMOVSXDQ, _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVSXDQ = /* VPMOVSXDQ */ [
        { VEX_128_WIG(PMOVSXDQ), _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVZXBW = /* PMOVZXBW */ [
        { PMOVZXBW, _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVZXBW = /* VPMOVZXBW */ [
        { VEX_128_WIG(PMOVZXBW), _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVZXBD = /* PMOVZXBD */ [
        { PMOVZXBD, _r, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVZXBD = /* VPMOVZXBD */ [
        { VEX_128_WIG(PMOVZXBD), _r, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVZXBQ = /* PMOVZXBQ */ [
        { PMOVZXBQ, _r, _xmm, _xmm_m16 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVZXBQ = /* VPMOVZXBQ */ [
        { VEX_128_WIG(PMOVZXBQ), _r, _xmm, _xmm_m16 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVZXWD = /* PMOVZXWD */ [
        { PMOVZXWD, _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVZXWD = /* VPMOVZXWD */ [
        { VEX_128_WIG(PMOVZXWD), _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVZXWQ = /* PMOVZXWQ */ [
        { PMOVZXWQ, _r, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVZXWQ = /* VPMOVZXWQ */ [
        { VEX_128_WIG(PMOVZXWQ), _r, _xmm, _xmm_m32 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMOVZXDQ = /* PMOVZXDQ */ [
        { PMOVZXDQ, _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VPMOVZXDQ = /* VPMOVZXDQ */ [
        { VEX_128_WIG(PMOVZXDQ), _r, _xmm, _xmm_m64 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMULDQ = /* PMULDQ */ [
        { PMULDQ, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMULDQ = /* VPMULDQ */ [
        { VEX_NDS_128_WIG(PMULDQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PMULLD = /* PMULLD */ [
        { PMULLD, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPMULLD = /* VPMULLD */ [
        { VEX_NDS_128_WIG(PMULLD), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PTEST = /* PTEST */ [
        { PTEST, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VPTEST = /* VPTEST */ [
        { VEX_128_WIG(PTEST), _r, _xmm, _xmm_m128 },
        { VEX_256_WIG(PTEST), _r, _ymm, _ymm_m256 },
        { ASM_END }
];

PTRNTAB3[2] aptb3ROUNDPD = /* ROUNDPD */ [
        { ROUNDPD, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VROUNDPD = /* VROUNDPD */ [
        { VEX_128_WIG(ROUNDPD), _r, _xmm, _xmm_m128, _imm8 },
        { VEX_256_WIG(ROUNDPD), _r, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3ROUNDPS = /* ROUNDPS */ [
        { ROUNDPS, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[3] aptb3VROUNDPS = /* VROUNDPS */ [
        { VEX_128_WIG(ROUNDPS), _r, _xmm, _xmm_m128, _imm8 },
        { VEX_256_WIG(ROUNDPS), _r, _ymm, _ymm_m256, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3ROUNDSD = /* ROUNDSD */ [
        { ROUNDSD, _r, _xmm, _xmm_m64, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VROUNDSD = /* VROUNDSD */ [
        { VEX_NDS_128_WIG(ROUNDSD), _r, _xmm, _xmm, _xmm_m64, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3ROUNDSS = /* ROUNDSS */ [
        { ROUNDSS, _r, _xmm, _xmm_m32, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VROUNDSS = /* VROUNDSS */ [
        { VEX_NDS_128_WIG(ROUNDSS), _r, _xmm, _xmm, _xmm_m32, _imm8 },
        { ASM_END }
];

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

PTRNTAB2[6] aptb2CRC32 = /* CRC32 */ [
        { 0xF20F38F0, _r        , _r32, _rm8  },
        { 0xF20F38F0, _r|_64_bit, _r64, _rm8  },
        { 0xF20F38F1, _r|_16_bit, _r32, _rm16 },
        { 0xF20F38F1, _r|_32_bit, _r32, _rm32 },
        { 0xF20F38F1, _r|_64_bit, _r64, _rm64 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PCMPESTRI  = /* PCMPESTRI */ [
        { PCMPESTRI, _r|_modcx  , _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPESTRI = /* VPCMPESTRI */ [
        { VEX_128_WIG(PCMPESTRI), _r|_modcx, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PCMPESTRM = /* PCMPESTRM */ [
        { PCMPESTRM, _r|_modxmm0, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPESTRM = /* VPCMPESTRM */ [
        { VEX_128_WIG(PCMPESTRM), _r|_modxmm0, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PCMPISTRI  = /* PCMPISTRI */ [
        { PCMPISTRI, _r|_modcx  , _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPISTRI = /* VPCMPISTRI */ [
        { VEX_128_WIG(PCMPISTRI), _r|_modcx, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3PCMPISTRM  = /* PCMPISTRM */ [
        { PCMPISTRM, _r|_modxmm0, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPISTRM = /* VPCMPISTRM */ [
        { VEX_128_WIG(PCMPISTRM), _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB2[2] aptb2PCMPGTQ  = /* PCMPGTQ */ [
        { PCMPGTQ, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VPCMPGTQ = /* VPCMPGTQ */ [
        { VEX_NDS_128_WIG(PCMPGTQ), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[4] aptb2POPCNT  = /* POPCNT */ [
        { POPCNT, _r|_16_bit, _r16, _rm16 },
        { POPCNT, _r|_32_bit, _r32, _rm32 },
        { POPCNT, _r|_64_bit, _r64, _rm64 },
        { ASM_END }
];

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

PTRNTAB3[2] aptb3PCLMULQDQ = /* PCLMULQDQ */ [
        { 0x660F3A44, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VPCLMULQDQ = /* VPCLMULQDQ */ [
        { VEX_NDS_128_WIG(0x660F3A44), _r, _xmm, _xmm, _xmm_m128, _imm8 },
        { ASM_END }
];

/* ======================= AVX ======================= */

PTRNTAB2[2] aptb2VBROADCASTF128 = /* VBROADCASTF128 */ [
        { VEX_256_WIG(0x660F381A), _r, _ymm, _m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2VBROADCASTSD = /* VBROADCASTSD */ [
        { VEX_256_WIG(0x660F3819), _r, _ymm, _m64 },
        { ASM_END }
];

PTRNTAB2[3] aptb2VBROADCASTSS = /* VBROADCASTSS */ [
        { VEX_128_WIG(0x660F3818), _r, _xmm, _m32 },
        { VEX_256_WIG(0x660F3818), _r, _ymm, _m32 },
        { ASM_END }
];

PTRNTAB3[2] aptb3VEXTRACTF128 = /* VEXTRACTF128 */ [
        { VEX_256_WIG(0x660F3A19), _r, _xmm_m128, _ymm, _imm8 },
        { ASM_END }
];

PTRNTAB4[2] aptb4VINSERTF128 = /* VINSERTF128 */ [
        { VEX_NDS_256_WIG(0x660F3A18), _r, _ymm, _ymm, _xmm_m128, _imm8 },
        { ASM_END }
];

PTRNTAB3[5] aptb3VMASKMOVPS = /* VMASKMOVPS */ [
        { VEX_NDS_128_WIG(0x660F382C), _r, _xmm, _xmm, _m128 },
        { VEX_NDS_256_WIG(0x660F382C), _r, _ymm, _ymm, _m256 },
        { VEX_NDS_128_WIG(0x660F382E), _r, _m128, _xmm, _xmm },
        { VEX_NDS_256_WIG(0x660F382E), _r, _m256, _ymm, _ymm },
        { ASM_END }
];

PTRNTAB3[5] aptb3VMASKMOVPD = /* VMASKMOVPD */ [
        { VEX_NDS_128_WIG(0x660F382D), _r, _xmm, _xmm, _m128 },
        { VEX_NDS_256_WIG(0x660F382D), _r, _ymm, _ymm, _m256 },
        { VEX_NDS_128_WIG(0x660F382F), _r, _m128, _xmm, _xmm },
        { VEX_NDS_256_WIG(0x660F382F), _r, _m256, _ymm, _ymm },
        { ASM_END }
];

PTRNTAB0[2] aptb0VZEROALL = /* VZEROALL */ [
        { VEX_256_WIG(0x0F77), _modall }, // FIXME: need _modxmm
        { ASM_END },
];

PTRNTAB0[2] aptb0VZEROUPPER = /* VZEROUPPER */ [
        { VEX_128_WIG(0x0F77), _modall }, // FIXME: need _modxmm
        { ASM_END },
];

PTRNTAB0[2]  aptb0XGETBV = /* XGETBV */ [
        { XGETBV, _modaxdx },
        { ASM_END },
];

PTRNTAB1[2]  aptb1XRSTOR = /* XRSTOR */ [
        { 0x0FAE, _5, _m512 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1XRSTOR64 = /* XRSTOR64 */ [
        { 0x0FAE, _5|_64_bit, _m512 }, // TODO: REX_W override is implicit
        { ASM_END }
];

PTRNTAB1[2]  aptb1XSAVE = /* XSAVE */ [
        { 0x0FAE, _4, _m512 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1XSAVE64 = /* XSAVE64 */ [
        { 0x0FAE, _4|_64_bit, _m512 }, // TODO: REX_W override is implicit
        { ASM_END }
];

PTRNTAB1[2]  aptb1XSAVEC = /* XSAVEC */ [
        { 0x0FC7, _4, _m512 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1XSAVEC64 = /* XSAVEC64 */ [
        { 0x0FC7, _4|_64_bit, _m512 }, // TODO: REX_W override is implicit
        { ASM_END }
];

PTRNTAB1[2]  aptb1XSAVEOPT = /* XSAVEOPT */ [
        { 0x0FAE, _6, _m512 },
        { ASM_END }
];

PTRNTAB1[2]  aptb1XSAVEOPT64 = /* XSAVEOPT64 */ [
        { 0x0FAE, _6|_64_bit, _m512 }, // TODO: REX_W override is implicit
        { ASM_END }
];

PTRNTAB0[2]  aptb0XSETBV = /* XSETBV */ [
        { XSETBV, 0 },
        { ASM_END },
];

PTRNTAB3[5]  aptb3VPERMILPD = /* VPERMILPD */ [
        { VEX_NDS_128_WIG(0x660F380D), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(0x660F380D), _r, _ymm, _ymm, _ymm_m256 },
        { VEX_128_WIG(0x660F3A05), _r, _xmm, _xmm_m128, _imm8 },
        { VEX_256_WIG(0x660F3A05), _r, _ymm, _ymm_m256, _imm8 },
        { ASM_END },
];

PTRNTAB3[5]  aptb3VPERMILPS = /* VPERMILPS */ [
        { VEX_NDS_128_WIG(0x660F380C), _r, _xmm, _xmm, _xmm_m128 },
        { VEX_NDS_256_WIG(0x660F380C), _r, _ymm, _ymm, _ymm_m256 },
        { VEX_128_WIG(0x660F3A04), _r, _xmm, _xmm_m128, _imm8 },
        { VEX_256_WIG(0x660F3A04), _r, _ymm, _ymm_m256, _imm8 },
        { ASM_END },
];

PTRNTAB4[2]  aptb3VPERM2F128 = /* VPERM2F128 */ [
        { VEX_NDS_256_WIG(0x660F3A06), _r, _ymm, _ymm, _ymm_m256, _imm8 },
        { ASM_END },
];

/* ======================= AES ======================= */

PTRNTAB2[2] aptb2AESENC = /* AESENC */ [
        { AESENC, _r, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB3[2] aptb3VAESENC = /* VAESENC */ [
        { VEX_NDS_128_WIG(AESENC), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB2[2] aptb2AESENCLAST = /* AESENCLAST */ [
        { AESENCLAST, _r, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB3[2] aptb3VAESENCLAST = /* VAESENCLAST */ [
        { VEX_NDS_128_WIG(AESENCLAST), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB2[2] aptb2AESDEC = /* AESDEC */ [
        { AESDEC, _r, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB3[2] aptb3VAESDEC = /* VAESDEC */ [
        { VEX_NDS_128_WIG(AESDEC), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB2[2] aptb2AESDECLAST = /* AESDECLAST */ [
        { AESDECLAST, _r, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB3[2] aptb3VAESDECLAST = /* VAESDECLAST */ [
        { VEX_NDS_128_WIG(AESDECLAST), _r, _xmm, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB2[2] aptb2AESIMC = /* AESIMC */ [
        { AESIMC, _r, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB2[2] aptb2VAESIMC = /* VAESIMC */ [
        { VEX_128_WIG(AESIMC), _r, _xmm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB3[2] aptb3AESKEYGENASSIST = /* AESKEYGENASSIST */ [
        { AESKEYGENASSIST, _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END },
];

PTRNTAB3[2] aptb3VAESKEYGENASSIST = /* VAESKEYGENASSIST */ [
        { VEX_128_WIG(AESKEYGENASSIST), _r, _xmm, _xmm_m128, _imm8 },
        { ASM_END },
];

/* ======================= FSGSBASE ======================= */

PTRNTAB1[3] aptb1RDFSBASE = /* RDFSBASE */ [
        { 0xF30FAE, _0, _r32 },
        { 0xF30FAE, _0|_64_bit, _r64 },
        { ASM_END },
];

PTRNTAB1[3] aptb1RDGSBASE = /* RDGSBASE */ [
        { 0xF30FAE, _1, _r32 },
        { 0xF30FAE, _1|_64_bit, _r64 },
        { ASM_END },
];

PTRNTAB1[3] aptb1WRFSBASE = /* WRFSBASE */ [
        { 0xF30FAE, _2, _r32 },
        { 0xF30FAE, _2|_64_bit, _r64 },
        { ASM_END },
];

PTRNTAB1[3] aptb1WRGSBASE = /* WRGSBASE */ [
        { 0xF30FAE, _3, _r32 },
        { 0xF30FAE, _3|_64_bit, _r64 },
        { ASM_END },
];

/* ======================= RDRAND ======================= */

PTRNTAB1[4] aptb1RDRAND = /* RDRAND */ [
        { 0x0FC7, _6|_16_bit, _r16 },
        { 0x0FC7, _6|_32_bit, _r32 },
        { 0x0FC7, _6|_64_bit, _r64 },
        { ASM_END },
];

/* ======================= RDSEED ======================= */

PTRNTAB1[4] aptb1RDSEED = /* RDSEED */ [
        { 0x0FC7, _7|_16_bit, _r16 },
        { 0x0FC7, _7|_32_bit, _r32 },
        { 0x0FC7, _7|_64_bit, _r64 },
        { ASM_END },
];

/* ======================= FP16C ======================= */

PTRNTAB2[3] aptb2VCVTPH2PS = /* VCVTPH2PS */ [
        { VEX_128_WIG(0x660F3813), _r, _xmm, _xmm_m64 },
        { VEX_256_WIG(0x660F3813), _r, _ymm, _xmm_m128 },
        { ASM_END },
];

PTRNTAB3[3] aptb3VCVTPS2PH = /* VCVTPS2PH */ [
        { VEX_128_WIG(0x660F3A1D), _r, _xmm_m64, _xmm, _imm8  },
        { VEX_256_WIG(0x660F3A1D), _r, _xmm_m128, _ymm, _imm8  },
        { ASM_END },
];

/* ======================= FMA ======================= */

PTRNTAB3[3] aptb3VFMADD132PD = /* VFMADD132PD */ [
        { VEX_DDS_128_W1(0x660F3898), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F3898), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADD213PD = /* VFMADD213PD */ [
        { VEX_DDS_128_W1(0x660F38A8), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38A8), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADD231PD = /* VFMADD231PD */ [
        { VEX_DDS_128_W1(0x660F38B8), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38B8), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADD132PS = /* VFMADD132PS */ [
        { VEX_DDS_128_WIG(0x660F3898), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F3898), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADD213PS = /* VFMADD213PS */ [
        { VEX_DDS_128_WIG(0x660F38A8), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38A8), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADD231PS = /* VFMADD231PS */ [
        { VEX_DDS_128_WIG(0x660F38B8), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38B8), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMADD132SD = /* VFMADD132SD */ [
        { VEX_DDS_128_W1(0x660F3899), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMADD213SD = /* VFMADD213SD */ [
        { VEX_DDS_128_W1(0x660F38A9), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMADD231SD = /* VFMADD231SD */ [
        { VEX_DDS_128_W1(0x660F38B9), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMADD132SS = /* VFMADD132SS */ [
        { VEX_DDS_128_WIG(0x660F3899), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMADD213SS = /* VFMADD213SS */ [
        { VEX_DDS_128_WIG(0x660F38A9), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMADD231SS = /* VFMADD231SS */ [
        { VEX_DDS_128_WIG(0x660F38B9), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADDSUB132PD = /* VFMADDSUB132PD */ [
        { VEX_DDS_128_W1(0x660F3896), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F3896), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADDSUB213PD = /* VFMADDSUB213PD */ [
        { VEX_DDS_128_W1(0x660F38A6), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38A6), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADDSUB231PD = /* VFMADDSUB231PD */ [
        { VEX_DDS_128_W1(0x660F38B6), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38B6), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADDSUB132PS = /* VFMADDSUB132PS */ [
        { VEX_DDS_128_WIG(0x660F3896), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F3896), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADDSUB213PS = /* VFMADDSUB213PS */ [
        { VEX_DDS_128_WIG(0x660F38A6), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38A6), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMADDSUB231PS = /* VFMADDSUB231PS */ [
        { VEX_DDS_128_WIG(0x660F38B6), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38B6), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUBADD132PD = /* VFMSUBADD132PD */ [
        { VEX_DDS_128_W1(0x660F3897), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F3897), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUBADD213PD = /* VFMSUBADD213PD */ [
        { VEX_DDS_128_W1(0x660F38A7), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38A7), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUBADD231PD = /* VFMSUBADD231PD */ [
        { VEX_DDS_128_W1(0x660F38B7), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38B7), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUBADD132PS = /* VFMSUBADD132PS */ [
        { VEX_DDS_128_WIG(0x660F3897), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F3897), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUBADD213PS = /* VFMSUBADD213PS */ [
        { VEX_DDS_128_WIG(0x660F38A7), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38A7), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUBADD231PS = /* VFMSUBADD231PS */ [
        { VEX_DDS_128_WIG(0x660F38B7), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38B7), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUB132PD = /* VFMSUB132PD */ [
        { VEX_DDS_128_W1(0x660F389A), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F389A), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUB213PD = /* VFMSUB213PD */ [
        { VEX_DDS_128_W1(0x660F38AA), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38AA), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUB231PD = /* VFMSUB231PD */ [
        { VEX_DDS_128_W1(0x660F38BA), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_W1(0x660F38BA), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUB132PS = /* VFMSUB132PS */ [
        { VEX_DDS_128_WIG(0x660F389A), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F389A), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUB213PS = /* VFMSUB213PS */ [
        { VEX_DDS_128_WIG(0x660F38AA), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38AA), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[3] aptb3VFMSUB231PS = /* VFMSUB231PS */ [
        { VEX_DDS_128_WIG(0x660F38BA), _r, _xmm, _xmm, _xmm_m128  },
        { VEX_DDS_256_WIG(0x660F38BA), _r, _ymm, _ymm, _ymm_m256  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMSUB132SD = /* VFMSUB132SD */ [
        { VEX_DDS_128_W1(0x660F389B), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMSUB213SD = /* VFMSUB213SD */ [
        { VEX_DDS_128_W1(0x660F38AB), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMSUB231SD = /* VFMSUB231SD */ [
        { VEX_DDS_128_W1(0x660F38BB), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMSUB132SS = /* VFMSUB132SS */ [
        { VEX_DDS_128_WIG(0x660F389B), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMSUB213SS = /* VFMSUB213SS */ [
        { VEX_DDS_128_WIG(0x660F38AB), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

PTRNTAB3[2] aptb3VFMSUB231SS = /* VFMSUB231SS */ [
        { VEX_DDS_128_WIG(0x660F38BB), _r, _xmm, _xmm, _xmm_m128  },
        { ASM_END },
];

/* ======================= SHA ======================= */

PTRNTAB3[2] aptb3SHA1RNDS4 = /* SHA1RNDS4 */ [
        { 0x0F3ACC, _ib, _xmm, _xmm_m128, _imm8 },
        { ASM_END },
];

PTRNTAB2[2] aptb2SHA1NEXTE = /* SHA1NEXTE */ [
        { 0x0F38C8, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SHA1MSG1 = /* SHA1MSG1 */ [
        { 0x0F38C9, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SHA1MSG2 = /* SHA1MSG2 */ [
        { 0x0F38CA, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SHA256RNDS2 = /* SHA256RNDS2 */ [
        { 0x0F38CB, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SHA256MSG1 = /* SHA256MSG1 */ [
        { 0x0F38CC, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

PTRNTAB2[2] aptb2SHA256MSG2 = /* SHA256MSG2 */ [
        { 0x0F38CD, _r, _xmm, _xmm_m128 },
        { ASM_END }
];

}

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

immutable OP[] optab =
[
//      opcode string, number of operators, reference to PTRNTAB
        { "__emit",     ITdata | OPdb,  { null } },
        { "_emit",      ITdata | OPdb,  { null } },
        { "aaa",        0,              { aptb0AAA.ptr } },
        { "aad",        0,              { aptb0AAD.ptr } },
        { "aam",        0,              { aptb0AAM.ptr } },
        { "aas",        0,              { aptb0AAS.ptr } },
        { "adc",        2,              { aptb2ADC.ptr } },
        { "add",        2,              { aptb2ADD.ptr } },
        { "addpd",      2,              { aptb2ADDPD.ptr } },
        { "addps",      2,              { aptb2ADDPS.ptr } },
        { "addsd",      2,              { aptb2ADDSD.ptr } },
        { "addss",      2,              { aptb2ADDSS.ptr } },
        { "addsubpd",   2,              { aptb2ADDSUBPD.ptr } },
        { "addsubps",   2,              { aptb2ADDSUBPS.ptr } },
        { "aesdec",     2,              { aptb2AESDEC.ptr } },
        { "aesdeclast", 2,              { aptb2AESDECLAST.ptr } },
        { "aesenc",     2,              { aptb2AESENC.ptr } },
        { "aesenclast", 2,              { aptb2AESENCLAST.ptr } },
        { "aesimc",     2,              { aptb2AESIMC.ptr } },
        { "aeskeygenassist", 3,         { aptb3AESKEYGENASSIST.ptr } },
        { "and",        2,              { aptb2AND.ptr } },
        { "andnpd",     2,              { aptb2ANDNPD.ptr } },
        { "andnps",     2,              { aptb2ANDNPS.ptr } },
        { "andpd",      2,              { aptb2ANDPD.ptr } },
        { "andps",      2,              { aptb2ANDPS.ptr } },
        { "arpl",       2,              { aptb2ARPL.ptr } },
        { "blendpd",    3,              { aptb3BLENDPD.ptr } },
        { "blendps",    3,              { aptb3BLENDPS.ptr } },
        { "blendvpd",   3,              { aptb3BLENDVPD.ptr } },
        { "blendvps",   3,              { aptb3BLENDVPS.ptr } },
        { "bound",      2,              { aptb2BOUND.ptr } },
        { "bsf",        2,              { aptb2BSF.ptr } },
        { "bsr",        2,              { aptb2BSR.ptr } },
        { "bswap",      1,              { aptb1BSWAP.ptr } },
        { "bt",         2,              { aptb2BT.ptr } },
        { "btc",        2,              { aptb2BTC.ptr } },
        { "btr",        2,              { aptb2BTR.ptr } },
        { "bts",        2,              { aptb2BTS.ptr } },
        { "call",       ITjump | 1,     { aptb1CALL.ptr } },
        { "cbw",        0,              { aptb0CBW.ptr } },
        { "cdq",        0,              { aptb0CDQ.ptr } },
        { "cdqe",       0,              { aptb0CDQE.ptr } },
        { "clc",        0,              { aptb0CLC.ptr } },
        { "cld",        0,              { aptb0CLD.ptr } },
        { "clflush",    1,              { aptb1CLFLUSH.ptr } },
        { "cli",        0,              { aptb0CLI.ptr } },
        { "clts",       0,              { aptb0CLTS.ptr } },
        { "cmc",        0,              { aptb0CMC.ptr } },
        { "cmova",      2,              { aptb2CMOVNBE.ptr } },
        { "cmovae",     2,              { aptb2CMOVNB.ptr } },
        { "cmovb",      2,              { aptb2CMOVB.ptr } },
        { "cmovbe",     2,              { aptb2CMOVBE.ptr } },
        { "cmovc",      2,              { aptb2CMOVB.ptr } },
        { "cmove",      2,              { aptb2CMOVZ.ptr } },
        { "cmovg",      2,              { aptb2CMOVNLE.ptr } },
        { "cmovge",     2,              { aptb2CMOVNL.ptr } },
        { "cmovl",      2,              { aptb2CMOVL.ptr } },
        { "cmovle",     2,              { aptb2CMOVLE.ptr } },
        { "cmovna",     2,              { aptb2CMOVBE.ptr } },
        { "cmovnae",    2,              { aptb2CMOVB.ptr } },
        { "cmovnb",     2,              { aptb2CMOVNB.ptr } },
        { "cmovnbe",    2,              { aptb2CMOVNBE.ptr } },
        { "cmovnc",     2,              { aptb2CMOVNB.ptr } },
        { "cmovne",     2,              { aptb2CMOVNZ.ptr } },
        { "cmovng",     2,              { aptb2CMOVLE.ptr } },
        { "cmovnge",    2,              { aptb2CMOVL.ptr } },
        { "cmovnl",     2,              { aptb2CMOVNL.ptr } },
        { "cmovnle",    2,              { aptb2CMOVNLE.ptr } },
        { "cmovno",     2,              { aptb2CMOVNO.ptr } },
        { "cmovnp",     2,              { aptb2CMOVNP.ptr } },
        { "cmovns",     2,              { aptb2CMOVNS.ptr } },
        { "cmovnz",     2,              { aptb2CMOVNZ.ptr } },
        { "cmovo",      2,              { aptb2CMOVO.ptr } },
        { "cmovp",      2,              { aptb2CMOVP.ptr } },
        { "cmovpe",     2,              { aptb2CMOVP.ptr } },
        { "cmovpo",     2,              { aptb2CMOVNP.ptr } },
        { "cmovs",      2,              { aptb2CMOVS.ptr } },
        { "cmovz",      2,              { aptb2CMOVZ.ptr } },
        { "cmp",        2,              { aptb2CMP.ptr } },
        { "cmppd",      3,              { aptb3CMPPD.ptr } },
        { "cmpps",      3,              { aptb3CMPPS.ptr } },
        { "cmps",       2,              { aptb2CMPS.ptr } },
        { "cmpsb",      0,              { aptb0CMPSB.ptr } },
        /*{ "cmpsd",    0,              { aptb0CMPSD.ptr } },*/
        { "cmpsd",      ITopt|3,        { aptb3CMPSD.ptr } },
        { "cmpsq",      0,              { aptb0CMPSQ.ptr } },
        { "cmpss",      3,              { aptb3CMPSS.ptr } },
        { "cmpsw",      0,              { aptb0CMPSW.ptr } },
        { "cmpxchg",    2,              { aptb2CMPXCHG.ptr } },
        { "cmpxchg16b", 1,              { aptb1CMPXCHG16B.ptr } },
        { "cmpxchg8b",  1,              { aptb1CMPXCHG8B.ptr } },
        { "comisd",     2,              { aptb2COMISD.ptr } },
        { "comiss",     2,              { aptb2COMISS.ptr } },
        { "cpuid",      0,              { aptb0CPUID.ptr } },
        { "cqo",        0,              { aptb0CQO.ptr } },
        { "crc32",      2,              { aptb2CRC32.ptr } },
        { "cvtdq2pd",   2,              { aptb2CVTDQ2PD.ptr } },
        { "cvtdq2ps",   2,              { aptb2CVTDQ2PS.ptr } },
        { "cvtpd2dq",   2,              { aptb2CVTPD2DQ.ptr } },
        { "cvtpd2pi",   2,              { aptb2CVTPD2PI.ptr } },
        { "cvtpd2ps",   2,              { aptb2CVTPD2PS.ptr } },
        { "cvtpi2pd",   2,              { aptb2CVTPI2PD.ptr } },
        { "cvtpi2ps",   2,              { aptb2CVTPI2PS.ptr } },
        { "cvtps2dq",   2,              { aptb2CVTPS2DQ.ptr } },
        { "cvtps2pd",   2,              { aptb2CVTPS2PD.ptr } },
        { "cvtps2pi",   2,              { aptb2CVTPS2PI.ptr } },
        { "cvtsd2si",   2,              { aptb2CVTSD2SI.ptr } },
        { "cvtsd2ss",   2,              { aptb2CVTSD2SS.ptr } },
        { "cvtsi2sd",   2,              { aptb2CVTSI2SD.ptr } },
        { "cvtsi2ss",   2,              { aptb2CVTSI2SS.ptr } },
        { "cvtss2sd",   2,              { aptb2CVTSS2SD.ptr } },
        { "cvtss2si",   2,              { aptb2CVTSS2SI.ptr } },
        { "cvttpd2dq",  2,              { aptb2CVTTPD2DQ.ptr } },
        { "cvttpd2pi",  2,              { aptb2CVTTPD2PI.ptr } },
        { "cvttps2dq",  2,              { aptb2CVTTPS2DQ.ptr } },
        { "cvttps2pi",  2,              { aptb2CVTTPS2PI.ptr } },
        { "cvttsd2si",  2,              { aptb2CVTTSD2SI.ptr } },
        { "cvttss2si",  2,              { aptb2CVTTSS2SI.ptr } },
        { "cwd",        0,              { aptb0CWD.ptr } },
        { "cwde",       0,              { aptb0CWDE.ptr } },
        { "da",         ITaddr | 4,     { null } },
        { "daa",        0,              { aptb0DAA.ptr } },
        { "das",        0,              { aptb0DAS.ptr } },
        { "db",         ITdata | OPdb,  { null } },
        { "dd",         ITdata | OPdd,  { null } },
        { "de",         ITdata | OPde,  { null } },
        { "dec",        1,              { aptb1DEC.ptr } },
        { "df",         ITdata | OPdf,  { null } },
        { "di",         ITdata | OPdi,  { null } },
        { "div",        ITopt  | 2,     { aptb2DIV.ptr } },
        { "divpd",      2,              { aptb2DIVPD.ptr } },
        { "divps",      2,              { aptb2DIVPS.ptr } },
        { "divsd",      2,              { aptb2DIVSD.ptr } },
        { "divss",      2,              { aptb2DIVSS.ptr } },
        { "dl",         ITdata | OPdl,  { null } },
        { "dppd",       3,              { aptb3DPPD.ptr } },
        { "dpps",       3,              { aptb3DPPS.ptr } },
        { "dq",         ITdata | OPdq,  { null } },
        { "ds",         ITdata | OPds,  { null } },
        { "dt",         ITdata | OPdt,  { null } },
        { "dw",         ITdata | OPdw,  { null } },
        { "emms",       0,              { aptb0EMMS.ptr } },
        { "enter",      2,              { aptb2ENTER.ptr } },
        { "extractps",  3,              { aptb3EXTRACTPS.ptr } },
        { "f2xm1",      ITfloat | 0,    { aptb0F2XM1.ptr } },
        { "fabs",       ITfloat | 0,    { aptb0FABS.ptr } },
        { "fadd",       ITfloat | 2,    { aptb2FADD.ptr } },
        { "faddp",      ITfloat | 2,    { aptb2FADDP.ptr } },
        { "fbld",       ITfloat | 1,    { aptb1FBLD.ptr } },
        { "fbstp",      ITfloat | 1,    { aptb1FBSTP.ptr } },
        { "fchs",       ITfloat | 0,    { aptb0FCHS.ptr } },
        { "fclex",      ITfloat | 0,    { aptb0FCLEX.ptr } },
        { "fcmovb",     ITfloat | 2,    { aptb2FCMOVB.ptr } },
        { "fcmovbe",    ITfloat | 2,    { aptb2FCMOVBE.ptr } },
        { "fcmove",     ITfloat | 2,    { aptb2FCMOVE.ptr } },
        { "fcmovnb",    ITfloat | 2,    { aptb2FCMOVNB.ptr } },
        { "fcmovnbe",   ITfloat | 2,    { aptb2FCMOVNBE.ptr } },
        { "fcmovne",    ITfloat | 2,    { aptb2FCMOVNE.ptr } },
        { "fcmovnu",    ITfloat | 2,    { aptb2FCMOVNU.ptr } },
        { "fcmovu",     ITfloat | 2,    { aptb2FCMOVU.ptr } },
        { "fcom",       ITfloat | 1,    { aptb1FCOM.ptr } },
        { "fcomi",      ITfloat | 2,    { aptb2FCOMI.ptr } },
        { "fcomip",     ITfloat | 2,    { aptb2FCOMIP.ptr } },
        { "fcomp",      ITfloat | 1,    { aptb1FCOMP.ptr } },
        { "fcompp",     ITfloat | 0,    { aptb0FCOMPP.ptr } },
        { "fcos",       ITfloat | 0,    { aptb0FCOS.ptr } },
        { "fdecstp",    ITfloat | 0,    { aptb0FDECSTP.ptr } },
        { "fdisi",      ITfloat | 0,    { aptb0FDISI.ptr } },
        { "fdiv",       ITfloat | 2,    { aptb2FDIV.ptr } },
        { "fdivp",      ITfloat | 2,    { aptb2FDIVP.ptr } },
        { "fdivr",      ITfloat | 2,    { aptb2FDIVR.ptr } },
        { "fdivrp",     ITfloat | 2,    { aptb2FDIVRP.ptr } },
        { "feni",       ITfloat | 0,    { aptb0FENI.ptr } },
        { "ffree",      ITfloat | 1,    { aptb1FFREE.ptr } },
        { "fiadd",      ITfloat | 2,    { aptb2FIADD.ptr } },
        { "ficom",      ITfloat | 1,    { aptb1FICOM.ptr } },
        { "ficomp",     ITfloat | 1,    { aptb1FICOMP.ptr } },
        { "fidiv",      ITfloat | 2,    { aptb2FIDIV.ptr } },
        { "fidivr",     ITfloat | 2,    { aptb2FIDIVR.ptr } },
        { "fild",       ITfloat | 1,    { aptb1FILD.ptr } },
        { "fimul",      ITfloat | 2,    { aptb2FIMUL.ptr } },
        { "fincstp",    ITfloat | 0,    { aptb0FINCSTP.ptr } },
        { "finit",      ITfloat | 0,    { aptb0FINIT.ptr } },
        { "fist",       ITfloat | 1,    { aptb1FIST.ptr } },
        { "fistp",      ITfloat | 1,    { aptb1FISTP.ptr } },
        { "fisttp",     ITfloat | 1,    { aptb1FISTTP.ptr } },
        { "fisub",      ITfloat | 2,    { aptb2FISUB.ptr } },
        { "fisubr",     ITfloat | 2,    { aptb2FISUBR.ptr } },
        { "fld",        ITfloat | 1,    { aptb1FLD.ptr } },
        { "fld1",       ITfloat | 0,    { aptb0FLD1.ptr } },
        { "fldcw",      ITfloat | 1,    { aptb1FLDCW.ptr } },
        { "fldenv",     ITfloat | 1,    { aptb1FLDENV.ptr } },
        { "fldl2e",     ITfloat | 0,    { aptb0FLDL2E.ptr } },
        { "fldl2t",     ITfloat | 0,    { aptb0FLDL2T.ptr } },
        { "fldlg2",     ITfloat | 0,    { aptb0FLDLG2.ptr } },
        { "fldln2",     ITfloat | 0,    { aptb0FLDLN2.ptr } },
        { "fldpi",      ITfloat | 0,    { aptb0FLDPI.ptr } },
        { "fldz",       ITfloat | 0,    { aptb0FLDZ.ptr } },
        { "fmul",       ITfloat | 2,    { aptb2FMUL.ptr } },
        { "fmulp",      ITfloat | 2,    { aptb2FMULP.ptr } },
        { "fnclex",     ITfloat | 0,    { aptb0FNCLEX.ptr } },
        { "fndisi",     ITfloat | 0,    { aptb0FNDISI.ptr } },
        { "fneni",      ITfloat | 0,    { aptb0FNENI.ptr } },
        { "fninit",     ITfloat | 0,    { aptb0FNINIT.ptr } },
        { "fnop",       ITfloat | 0,    { aptb0FNOP.ptr } },
        { "fnsave",     ITfloat | 1,    { aptb1FNSAVE.ptr } },
        { "fnstcw",     ITfloat | 1,    { aptb1FNSTCW.ptr } },
        { "fnstenv",    ITfloat | 1,    { aptb1FNSTENV.ptr } },
        { "fnstsw",     1,              { aptb1FNSTSW.ptr } },
        { "fpatan",     ITfloat | 0,    { aptb0FPATAN.ptr } },
        { "fprem",      ITfloat | 0,    { aptb0FPREM.ptr } },
        { "fprem1",     ITfloat | 0,    { aptb0FPREM1.ptr } },
        { "fptan",      ITfloat | 0,    { aptb0FPTAN.ptr } },
        { "frndint",    ITfloat | 0,    { aptb0FRNDINT.ptr } },
        { "frstor",     ITfloat | 1,    { aptb1FRSTOR.ptr } },
        { "fsave",      ITfloat | 1,    { aptb1FSAVE.ptr } },
        { "fscale",     ITfloat | 0,    { aptb0FSCALE.ptr } },
        { "fsetpm",     ITfloat | 0,    { aptb0FSETPM.ptr } },
        { "fsin",       ITfloat | 0,    { aptb0FSIN.ptr } },
        { "fsincos",    ITfloat | 0,    { aptb0FSINCOS.ptr } },
        { "fsqrt",      ITfloat | 0,    { aptb0FSQRT.ptr } },
        { "fst",        ITfloat | 1,    { aptb1FST.ptr } },
        { "fstcw",      ITfloat | 1,    { aptb1FSTCW.ptr } },
        { "fstenv",     ITfloat | 1,    { aptb1FSTENV.ptr } },
        { "fstp",       ITfloat | 1,    { aptb1FSTP.ptr } },
        { "fstsw",      1,              { aptb1FSTSW.ptr } },
        { "fsub",       ITfloat | 2,    { aptb2FSUB.ptr } },
        { "fsubp",      ITfloat | 2,    { aptb2FSUBP.ptr } },
        { "fsubr",      ITfloat | 2,    { aptb2FSUBR.ptr } },
        { "fsubrp",     ITfloat | 2,    { aptb2FSUBRP.ptr } },
        { "ftst",       ITfloat | 0,    { aptb0FTST.ptr } },
        { "fucom",      ITfloat | 1,    { aptb1FUCOM.ptr } },
        { "fucomi",     ITfloat | 2,    { aptb2FUCOMI.ptr } },
        { "fucomip",    ITfloat | 2,    { aptb2FUCOMIP.ptr } },
        { "fucomp",     ITfloat | 1,    { aptb1FUCOMP.ptr } },
        { "fucompp",    ITfloat | 0,    { aptb0FUCOMPP.ptr } },
        { "fwait",      ITfloat | 0,    { aptb0FWAIT.ptr } },
        { "fxam",       ITfloat | 0,    { aptb0FXAM.ptr } },
        { "fxch",       ITfloat | 1,    { aptb1FXCH.ptr } },
        { "fxrstor",    ITfloat | 1,    { aptb1FXRSTOR.ptr } },
        { "fxsave",     ITfloat | 1,    { aptb1FXSAVE.ptr } },
        { "fxtract",    ITfloat | 0,    { aptb0FXTRACT.ptr } },
        { "fyl2x",      ITfloat | 0,    { aptb0FYL2X.ptr } },
        { "fyl2xp1",    ITfloat | 0,    { aptb0FYL2XP1.ptr } },
        { "haddpd",     2,              { aptb2HADDPD.ptr } },
        { "haddps",     2,              { aptb2HADDPS.ptr } },
        { "hlt",        0,              { aptb0HLT.ptr } },
        { "hsubpd",     2,              { aptb2HSUBPD.ptr } },
        { "hsubps",     2,              { aptb2HSUBPS.ptr } },
        { "idiv",       ITopt | 2,      { aptb2IDIV.ptr } },
        { "imul",       ITopt | 3,      { aptb3IMUL.ptr } },
        { "in",         2,              { aptb2IN.ptr } },
        { "inc",        1,              { aptb1INC.ptr } },
        { "ins",        2,              { aptb2INS.ptr } },
        { "insb",       0,              { aptb0INSB.ptr } },
        { "insd",       0,              { aptb0INSD.ptr } },
        { "insertps",   3,              { aptb3INSERTPS.ptr } },
        { "insw",       0,              { aptb0INSW.ptr } },
        { "int",        ITimmed | 1,    { aptb1INT.ptr } },
        { "into",       0,              { aptb0INTO.ptr } },
        { "invd",       0,              { aptb0INVD.ptr } },
        { "invlpg",     1,              { aptb1INVLPG.ptr } },
        { "iret",       0,              { aptb0IRET.ptr } },
        { "iretd",      0,              { aptb0IRETD.ptr } },
        { "iretq",      0,              { aptb0IRETQ.ptr } },
        { "ja",         ITjump | 1,     { aptb1JNBE.ptr } },
        { "jae",        ITjump | 1,     { aptb1JNB.ptr } },
        { "jb",         ITjump | 1,     { aptb1JB.ptr } },
        { "jbe",        ITjump | 1,     { aptb1JBE.ptr } },
        { "jc",         ITjump | 1,     { aptb1JB.ptr } },
        { "jcxz",       ITjump | 1,     { aptb1JCXZ.ptr } },
        { "je",         ITjump | 1,     { aptb1JZ.ptr } },
        { "jecxz",      ITjump | 1,     { aptb1JECXZ.ptr } },
        { "jg",         ITjump | 1,     { aptb1JNLE.ptr } },
        { "jge",        ITjump | 1,     { aptb1JNL.ptr } },
        { "jl",         ITjump | 1,     { aptb1JL.ptr } },
        { "jle",        ITjump | 1,     { aptb1JLE.ptr } },
        { "jmp",        ITjump | 1,     { aptb1JMP.ptr } },
        { "jna",        ITjump | 1,     { aptb1JBE.ptr } },
        { "jnae",       ITjump | 1,     { aptb1JB.ptr } },
        { "jnb",        ITjump | 1,     { aptb1JNB.ptr } },
        { "jnbe",       ITjump | 1,     { aptb1JNBE.ptr } },
        { "jnc",        ITjump | 1,     { aptb1JNB.ptr } },
        { "jne",        ITjump | 1,     { aptb1JNZ.ptr } },
        { "jng",        ITjump | 1,     { aptb1JLE.ptr } },
        { "jnge",       ITjump | 1,     { aptb1JL.ptr } },
        { "jnl",        ITjump | 1,     { aptb1JNL.ptr } },
        { "jnle",       ITjump | 1,     { aptb1JNLE.ptr } },
        { "jno",        ITjump | 1,     { aptb1JNO.ptr } },
        { "jnp",        ITjump | 1,     { aptb1JNP.ptr } },
        { "jns",        ITjump | 1,     { aptb1JNS.ptr } },
        { "jnz",        ITjump | 1,     { aptb1JNZ.ptr } },
        { "jo",         ITjump | 1,     { aptb1JO.ptr } },
        { "jp",         ITjump | 1,     { aptb1JP.ptr } },
        { "jpe",        ITjump | 1,     { aptb1JP.ptr } },
        { "jpo",        ITjump | 1,     { aptb1JNP.ptr } },
        { "js",         ITjump | 1,     { aptb1JS.ptr } },
        { "jz",         ITjump | 1,     { aptb1JZ.ptr } },
        { "lahf",           0,              { aptb0LAHF.ptr } },
        { "lar",            2,              { aptb2LAR.ptr } },
        { "lddqu",          2,              { aptb2LDDQU.ptr } },
        { "ldmxcsr",        1,              { aptb1LDMXCSR.ptr } },
        { "lds",            2,              { aptb2LDS.ptr } },
        { "lea",            2,              { aptb2LEA.ptr } },
        { "leave",          0,              { aptb0LEAVE.ptr } },
        { "les",            2,              { aptb2LES.ptr } },
        { "lfence",         0,              { aptb0LFENCE.ptr } },
        { "lfs",            2,              { aptb2LFS.ptr } },
        { "lgdt",           1,              { aptb1LGDT.ptr } },
        { "lgs",            2,              { aptb2LGS.ptr } },
        { "lidt",           1,              { aptb1LIDT.ptr } },
        { "lldt",           1,              { aptb1LLDT.ptr } },
        { "lmsw",           1,              { aptb1LMSW.ptr } },
        { "lock",           ITprefix | 0,   { aptb0LOCK.ptr } },
        { "lods",           1,              { aptb1LODS.ptr } },
        { "lodsb",          0,              { aptb0LODSB.ptr } },
        { "lodsd",          0,              { aptb0LODSD.ptr } },
        { "lodsq",          0,              { aptb0LODSQ.ptr } },
        { "lodsw",          0,              { aptb0LODSW.ptr } },
        { "loop",           ITjump | 1,     { aptb1LOOP.ptr } },
        { "loope",          ITjump | 1,     { aptb1LOOPE.ptr } },
        { "loopne",         ITjump | 1,     { aptb1LOOPNE.ptr } },
        { "loopnz",         ITjump | 1,     { aptb1LOOPNE.ptr } },
        { "loopz",          ITjump | 1,     { aptb1LOOPE.ptr } },
        { "lsl",            2,              { aptb2LSL.ptr } },
        { "lss",            2,              { aptb2LSS.ptr } },
        { "ltr",            1,              { aptb1LTR.ptr } },
        { "lzcnt",          2,              { aptb2LZCNT.ptr } },
        { "maskmovdqu",     2,              { aptb2MASKMOVDQU.ptr } },
        { "maskmovq",       2,              { aptb2MASKMOVQ.ptr } },
        { "maxpd",          2,              { aptb2MAXPD.ptr } },
        { "maxps",          2,              { aptb2MAXPS.ptr } },
        { "maxsd",          2,              { aptb2MAXSD.ptr } },
        { "maxss",          2,              { aptb2MAXSS.ptr } },
        { "mfence",         0,              { aptb0MFENCE.ptr } },
        { "minpd",          2,              { aptb2MINPD.ptr } },
        { "minps",          2,              { aptb2MINPS.ptr } },
        { "minsd",          2,              { aptb2MINSD.ptr } },
        { "minss",          2,              { aptb2MINSS.ptr } },
        { "monitor",        0,              { aptb0MONITOR.ptr } },
        { "mov",            2,              { aptb2MOV.ptr } },
        { "movapd",         2,              { aptb2MOVAPD.ptr } },
        { "movaps",         2,              { aptb2MOVAPS.ptr } },
        { "movd",           2,              { aptb2MOVD.ptr } },
        { "movddup",        2,              { aptb2MOVDDUP.ptr } },
        { "movdq2q",        2,              { aptb2MOVDQ2Q.ptr } },
        { "movdqa",         2,              { aptb2MOVDQA.ptr } },
        { "movdqu",         2,              { aptb2MOVDQU.ptr } },
        { "movhlps",        2,              { aptb2MOVHLPS.ptr } },
        { "movhpd",         2,              { aptb2MOVHPD.ptr } },
        { "movhps",         2,              { aptb2MOVHPS.ptr } },
        { "movlhps",        2,              { aptb2MOVLHPS.ptr } },
        { "movlpd",         2,              { aptb2MOVLPD.ptr } },
        { "movlps",         2,              { aptb2MOVLPS.ptr } },
        { "movmskpd",       2,              { aptb2MOVMSKPD.ptr } },
        { "movmskps",       2,              { aptb2MOVMSKPS.ptr } },
        { "movntdq",        2,              { aptb2MOVNTDQ.ptr } },
        { "movntdqa",       2,              { aptb2MOVNTDQA.ptr } },
        { "movnti",         2,              { aptb2MOVNTI.ptr } },
        { "movntpd",        2,              { aptb2MOVNTPD.ptr } },
        { "movntps",        2,              { aptb2MOVNTPS.ptr } },
        { "movntq",         2,              { aptb2MOVNTQ.ptr } },
        { "movq",           2,              { aptb2MOVQ.ptr } },
        { "movq2dq",        2,              { aptb2MOVQ2DQ.ptr } },
        { "movs",           2,              { aptb2MOVS.ptr } },
        { "movsb",          0,              { aptb0MOVSB.ptr } },
        { "movsd",          ITopt | 2,      { aptb2MOVSD.ptr } },
        { "movshdup",       2,              { aptb2MOVSHDUP.ptr } },
        { "movsldup",       2,              { aptb2MOVSLDUP.ptr } },
        { "movsq",          0,              { aptb0MOVSQ.ptr } },
        { "movss",          2,              { aptb2MOVSS.ptr } },
        { "movsw",          0,              { aptb0MOVSW.ptr } },
        { "movsx",          2,              { aptb2MOVSX.ptr } },
        { "movsxd",         2,              { aptb2MOVSXD.ptr } },
        { "movupd",         2,              { aptb2MOVUPD.ptr } },
        { "movups",         2,              { aptb2MOVUPS.ptr } },
        { "movzx",          2,              { aptb2MOVZX.ptr } },
        { "mpsadbw",        3,              { aptb3MPSADBW.ptr } },
        { "mul",            ITopt | 2,      { aptb2MUL.ptr } },
        { "mulpd",          2,              { aptb2MULPD.ptr } },
        { "mulps",          2,              { aptb2MULPS.ptr } },
        { "mulsd",          2,              { aptb2MULSD.ptr } },
        { "mulss",          2,              { aptb2MULSS.ptr } },
        { "mwait",          0,              { aptb0MWAIT.ptr } },
        { "neg",            1,              { aptb1NEG.ptr } },
        { "nop",            0,              { aptb0NOP.ptr } },
        { "not",            1,              { aptb1NOT.ptr } },
        { "or",             2,              { aptb2OR.ptr } },
        { "orpd",           2,              { aptb2ORPD.ptr } },
        { "orps",           2,              { aptb2ORPS.ptr } },
        { "out",            2,              { aptb2OUT.ptr } },
        { "outs",           2,              { aptb2OUTS.ptr } },
        { "outsb",          0,              { aptb0OUTSB.ptr } },
        { "outsd",          0,              { aptb0OUTSD.ptr } },
        { "outsw",          0,              { aptb0OUTSW.ptr } },
        { "pabsb",          2,              { aptb2PABSB.ptr } },
        { "pabsd",          2,              { aptb2PABSD.ptr } },
        { "pabsw",          2,              { aptb2PABSW.ptr } },
        { "packssdw",       2,              { aptb2PACKSSDW.ptr } },
        { "packsswb",       2,              { aptb2PACKSSWB.ptr } },
        { "packusdw",       2,              { aptb2PACKUSDW.ptr } },
        { "packuswb",       2,              { aptb2PACKUSWB.ptr } },
        { "paddb",          2,              { aptb2PADDB.ptr } },
        { "paddd",          2,              { aptb2PADDD.ptr } },
        { "paddq",          2,              { aptb2PADDQ.ptr } },
        { "paddsb",         2,              { aptb2PADDSB.ptr } },
        { "paddsw",         2,              { aptb2PADDSW.ptr } },
        { "paddusb",        2,              { aptb2PADDUSB.ptr } },
        { "paddusw",        2,              { aptb2PADDUSW.ptr } },
        { "paddw",          2,              { aptb2PADDW.ptr } },
        { "palignr",        3,              { aptb3PALIGNR.ptr } },
        { "pand",           2,              { aptb2PAND.ptr } },
        { "pandn",          2,              { aptb2PANDN.ptr } },
        { "pause",          0,              { aptb0PAUSE.ptr } },
        { "pavgb",          2,              { aptb2PAVGB.ptr } },
        { "pavgusb",        2,              { aptb2PAVGUSB.ptr } },
        { "pavgw",          2,              { aptb2PAVGW.ptr } },
        { "pblendvb",       3,              { aptb3PBLENDVB.ptr } },
        { "pblendw",        3,              { aptb3PBLENDW.ptr } },
        { "pclmulqdq",      3,              { aptb3PCLMULQDQ.ptr } },
        { "pcmpeqb",        2,              { aptb2PCMPEQB.ptr } },
        { "pcmpeqd",        2,              { aptb2PCMPEQD.ptr } },
        { "pcmpeqq",        2,              { aptb2PCMPEQQ.ptr } },
        { "pcmpeqw",        2,              { aptb2PCMPEQW.ptr } },
        { "pcmpestri",      3,              { aptb3PCMPESTRI.ptr } },
        { "pcmpestrm",      3,              { aptb3PCMPESTRM.ptr } },
        { "pcmpgtb",        2,              { aptb2PCMPGTB.ptr } },
        { "pcmpgtd",        2,              { aptb2PCMPGTD.ptr } },
        { "pcmpgtq",        2,              { aptb2PCMPGTQ.ptr } },
        { "pcmpgtw",        2,              { aptb2PCMPGTW.ptr } },
        { "pcmpistri",      3,              { aptb3PCMPISTRI.ptr } },
        { "pcmpistrm",      3,              { aptb3PCMPISTRM.ptr } },
        { "pextrb",         3,              { aptb3PEXTRB.ptr } },
        { "pextrd",         3,              { aptb3PEXTRD.ptr } },
        { "pextrq",         3,              { aptb3PEXTRQ.ptr } },
        { "pextrw",         3,              { aptb3PEXTRW.ptr } },
        { "pf2id",          2,              { aptb2PF2ID.ptr } },
        { "pfacc",          2,              { aptb2PFACC.ptr } },
        { "pfadd",          2,              { aptb2PFADD.ptr } },
        { "pfcmpeq",        2,              { aptb2PFCMPEQ.ptr } },
        { "pfcmpge",        2,              { aptb2PFCMPGE.ptr } },
        { "pfcmpgt",        2,              { aptb2PFCMPGT.ptr } },
        { "pfmax",          2,              { aptb2PFMAX.ptr } },
        { "pfmin",          2,              { aptb2PFMIN.ptr } },
        { "pfmul",          2,              { aptb2PFMUL.ptr } },
        { "pfnacc",         2,              { aptb2PFNACC.ptr } },
        { "pfpnacc",        2,              { aptb2PFPNACC.ptr } },
        { "pfrcp",          2,              { aptb2PFRCP.ptr } },
        { "pfrcpit1",       2,              { aptb2PFRCPIT1.ptr } },
        { "pfrcpit2",       2,              { aptb2PFRCPIT2.ptr } },
        { "pfrsqit1",       2,              { aptb2PFRSQIT1.ptr } },
        { "pfrsqrt",        2,              { aptb2PFRSQRT.ptr } },
        { "pfsub",          2,              { aptb2PFSUB.ptr } },
        { "pfsubr",         2,              { aptb2PFSUBR.ptr } },
        { "phaddd",         2,              { aptb2PHADDD.ptr } },
        { "phaddsw",        2,              { aptb2PHADDSW.ptr } },
        { "phaddw",         2,              { aptb2PHADDW.ptr } },
        { "phminposuw",     2,              { aptb2PHMINPOSUW.ptr } },
        { "phsubd",         2,              { aptb2PHSUBD.ptr } },
        { "phsubsw",        2,              { aptb2PHSUBSW.ptr } },
        { "phsubw",         2,              { aptb2PHSUBW.ptr } },
        { "pi2fd",          2,              { aptb2PI2FD.ptr } },
        { "pinsrb",         3,              { aptb3PINSRB.ptr } },
        { "pinsrd",         3,              { aptb3PINSRD.ptr } },
        { "pinsrq",         3,              { aptb3PINSRQ.ptr } },
        { "pinsrw",         3,              { aptb3PINSRW.ptr } },
        { "pmaddubsw",      2,              { aptb2PMADDUBSW.ptr } },
        { "pmaddwd",        2,              { aptb2PMADDWD.ptr } },
        { "pmaxsb",         2,              { aptb2PMAXSB.ptr } },
        { "pmaxsd",         2,              { aptb2PMAXSD.ptr } },
        { "pmaxsw",         2,              { aptb2PMAXSW.ptr } },
        { "pmaxub",         2,              { aptb2PMAXUB.ptr } },
        { "pmaxud",         2,              { aptb2PMAXUD.ptr } },
        { "pmaxuw",         2,              { aptb2PMAXUW.ptr } },
        { "pminsb",         2,              { aptb2PMINSB.ptr } },
        { "pminsd",         2,              { aptb2PMINSD.ptr } },
        { "pminsw",         2,              { aptb2PMINSW.ptr } },
        { "pminub",         2,              { aptb2PMINUB.ptr } },
        { "pminud",         2,              { aptb2PMINUD.ptr } },
        { "pminuw",         2,              { aptb2PMINUW.ptr } },
        { "pmovmskb",       2,              { aptb2PMOVMSKB.ptr } },
        { "pmovsxbd",       2,              { aptb2PMOVSXBD.ptr } },
        { "pmovsxbq",       2,              { aptb2PMOVSXBQ.ptr } },
        { "pmovsxbw",       2,              { aptb2PMOVSXBW.ptr } },
        { "pmovsxdq",       2,              { aptb2PMOVSXDQ.ptr } },
        { "pmovsxwd",       2,              { aptb2PMOVSXWD.ptr } },
        { "pmovsxwq",       2,              { aptb2PMOVSXWQ.ptr } },
        { "pmovzxbd",       2,              { aptb2PMOVZXBD.ptr } },
        { "pmovzxbq",       2,              { aptb2PMOVZXBQ.ptr } },
        { "pmovzxbw",       2,              { aptb2PMOVZXBW.ptr } },
        { "pmovzxdq",       2,              { aptb2PMOVZXDQ.ptr } },
        { "pmovzxwd",       2,              { aptb2PMOVZXWD.ptr } },
        { "pmovzxwq",       2,              { aptb2PMOVZXWQ.ptr } },
        { "pmuldq",         2,              { aptb2PMULDQ.ptr } },
        { "pmulhrsw",       2,              { aptb2PMULHRSW.ptr } },
        { "pmulhrw",        2,              { aptb2PMULHRW.ptr } },
        { "pmulhuw",        2,              { aptb2PMULHUW.ptr } },
        { "pmulhw",         2,              { aptb2PMULHW.ptr } },
        { "pmulld",         2,              { aptb2PMULLD.ptr } },
        { "pmullw",         2,              { aptb2PMULLW.ptr } },
        { "pmuludq",        2,              { aptb2PMULUDQ.ptr } },
        { "pop",            1,              { aptb1POP.ptr } },
        { "popa",           0,              { aptb0POPA.ptr } },
        { "popad",          0,              { aptb0POPAD.ptr } },
        { "popcnt",         2,              { aptb2POPCNT.ptr } },
        { "popf",           0,              { aptb0POPF.ptr } },
        { "popfd",          0,              { aptb0POPFD.ptr } },
        { "popfq",          0,              { aptb0POPFQ.ptr } },
        { "por",            2,              { aptb2POR.ptr } },
        { "prefetchnta",    1,              { aptb1PREFETCHNTA.ptr } },
        { "prefetcht0",     1,              { aptb1PREFETCHT0.ptr } },
        { "prefetcht1",     1,              { aptb1PREFETCHT1.ptr } },
        { "prefetcht2",     1,              { aptb1PREFETCHT2.ptr } },
        { "prefetchw",      1,              { aptb1PREFETCHW.ptr } },
        { "prefetchwt1",    1,              { aptb1PREFETCHWT1.ptr } },
        { "psadbw",         2,              { aptb2PSADBW.ptr } },
        { "pshufb",         2,              { aptb2PSHUFB.ptr } },
        { "pshufd",         3,              { aptb3PSHUFD.ptr } },
        { "pshufhw",        3,              { aptb3PSHUFHW.ptr } },
        { "pshuflw",        3,              { aptb3PSHUFLW.ptr } },
        { "pshufw",         3,              { aptb3PSHUFW.ptr } },
        { "psignb",         2,              { aptb2PSIGNB.ptr } },
        { "psignd",         2,              { aptb2PSIGND.ptr } },
        { "psignw",         2,              { aptb2PSIGNW.ptr } },
        { "pslld",          2,              { aptb2PSLLD.ptr } },
        { "pslldq",         2,              { aptb2PSLLDQ.ptr } },
        { "psllq",          2,              { aptb2PSLLQ.ptr } },
        { "psllw",          2,              { aptb2PSLLW.ptr } },
        { "psrad",          2,              { aptb2PSRAD.ptr } },
        { "psraw",          2,              { aptb2PSRAW.ptr } },
        { "psrld",          2,              { aptb2PSRLD.ptr } },
        { "psrldq",         2,              { aptb2PSRLDQ.ptr } },
        { "psrlq",          2,              { aptb2PSRLQ.ptr } },
        { "psrlw",          2,              { aptb2PSRLW.ptr } },
        { "psubb",          2,              { aptb2PSUBB.ptr } },
        { "psubd",          2,              { aptb2PSUBD.ptr } },
        { "psubq",          2,              { aptb2PSUBQ.ptr } },
        { "psubsb",         2,              { aptb2PSUBSB.ptr } },
        { "psubsw",         2,              { aptb2PSUBSW.ptr } },
        { "psubusb",        2,              { aptb2PSUBUSB.ptr } },
        { "psubusw",        2,              { aptb2PSUBUSW.ptr } },
        { "psubw",          2,              { aptb2PSUBW.ptr } },
        { "pswapd",         2,              { aptb2PSWAPD.ptr } },
        { "ptest",          2,              { aptb2PTEST.ptr } },
        { "punpckhbw",      2,              { aptb2PUNPCKHBW.ptr } },
        { "punpckhdq",      2,              { aptb2PUNPCKHDQ.ptr } },
        { "punpckhqdq",     2,              { aptb2PUNPCKHQDQ.ptr } },
        { "punpckhwd",      2,              { aptb2PUNPCKHWD.ptr } },
        { "punpcklbw",      2,              { aptb2PUNPCKLBW.ptr } },
        { "punpckldq",      2,              { aptb2PUNPCKLDQ.ptr } },
        { "punpcklqdq",     2,              { aptb2PUNPCKLQDQ.ptr } },
        { "punpcklwd",      2,              { aptb2PUNPCKLWD.ptr } },
        { "push",           1,              { aptb1PUSH.ptr } },
        { "pusha",          0,              { aptb0PUSHA.ptr } },
        { "pushad",         0,              { aptb0PUSHAD.ptr } },
        { "pushf",          0,              { aptb0PUSHF.ptr } },
        { "pushfd",         0,              { aptb0PUSHFD.ptr } },
        { "pushfq",         0,              { aptb0PUSHFQ.ptr } },
        { "pxor",           2,              { aptb2PXOR.ptr } },
        { "rcl",            ITshift | 2,    { aptb2RCL.ptr } },
        { "rcpps",          2,              { aptb2RCPPS.ptr } },
        { "rcpss",          2,              { aptb2RCPSS.ptr } },
        { "rcr",            ITshift | 2,    { aptb2RCR.ptr } },
        { "rdfsbase",       1,              { aptb1RDFSBASE.ptr } },
        { "rdgsbase",       1,              { aptb1RDGSBASE.ptr } },
        { "rdmsr",          0,              { aptb0RDMSR.ptr } },
        { "rdpmc",          0,              { aptb0RDPMC.ptr } },
        { "rdrand",         1,              { aptb1RDRAND.ptr } },
        { "rdseed",         1,              { aptb1RDSEED.ptr } },
        { "rdtsc",          0,              { aptb0RDTSC.ptr } },
        { "rdtscp",         0,              { aptb0RDTSCP.ptr } },
        { "rep",            ITprefix | 0,   { aptb0REP.ptr } },
        { "repe",           ITprefix | 0,   { aptb0REP.ptr } },
        { "repne",          ITprefix | 0,   { aptb0REPNE.ptr } },
        { "repnz",          ITprefix | 0,   { aptb0REPNE.ptr } },
        { "repz",           ITprefix | 0,   { aptb0REP.ptr } },
        { "ret",            ITopt | 1,      { aptb1RET.ptr } },
        { "retf",           ITopt | 1,      { aptb1RETF.ptr } },
        { "rol",            ITshift | 2,    { aptb2ROL.ptr } },
        { "ror",            ITshift | 2,    { aptb2ROR.ptr } },
        { "roundpd",        3,              { aptb3ROUNDPD.ptr } },
        { "roundps",        3,              { aptb3ROUNDPS.ptr } },
        { "roundsd",        3,              { aptb3ROUNDSD.ptr } },
        { "roundss",        3,              { aptb3ROUNDSS.ptr } },
        { "rsm",            0,              { aptb0RSM.ptr } },
        { "rsqrtps",        2,              { aptb2RSQRTPS.ptr } },
        { "rsqrtss",        2,              { aptb2RSQRTSS.ptr } },
        { "sahf",           0,              { aptb0SAHF.ptr } },
        { "sal",            ITshift | 2,    { aptb2SHL.ptr } },
        { "sar",            ITshift | 2,    { aptb2SAR.ptr } },
        { "sbb",            2,              { aptb2SBB.ptr } },
        { "scas",           1,              { aptb1SCAS.ptr } },
        { "scasb",          0,              { aptb0SCASB.ptr } },
        { "scasd",          0,              { aptb0SCASD.ptr } },
        { "scasq",          0,              { aptb0SCASQ.ptr } },
        { "scasw",          0,              { aptb0SCASW.ptr } },
        { "seta",           1,              { aptb1SETNBE.ptr } },
        { "setae",          1,              { aptb1SETNB.ptr } },
        { "setb",           1,              { aptb1SETB.ptr } },
        { "setbe",          1,              { aptb1SETBE.ptr } },
        { "setc",           1,              { aptb1SETB.ptr } },
        { "sete",           1,              { aptb1SETZ.ptr } },
        { "setg",           1,              { aptb1SETNLE.ptr } },
        { "setge",          1,              { aptb1SETNL.ptr } },
        { "setl",           1,              { aptb1SETL.ptr } },
        { "setle",          1,              { aptb1SETLE.ptr } },
        { "setna",          1,              { aptb1SETBE.ptr } },
        { "setnae",         1,              { aptb1SETB.ptr } },
        { "setnb",          1,              { aptb1SETNB.ptr } },
        { "setnbe",         1,              { aptb1SETNBE.ptr } },
        { "setnc",          1,              { aptb1SETNB.ptr } },
        { "setne",          1,              { aptb1SETNZ.ptr } },
        { "setng",          1,              { aptb1SETLE.ptr } },
        { "setnge",         1,              { aptb1SETL.ptr } },
        { "setnl",          1,              { aptb1SETNL.ptr } },
        { "setnle",         1,              { aptb1SETNLE.ptr } },
        { "setno",          1,              { aptb1SETNO.ptr } },
        { "setnp",          1,              { aptb1SETNP.ptr } },
        { "setns",          1,              { aptb1SETNS.ptr } },
        { "setnz",          1,              { aptb1SETNZ.ptr } },
        { "seto",           1,              { aptb1SETO.ptr } },
        { "setp",           1,              { aptb1SETP.ptr } },
        { "setpe",          1,              { aptb1SETP.ptr } },
        { "setpo",          1,              { aptb1SETNP.ptr } },
        { "sets",           1,              { aptb1SETS.ptr } },
        { "setz",           1,              { aptb1SETZ.ptr } },
        { "sfence",         0,              { aptb0SFENCE.ptr } },
        { "sgdt",           1,              { aptb1SGDT.ptr } },
        { "sha1msg1",       2,              { aptb2SHA1MSG1.ptr } },
        { "sha1msg2",       2,              { aptb2SHA1MSG2.ptr } },
        { "sha1nexte",      2,              { aptb2SHA1NEXTE.ptr } },
        { "sha1rnds4",      3,              { aptb3SHA1RNDS4.ptr } },
        { "sha256msg1",     2,              { aptb2SHA256MSG1.ptr } },
        { "sha256msg2",     2,              { aptb2SHA256MSG2.ptr } },
        { "sha256rnds2",    2,              { aptb2SHA256RNDS2.ptr } },
        { "shl",            ITshift | 2,    { aptb2SHL.ptr } },
        { "shld",           3,              { aptb3SHLD.ptr } },
        { "shr",            ITshift | 2,    { aptb2SHR.ptr } },
        { "shrd",           3,              { aptb3SHRD.ptr } },
        { "shufpd",         3,              { aptb3SHUFPD.ptr } },
        { "shufps",         3,              { aptb3SHUFPS.ptr } },
        { "sidt",           1,              { aptb1SIDT.ptr } },
        { "sldt",           1,              { aptb1SLDT.ptr } },
        { "smsw",           1,              { aptb1SMSW.ptr } },
        { "sqrtpd",         2,              { aptb2SQRTPD.ptr } },
        { "sqrtps",         2,              { aptb2SQRTPS.ptr } },
        { "sqrtsd",         2,              { aptb2SQRTSD.ptr } },
        { "sqrtss",         2,              { aptb2SQRTSS.ptr } },
        { "stc",            0,              { aptb0STC.ptr } },
        { "std",            0,              { aptb0STD.ptr } },
        { "sti",            0,              { aptb0STI.ptr } },
        { "stmxcsr",        1,              { aptb1STMXCSR.ptr } },
        { "stos",           1,              { aptb1STOS.ptr } },
        { "stosb",          0,              { aptb0STOSB.ptr } },
        { "stosd",          0,              { aptb0STOSD.ptr } },
        { "stosq",          0,              { aptb0STOSQ.ptr } },
        { "stosw",          0,              { aptb0STOSW.ptr } },
        { "str",            1,              { aptb1STR.ptr } },
        { "sub",            2,              { aptb2SUB.ptr } },
        { "subpd",          2,              { aptb2SUBPD.ptr } },
        { "subps",          2,              { aptb2SUBPS.ptr } },
        { "subsd",          2,              { aptb2SUBSD.ptr } },
        { "subss",          2,              { aptb2SUBSS.ptr } },
        { "syscall",        0,              { aptb0SYSCALL.ptr } },
        { "sysenter",       0,              { aptb0SYSENTER.ptr } },
        { "sysexit",        0,              { aptb0SYSEXIT.ptr } },
        { "sysret",         0,              { aptb0SYSRET.ptr } },
        { "test",           2,              { aptb2TEST.ptr } },
        { "tzcnt",          2,              { aptb2TZCNT.ptr } },
        { "ucomisd",        2,              { aptb2UCOMISD.ptr } },
        { "ucomiss",        2,              { aptb2UCOMISS.ptr } },
        { "ud2",            0,              { aptb0UD2.ptr } },
        { "unpckhpd",       2,              { aptb2UNPCKHPD.ptr } },
        { "unpckhps",       2,              { aptb2UNPCKHPS.ptr } },
        { "unpcklpd",       2,              { aptb2UNPCKLPD.ptr } },
        { "unpcklps",       2,              { aptb2UNPCKLPS.ptr } },
        { "vaddpd",         3,              { aptb3VADDPD.ptr } },
        { "vaddps",         3,              { aptb3VADDPS.ptr } },
        { "vaddsd",         3,              { aptb3VADDSD.ptr } },
        { "vaddss",         3,              { aptb3VADDSS.ptr } },
        { "vaddsubpd",      3,              { aptb3VADDSUBPD.ptr } },
        { "vaddsubps",      3,              { aptb3VADDSUBPS.ptr } },
        { "vaesdec",        3,              { aptb3VAESDEC.ptr } },
        { "vaesdeclast",    3,              { aptb3VAESDECLAST.ptr } },
        { "vaesenc",        3,              { aptb3VAESENC.ptr } },
        { "vaesenclast",    3,              { aptb3VAESENCLAST.ptr } },
        { "vaesimc",        2,              { aptb2VAESIMC.ptr } },
        { "vaeskeygenassist", 3,            { aptb3VAESKEYGENASSIST.ptr } },
        { "vandnpd",        3,              { aptb3VANDNPD.ptr } },
        { "vandnps",        3,              { aptb3VANDNPS.ptr } },
        { "vandpd",         3,              { aptb3VANDPD.ptr } },
        { "vandps",         3,              { aptb3VANDPS.ptr } },
        { "vblendpd",       4,              { aptb4VBLENDPD.ptr } },
        { "vblendps",       4,              { aptb4VBLENDPS.ptr } },
        { "vblendvpd",      4,              { aptb4VBLENDVPD.ptr } },
        { "vblendvps",      4,              { aptb4VBLENDVPS.ptr } },
        { "vbroadcastf128", 2,              { aptb2VBROADCASTF128.ptr } },
        { "vbroadcastsd",   2,              { aptb2VBROADCASTSD.ptr } },
        { "vbroadcastss",   2,              { aptb2VBROADCASTSS.ptr } },
        { "vcmppd",         4,              { aptb4VCMPPD.ptr } },
        { "vcmpps",         4,              { aptb4VCMPPS.ptr } },
        { "vcmpsd",         4,              { aptb4VCMPSD.ptr } },
        { "vcmpss",         4,              { aptb4VCMPSS.ptr } },
        { "vcomisd",        2,              { aptb2VCOMISD.ptr } },
        { "vcomiss",        2,              { aptb2VCOMISS.ptr } },
        { "vcvtdq2pd",      2,              { aptb2VCVTDQ2PD.ptr } },
        { "vcvtdq2ps",      2,              { aptb2VCVTDQ2PS.ptr } },
        { "vcvtpd2dq",      2,              { aptb2VCVTPD2DQ.ptr } },
        { "vcvtpd2ps",      2,              { aptb2VCVTPD2PS.ptr } },
        { "vcvtph2ps",      2,              { aptb2VCVTPH2PS.ptr } },
        { "vcvtps2dq",      2,              { aptb2VCVTPS2DQ.ptr } },
        { "vcvtps2pd",      2,              { aptb2VCVTPS2PD.ptr } },
        { "vcvtps2ph",      3,              { aptb3VCVTPS2PH.ptr } },
        { "vcvtsd2si",      2,              { aptb2VCVTSD2SI.ptr } },
        { "vcvtsd2ss",      3,              { aptb3VCVTSD2SS.ptr } },
        { "vcvtsi2sd",      3,              { aptb3VCVTSI2SD.ptr } },
        { "vcvtsi2ss",      3,              { aptb3VCVTSI2SS.ptr } },
        { "vcvtss2sd",      3,              { aptb3VCVTSS2SD.ptr } },
        { "vcvtss2si",      2,              { aptb2VCVTSS2SI.ptr } },
        { "vcvttpd2dq",     2,              { aptb2VCVTTPD2DQ.ptr } },
        { "vcvttps2dq",     2,              { aptb2VCVTTPS2DQ.ptr } },
        { "vcvttsd2si",     2,              { aptb2VCVTTSD2SI.ptr } },
        { "vcvttss2si",     2,              { aptb2VCVTTSS2SI.ptr } },
        { "vdivpd",         3,              { aptb3VDIVPD.ptr } },
        { "vdivps",         3,              { aptb3VDIVPS.ptr } },
        { "vdivsd",         3,              { aptb3VDIVSD.ptr } },
        { "vdivss",         3,              { aptb3VDIVSS.ptr } },
        { "vdppd",          4,              { aptb4VDPPD.ptr } },
        { "vdpps",          4,              { aptb4VDPPS.ptr } },
        { "verr",           1,              { aptb1VERR.ptr } },
        { "verw",           1,              { aptb1VERW.ptr } },
        { "vextractf128",   3,              { aptb3VEXTRACTF128.ptr } },
        { "vextractps",     3,              { aptb3VEXTRACTPS.ptr } },
        { "vfmadd132pd",    3,              { aptb3VFMADD132PD.ptr } },
        { "vfmadd132ps",    3,              { aptb3VFMADD132PS.ptr } },
        { "vfmadd132sd",    3,              { aptb3VFMADD132SD.ptr } },
        { "vfmadd132ss",    3,              { aptb3VFMADD132SS.ptr } },
        { "vfmadd213pd",    3,              { aptb3VFMADD213PD.ptr } },
        { "vfmadd213ps",    3,              { aptb3VFMADD213PS.ptr } },
        { "vfmadd213sd",    3,              { aptb3VFMADD213SD.ptr } },
        { "vfmadd213ss",    3,              { aptb3VFMADD213SS.ptr } },
        { "vfmadd231pd",    3,              { aptb3VFMADD231PD.ptr } },
        { "vfmadd231ps",    3,              { aptb3VFMADD231PS.ptr } },
        { "vfmadd231sd",    3,              { aptb3VFMADD231SD.ptr } },
        { "vfmadd231ss",    3,              { aptb3VFMADD231SS.ptr } },
        { "vfmaddsub132pd", 3,              { aptb3VFMADDSUB132PD.ptr } },
        { "vfmaddsub132ps", 3,              { aptb3VFMADDSUB132PS.ptr } },
        { "vfmaddsub213pd", 3,              { aptb3VFMADDSUB213PD.ptr } },
        { "vfmaddsub213ps", 3,              { aptb3VFMADDSUB213PS.ptr } },
        { "vfmaddsub231pd", 3,              { aptb3VFMADDSUB231PD.ptr } },
        { "vfmaddsub231ps", 3,              { aptb3VFMADDSUB231PS.ptr } },
        { "vfmsub132pd",    3,              { aptb3VFMSUB132PD.ptr } },
        { "vfmsub132ps",    3,              { aptb3VFMSUB132PS.ptr } },
        { "vfmsub132sd",    3,              { aptb3VFMSUB132SD.ptr } },
        { "vfmsub132ss",    3,              { aptb3VFMSUB132SS.ptr } },
        { "vfmsub213pd",    3,              { aptb3VFMSUB213PD.ptr } },
        { "vfmsub213ps",    3,              { aptb3VFMSUB213PS.ptr } },
        { "vfmsub213sd",    3,              { aptb3VFMSUB213SD.ptr } },
        { "vfmsub213ss",    3,              { aptb3VFMSUB213SS.ptr } },
        { "vfmsub231pd",    3,              { aptb3VFMSUB231PD.ptr } },
        { "vfmsub231ps",    3,              { aptb3VFMSUB231PS.ptr } },
        { "vfmsub231sd",    3,              { aptb3VFMSUB231SD.ptr } },
        { "vfmsub231ss",    3,              { aptb3VFMSUB231SS.ptr } },
        { "vfmsubadd132pd", 3,              { aptb3VFMSUBADD132PD.ptr } },
        { "vfmsubadd132ps", 3,              { aptb3VFMSUBADD132PS.ptr } },
        { "vfmsubadd213pd", 3,              { aptb3VFMSUBADD213PD.ptr } },
        { "vfmsubadd213ps", 3,              { aptb3VFMSUBADD213PS.ptr } },
        { "vfmsubadd231pd", 3,              { aptb3VFMSUBADD231PD.ptr } },
        { "vfmsubadd231ps", 3,              { aptb3VFMSUBADD231PS.ptr } },
        { "vhaddpd",        3,              { aptb3VHADDPD.ptr } },
        { "vhaddps",        3,              { aptb3VHADDPS.ptr } },
        { "vinsertf128",    4,              { aptb4VINSERTF128.ptr } },
        { "vinsertps",      4,              { aptb4VINSERTPS.ptr } },
        { "vlddqu",         2,              { aptb2VLDDQU.ptr } },
        { "vldmxcsr",       1,              { aptb1VLDMXCSR.ptr } },
        { "vmaskmovdqu",    2,              { aptb2VMASKMOVDQU.ptr } },
        { "vmaskmovpd",     3,              { aptb3VMASKMOVPD.ptr } },
        { "vmaskmovps",     3,              { aptb3VMASKMOVPS.ptr } },
        { "vmaxpd",         3,              { aptb3VMAXPD.ptr } },
        { "vmaxps",         3,              { aptb3VMAXPS.ptr } },
        { "vmaxsd",         3,              { aptb3VMAXSD.ptr } },
        { "vmaxss",         3,              { aptb3VMAXSS.ptr } },
        { "vminpd",         3,              { aptb3VMINPD.ptr } },
        { "vminps",         3,              { aptb3VMINPS.ptr } },
        { "vminsd",         3,              { aptb3VMINSD.ptr } },
        { "vminss",         3,              { aptb3VMINSS.ptr } },
        { "vmovapd",        2,              { aptb2VMOVAPD.ptr } },
        { "vmovaps",        2,              { aptb2VMOVAPS.ptr } },
        { "vmovd",          2,              { aptb2VMOVD.ptr } },
        { "vmovddup",       2,              { aptb2VMOVDDUP.ptr } },
        { "vmovdqa",        2,              { aptb2VMOVDQA.ptr } },
        { "vmovdqu",        2,              { aptb2VMOVDQU.ptr } },
        { "vmovhlps",       3,              { aptb3VMOVHLPS.ptr } },
        { "vmovhpd",        ITopt | 3,      { aptb3VMOVHPD.ptr } },
        { "vmovhps",        ITopt | 3,      { aptb3VMOVHPS.ptr } },
        { "vmovlhps",       3,              { aptb3VMOVLHPS.ptr } },
        { "vmovlpd",        ITopt | 3,      { aptb3VMOVLPD.ptr } },
        { "vmovlps",        ITopt | 3,      { aptb3VMOVLPS.ptr } },
        { "vmovmskpd",      2,              { aptb2VMOVMSKPD.ptr } },
        { "vmovmskps",      2,              { aptb2VMOVMSKPS.ptr } },
        { "vmovntdq",       2,              { aptb2VMOVNTDQ.ptr } },
        { "vmovntdqa",      2,              { aptb2VMOVNTDQA.ptr } },
        { "vmovntpd",       2,              { aptb2VMOVNTPD.ptr } },
        { "vmovntps",       2,              { aptb2VMOVNTPS.ptr } },
        { "vmovq",          2,              { aptb2VMOVQ.ptr } },
        { "vmovsd",         ITopt | 3,      { aptb3VMOVSD.ptr } },
        { "vmovshdup",      2,              { aptb2VMOVSHDUP.ptr } },
        { "vmovsldup",      2,              { aptb2VMOVSLDUP.ptr } },
        { "vmovss",         ITopt | 3,      { aptb3VMOVSS.ptr } },
        { "vmovupd",        2,              { aptb2VMOVUPD.ptr } },
        { "vmovups",        2,              { aptb2VMOVUPS.ptr } },
        { "vmpsadbw",       4,              { aptb4VMPSADBW.ptr } },
        { "vmulpd",         3,              { aptb3VMULPD.ptr } },
        { "vmulps",         3,              { aptb3VMULPS.ptr } },
        { "vmulsd",         3,              { aptb3VMULSD.ptr } },
        { "vmulss",         3,              { aptb3VMULSS.ptr } },
        { "vorpd",          3,              { aptb3VORPD.ptr } },
        { "vorps",          3,              { aptb3VORPS.ptr } },
        { "vpabsb",         2,              { aptb2VPABSB.ptr } },
        { "vpabsd",         2,              { aptb2VPABSD.ptr } },
        { "vpabsw",         2,              { aptb2VPABSW.ptr } },
        { "vpackssdw",      3,              { aptb3VPACKSSDW.ptr } },
        { "vpacksswb",      3,              { aptb3VPACKSSWB.ptr } },
        { "vpackusdw",      3,              { aptb3VPACKUSDW.ptr } },
        { "vpackuswb",      3,              { aptb3VPACKUSWB.ptr } },
        { "vpaddb",         3,              { aptb3VPADDB.ptr } },
        { "vpaddd",         3,              { aptb3VPADDD.ptr } },
        { "vpaddq",         3,              { aptb3VPADDQ.ptr } },
        { "vpaddsb",        3,              { aptb3VPADDSB.ptr } },
        { "vpaddsw",        3,              { aptb3VPADDSW.ptr } },
        { "vpaddusb",       3,              { aptb3VPADDUSB.ptr } },
        { "vpaddusw",       3,              { aptb3VPADDUSW.ptr } },
        { "vpaddw",         3,              { aptb3VPADDW.ptr } },
        { "vpalignr",       4,              { aptb4VPALIGNR.ptr } },
        { "vpand",          3,              { aptb3VPAND.ptr } },
        { "vpandn",         3,              { aptb3VPANDN.ptr } },
        { "vpavgb",         3,              { aptb3VPAVGB.ptr } },
        { "vpavgw",         3,              { aptb3VPAVGW.ptr } },
        { "vpblendvb",      4,              { aptb4VPBLENDVB.ptr } },
        { "vpblendw",       4,              { aptb4VPBLENDW.ptr } },
        { "vpclmulqdq",     4,              { aptb4VPCLMULQDQ.ptr } },
        { "vpcmpeqb",       3,              { aptb3VPCMPEQB.ptr } },
        { "vpcmpeqd",       3,              { aptb3VPCMPEQD.ptr } },
        { "vpcmpeqq",       3,              { aptb3VPCMPEQQ.ptr } },
        { "vpcmpeqw",       3,              { aptb3VPCMPEQW.ptr } },
        { "vpcmpestri",     3,              { aptb3VPCMPESTRI.ptr } },
        { "vpcmpestrm",     3,              { aptb3VPCMPESTRM.ptr } },
        { "vpcmpgtb",       3,              { aptb3VPCMPGTB.ptr } },
        { "vpcmpgtd",       3,              { aptb3VPCMPGTD.ptr } },
        { "vpcmpgtq",       3,              { aptb3VPCMPGTQ.ptr } },
        { "vpcmpgtw",       3,              { aptb3VPCMPGTW.ptr } },
        { "vpcmpistri",     3,              { aptb3VPCMPISTRI.ptr } },
        { "vpcmpistrm",     3,              { aptb3VPCMPISTRM.ptr } },
        { "vperm2f128",     4,              { aptb3VPERM2F128.ptr } },
        { "vpermilpd",      3,              { aptb3VPERMILPD.ptr } },
        { "vpermilps",      3,              { aptb3VPERMILPS.ptr } },
        { "vpextrb",        3,              { aptb3VPEXTRB.ptr } },
        { "vpextrd",        3,              { aptb3VPEXTRD.ptr } },
        { "vpextrq",        3,              { aptb3VPEXTRQ.ptr } },
        { "vpextrw",        3,              { aptb3VPEXTRW.ptr } },
        { "vphaddd",        3,              { aptb3VPHADDD.ptr } },
        { "vphaddsw",       3,              { aptb3VPHADDSW.ptr } },
        { "vphaddw",        3,              { aptb3VPHADDW.ptr } },
        { "vphminposuw",    2,              { aptb2VPHMINPOSUW.ptr } },
        { "vphsubd",        3,              { aptb3VPHSUBD.ptr } },
        { "vphsubsw",       3,              { aptb3VPHSUBSW.ptr } },
        { "vphsubw",        3,              { aptb3VPHSUBW.ptr } },
        { "vpinsrb",        4,              { aptb4VPINSRB.ptr } },
        { "vpinsrd",        4,              { aptb4VPINSRD.ptr } },
        { "vpinsrq",        4,              { aptb4VPINSRQ.ptr } },
        { "vpinsrw",        4,              { aptb4VPINSRW.ptr } },
        { "vpmaddubsw",     3,              { aptb3VPMADDUBSW.ptr } },
        { "vpmaddwd",       3,              { aptb3VPMADDWD.ptr } },
        { "vpmaxsb",        3,              { aptb3VPMAXSB.ptr } },
        { "vpmaxsd",        3,              { aptb3VPMAXSD.ptr } },
        { "vpmaxsw",        3,              { aptb3VPMAXSW.ptr } },
        { "vpmaxub",        3,              { aptb3VPMAXUB.ptr } },
        { "vpmaxud",        3,              { aptb3VPMAXUD.ptr } },
        { "vpmaxuw",        3,              { aptb3VPMAXUW.ptr } },
        { "vpminsb",        3,              { aptb3VPMINSB.ptr } },
        { "vpminsd",        3,              { aptb3VPMINSD.ptr } },
        { "vpminsw",        3,              { aptb3VPMINSW.ptr } },
        { "vpminub",        3,              { aptb3VPMINUB.ptr } },
        { "vpminud",        3,              { aptb3VPMINUD.ptr } },
        { "vpminuw",        3,              { aptb3VPMINUW.ptr } },
        { "vpmovmskb",      2,              { aptb2VPMOVMSKB.ptr } },
        { "vpmovsxbd",      2,              { aptb2VPMOVSXBD.ptr } },
        { "vpmovsxbq",      2,              { aptb2VPMOVSXBQ.ptr } },
        { "vpmovsxbw",      2,              { aptb2VPMOVSXBW.ptr } },
        { "vpmovsxdq",      2,              { aptb2VPMOVSXDQ.ptr } },
        { "vpmovsxwd",      2,              { aptb2VPMOVSXWD.ptr } },
        { "vpmovsxwq",      2,              { aptb2VPMOVSXWQ.ptr } },
        { "vpmovzxbd",      2,              { aptb2VPMOVZXBD.ptr } },
        { "vpmovzxbq",      2,              { aptb2VPMOVZXBQ.ptr } },
        { "vpmovzxbw",      2,              { aptb2VPMOVZXBW.ptr } },
        { "vpmovzxdq",      2,              { aptb2VPMOVZXDQ.ptr } },
        { "vpmovzxwd",      2,              { aptb2VPMOVZXWD.ptr } },
        { "vpmovzxwq",      2,              { aptb2VPMOVZXWQ.ptr } },
        { "vpmuldq",        3,              { aptb3VPMULDQ.ptr } },
        { "vpmulhrsw",      3,              { aptb3VPMULHRSW.ptr } },
        { "vpmulhuw",       3,              { aptb3VPMULHUW.ptr } },
        { "vpmulhw",        3,              { aptb3VPMULHW.ptr } },
        { "vpmulld",        3,              { aptb3VPMULLD.ptr } },
        { "vpmullw",        3,              { aptb3VPMULLW.ptr } },
        { "vpmuludq",       3,              { aptb3VPMULUDQ.ptr } },
        { "vpor",           3,              { aptb3VPOR.ptr } },
        { "vpsadbw",        3,              { aptb3VPSADBW.ptr } },
        { "vpshufb",        3,              { aptb3VPSHUFB.ptr } },
        { "vpshufd",        3,              { aptb3VPSHUFD.ptr } },
        { "vpshufhw",       3,              { aptb3VPSHUFHW.ptr } },
        { "vpshuflw",       3,              { aptb3VPSHUFLW.ptr } },
        { "vpsignb",        3,              { aptb3VPSIGNB.ptr } },
        { "vpsignd",        3,              { aptb3VPSIGND.ptr } },
        { "vpsignw",        3,              { aptb3VPSIGNW.ptr } },
        { "vpslld",         3,              { aptb3VPSLLD.ptr } },
        { "vpslldq",        3,              { aptb3VPSLLDQ.ptr } },
        { "vpsllq",         3,              { aptb3VPSLLQ.ptr } },
        { "vpsllw",         3,              { aptb3VPSLLW.ptr } },
        { "vpsrad",         3,              { aptb3VPSRAD.ptr } },
        { "vpsraw",         3,              { aptb3VPSRAW.ptr } },
        { "vpsrld",         3,              { aptb3VPSRLD.ptr } },
        { "vpsrldq",        3,              { aptb3VPSRLDQ.ptr } },
        { "vpsrlq",         3,              { aptb3VPSRLQ.ptr } },
        { "vpsrlw",         3,              { aptb3VPSRLW.ptr } },
        { "vpsubb",         3,              { aptb3VPSUBB.ptr } },
        { "vpsubd",         3,              { aptb3VPSUBD.ptr } },
        { "vpsubq",         3,              { aptb3VPSUBQ.ptr } },
        { "vpsubsb",        3,              { aptb3VPSUBSB.ptr } },
        { "vpsubsw",        3,              { aptb3VPSUBSW.ptr } },
        { "vpsubusb",       3,              { aptb3VPSUBUSB.ptr } },
        { "vpsubusw",       3,              { aptb3VPSUBUSW.ptr } },
        { "vpsubw",         3,              { aptb3VPSUBW.ptr } },
        { "vptest",         2,              { aptb2VPTEST.ptr } },
        { "vpunpckhbw",     3,              { aptb3VPUNPCKHBW.ptr } },
        { "vpunpckhdq",     3,              { aptb3VPUNPCKHDQ.ptr } },
        { "vpunpckhqdq",    3,              { aptb3VPUNPCKHQDQ.ptr } },
        { "vpunpckhwd",     3,              { aptb3VPUNPCKHWD.ptr } },
        { "vpunpcklbw",     3,              { aptb3VPUNPCKLBW.ptr } },
        { "vpunpckldq",     3,              { aptb3VPUNPCKLDQ.ptr } },
        { "vpunpcklqdq",    3,              { aptb3VPUNPCKLQDQ.ptr } },
        { "vpunpcklwd",     3,              { aptb3VPUNPCKLWD.ptr } },
        { "vpxor",          3,              { aptb3VPXOR.ptr } },
        { "vrcpps",         2,              { aptb2VRCPPS.ptr } },
        { "vrcpss",         3,              { aptb3VRCPSS.ptr } },
        { "vroundpd",       3,              { aptb3VROUNDPD.ptr } },
        { "vroundps",       3,              { aptb3VROUNDPS.ptr } },
        { "vroundsd",       4,              { aptb4VROUNDSD.ptr } },
        { "vroundss",       4,              { aptb4VROUNDSS.ptr } },
        { "vshufpd",        4,              { aptb4VSHUFPD.ptr } },
        { "vshufps",        4,              { aptb4VSHUFPS.ptr } },
        { "vsqrtpd",        2,              { aptb2VSQRTPD.ptr } },
        { "vsqrtps",        2,              { aptb2VSQRTPS.ptr } },
        { "vsqrtsd",        3,              { aptb3VSQRTSD.ptr } },
        { "vsqrtss",        3,              { aptb3VSQRTSS.ptr } },
        { "vstmxcsr",       1,              { aptb1VSTMXCSR.ptr } },
        { "vsubpd",         3,              { aptb3VSUBPD.ptr } },
        { "vsubps",         3,              { aptb3VSUBPS.ptr } },
        { "vsubsd",         3,              { aptb3VSUBSD.ptr } },
        { "vsubss",         3,              { aptb3VSUBSS.ptr } },
        { "vucomisd",       2,              { aptb2VUCOMISD.ptr } },
        { "vucomiss",       2,              { aptb2VUCOMISS.ptr } },
        { "vunpckhpd",      3,              { aptb3VUNPCKHPD.ptr } },
        { "vunpckhps",      3,              { aptb3VUNPCKHPS.ptr } },
        { "vunpcklpd",      3,              { aptb3VUNPCKLPD.ptr } },
        { "vunpcklps",      3,              { aptb3VUNPCKLPS.ptr } },
        { "vxorpd",         3,              { aptb3VXORPD.ptr } },
        { "vxorps",         3,              { aptb3VXORPS.ptr } },
        { "vzeroall",       0,              { aptb0VZEROALL.ptr } },
        { "vzeroupper",     0,              { aptb0VZEROUPPER.ptr } },
        { "wait",           0,              { aptb0WAIT.ptr } },
        { "wbinvd",         0,              { aptb0WBINVD.ptr } },
        { "wrfsbase",       1,              { aptb1WRFSBASE.ptr } },
        { "wrgsbase",       1,              { aptb1WRGSBASE.ptr } },
        { "wrmsr",          0,              { aptb0WRMSR.ptr } },
        { "xadd",           2,              { aptb2XADD.ptr } },
        { "xchg",           2,              { aptb2XCHG.ptr } },
        { "xgetbv",         0,              { aptb0XGETBV.ptr } },
        { "xlat",           ITopt | 1,      { aptb1XLAT.ptr } },
        { "xlatb",          0,              { aptb0XLATB.ptr } },
        { "xor",            2,              { aptb2XOR.ptr } },
        { "xorpd",          2,              { aptb2XORPD.ptr } },
        { "xorps",          2,              { aptb2XORPS.ptr } },
        { "xrstor",         ITfloat | 1,    { aptb1XRSTOR.ptr } },
        { "xrstor64",       ITfloat | 1,    { aptb1XRSTOR64.ptr } },
        { "xsave",          ITfloat | 1,    { aptb1XSAVE.ptr } },
        { "xsave64",        ITfloat | 1,    { aptb1XSAVE64.ptr } },
        { "xsavec",         ITfloat | 1,    { aptb1XSAVEC.ptr } },
        { "xsavec64",       ITfloat | 1,    { aptb1XSAVEC64.ptr } },
        { "xsaveopt",       ITfloat | 1,    { aptb1XSAVEOPT.ptr } },
        { "xsaveopt64",     ITfloat | 1,    { aptb1XSAVEOPT64.ptr } },
        { "xsetbv",         0,              { aptb0XSETBV.ptr } },
];

/*******************************
 */

extern (C++) const(char)* asm_opstr(OP *pop)
{
    return pop.str;
}

/*******************************
 */

@trusted
extern (C++) OP *asm_op_lookup(const(char)* s)
{
    int i;
    char[20] szBuf = void;

    //printf("asm_op_lookup('%s')\n",s);
    if (strlen(s) >= szBuf.length)
        return null;
    strcpy(szBuf.ptr,s);

    version (SCPP)
        strlwr(szBuf.ptr);

    i = binary(szBuf.ptr,optab);
    return (i == -1) ? null : cast(OP*)&optab[i];
}

/*******************************
 */

@trusted
extern (C++) void init_optab()
{   int i;

    debug
    for (i = 0; i < optab.length - 1; i++)
    {
        if (strcmp(optab[i].str,optab[i + 1].str) >= 0)
        {
            printf("optab[%d] = '%s', [%d] = '%s'\n",i,optab[i].str,i + 1,optab[i + 1].str);
            assert(0);
        }
    }
}

@trusted
private int binary(const(char)* p, const OP[] table)
{
    int low = 0;
    char cp = *p;
    int high = cast(int)(table.length) - 1;
    p++;

    while (low <= high)
    {
        const mid = (low + high) >> 1;
        int cond = table[mid].str[0] - cp;
        if (cond == 0)
            cond = strcmp(table[mid].str + 1,p);
        if (cond > 0)
            high = mid - 1;
        else if (cond < 0)
            low = mid + 1;
        else
            return cast(int)mid;                 /* match index                  */
    }
    return -1;
}


}
