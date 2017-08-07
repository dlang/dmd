/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1992-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     Mike Cote, John Micco, $(LINK2 http://www.digitalmars.com, Walter Bright),
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/iasm.h
 */

#include <setjmp.h>

/////////////////////////////////////////////////
// Instruction flags (usFlags)
//
//

// This is for when the reg field of modregrm specifies which instruction it is
#define NUM_MASK        0x7
#define NUM_MASKR       0x8             // for REX extended registers
#define _0      (0x0 | _modrm)          // insure that some _modrm bit is set
#define _1      0x1                     // with _0
#define _2      0x2
#define _3      0x3
#define _4      0x4
#define _5      0x5
#define _6      0x6
#define _7      0x7

#define _modrm  0x10

#define _r      _modrm
#define _cb     _modrm
#define _cw     _modrm
#define _cd     _modrm
#define _cq     _modrm
#define _cp     _modrm
#define _ib     0
#define _iw     0
#define _id     0
#define _rb     0
#define _rw     0
#define _rd     0
#define _16_bit 0x20
#define _32_bit 0x40
#define _64_bit 0x10000
#define _i64_bit 0x20000        // opcode is invalid in 64bit mode
#define _I386   0x80            // opcode is only for 386 and later
#define _16_bit_addr    0x100
#define _32_bit_addr    0x200
#define _fwait 0x400    // Add an FWAIT prior to the instruction opcode
#define _nfwait 0x800   // Do not add an FWAIT prior to the instruction

#define MOD_MASK        0xF000  // Mod mask
#define _modsi          0x1000  // Instruction modifies SI
#define _moddx          0x2000  // Instruction modifies DX
#define _mod2           0x3000  // Instruction modifies second operand
#define _modax          0x4000  // Instruction modifies AX
#define _modnot1        0x5000  // Instruction does not modify first operand
#define _modaxdx        0x6000  // instruction modifies AX and DX
#define _moddi          0x7000  // Instruction modifies DI
#define _modsidi        0x8000  // Instruction modifies SI and DI
#define _modcx          0x9000  // Instruction modifies CX
#define _modes          0xa000  // Instruction modifies ES
#define _modall         0xb000  // Instruction modifies all register values
#define _modsiax        0xc000  // Instruction modifies AX and SI
#define _modsinot1      0xd000  // Instruction modifies SI and not first param
#define _modcxr11       0xe000  // Instruction modifies CX and R11
#define _modxmm0        0xf000  // Instruction modifies XMM0

// translates opcode into equivalent vex encoding
#define VEX_128_W0(op)            (_VEX(op)|_VEX_NOO)
#define VEX_128_W1(op)            (_VEX(op)|_VEX_NOO|_VEX_W)
#define VEX_128_WIG(op)            VEX_128_W0(op)
#define VEX_256_W0(op)            (_VEX(op)|_VEX_NOO|_VEX_L)
#define VEX_256_W1(op)            (_VEX(op)|_VEX_NOO|_VEX_W|_VEX_L)
#define VEX_256_WIG(op)            VEX_256_W0(op)
#define VEX_NDS_128_W0(op)        (_VEX(op)|_VEX_NDS)
#define VEX_NDS_128_W1(op)        (_VEX(op)|_VEX_NDS|_VEX_W)
#define VEX_NDS_128_WIG(op)        VEX_NDS_128_W0(op)
#define VEX_NDS_256_W0(op)        (_VEX(op)|_VEX_NDS|_VEX_L)
#define VEX_NDS_256_W1(op)        (_VEX(op)|_VEX_NDS|_VEX_W|_VEX_L)
#define VEX_NDS_256_WIG(op)        VEX_NDS_256_W0(op)
#define VEX_NDD_128_W0(op)        (_VEX(op)|_VEX_NDD)
#define VEX_NDD_128_W1(op)        (_VEX(op)|_VEX_NDD|_VEX_W)
#define VEX_NDD_128_WIG(op)        VEX_NDD_128_W0(op)
#define VEX_NDD_256_W0(op)        (_VEX(op)|_VEX_NDD|_VEX_L)
#define VEX_NDD_256_W1(op)        (_VEX(op)|_VEX_NDD|_VEX_W|_VEX_L)
#define VEX_NDD_256_WIG(op)        VEX_NDD_256_W0(op)
#define VEX_DDS_128_W0(op)        (_VEX(op)|_VEX_DDS)
#define VEX_DDS_128_W1(op)        (_VEX(op)|_VEX_DDS|_VEX_W)
#define VEX_DDS_128_WIG(op)        VEX_DDS_128_W0(op)
#define VEX_DDS_256_W0(op)        (_VEX(op)|_VEX_DDS|_VEX_L)
#define VEX_DDS_256_W1(op)        (_VEX(op)|_VEX_DDS|_VEX_W|_VEX_L)
#define VEX_DDS_256_WIG(op)        VEX_DDS_256_W0(op)

#define _VEX_W   0x8000
/* Don't encode LIG/LZ use 128 for these.
 */
#define _VEX_L   0x0400
/* Encode nds, ndd, dds in the vvvv field, it gets
 * overwritten with the actual register later.
 */
#define  VEX_NOO 0 // neither of nds, ndd, dds
#define  VEX_NDS 1
#define  VEX_NDD 2
#define  VEX_DDS 3
#define _VEX_NOO  (  VEX_NOO << 11)
#define _VEX_NDS  (  VEX_NDS << 11)
#define _VEX_NDD  (  VEX_NDD << 11)
#define _VEX_DDS  (  VEX_DDS << 11)

#define _VEX(op) (0xC4 << 24 | _VEX_MM(op >> 8) | (op & 0xFF))

#define _VEX_MM(op)                                                     \
    (                                                                   \
        ((op) & 0x00FF) == 0x000F ? (0x1 << 16 | _VEX_PP((op) >>  8)) : \
        ((op) & 0xFFFF) == 0x0F38 ? (0x2 << 16 | _VEX_PP((op) >> 16)) : \
        ((op) & 0xFFFF) == 0x0F3A ? (0x3 << 16 | _VEX_PP((op) >> 16)) : \
        _VEX_ASSERT0                                                    \
    )

#define _VEX_PP(op)                                     \
    (                                                   \
        (op) == 0x00 ? 0x00 << 8 :                      \
        (op) == 0x66 ? 0x01 << 8 :                      \
        (op) == 0xF3 ? 0x02 << 8 :                      \
        (op) == 0xF2 ? 0x03 << 8 :                      \
        _VEX_ASSERT0                                    \
    )

// avoid dynamic initialization of the asm tables
#if DEBUG
    #define _VEX_ASSERT0 (assert(0))
#else
    #define _VEX_ASSERT0 (0)
#endif


/////////////////////////////////////////////////
// Operand flags - usOp1, usOp2, usOp3
//

typedef unsigned opflag_t;

// Operand flags for normal opcodes

#define _r8     CONSTRUCT_FLAGS( _8, _reg, _normal, 0 )
#define _r16    CONSTRUCT_FLAGS(_16, _reg, _normal, 0 )
#define _r32    CONSTRUCT_FLAGS(_32, _reg, _normal, 0 )
#define _r64    CONSTRUCT_FLAGS(_64, _reg, _normal, 0 )
#define _m8     CONSTRUCT_FLAGS(_8, _m, _normal, 0 )
#define _m16    CONSTRUCT_FLAGS(_16, _m, _normal, 0 )
#define _m32    CONSTRUCT_FLAGS(_32, _m, _normal, 0 )
#define _m48    CONSTRUCT_FLAGS( _48, _m, _normal, 0 )
#define _m64    CONSTRUCT_FLAGS( _64, _m, _normal, 0 )
#define _m128   CONSTRUCT_FLAGS( _anysize, _m, _normal, 0 )
#define _m256   CONSTRUCT_FLAGS( _anysize, _m, _normal, 0 )
#define _rm8    CONSTRUCT_FLAGS(_8, _rm, _normal, 0 )
#define _rm16   CONSTRUCT_FLAGS(_16, _rm, _normal, 0 )
#define _rm32   CONSTRUCT_FLAGS(_32, _rm, _normal, 0)
#define _rm64   CONSTRUCT_FLAGS(_64, _rm, _normal, 0)
#define _r32m8  CONSTRUCT_FLAGS(_32|_8, _rm, _normal, 0)
#define _r32m16 CONSTRUCT_FLAGS(_32|_16, _rm, _normal, 0)
#define _regm8  CONSTRUCT_FLAGS(_64|_32|_8, _rm, _normal, 0)
#define _imm8   CONSTRUCT_FLAGS(_8, _imm, _normal, 0 )
#define _imm16  CONSTRUCT_FLAGS(_16, _imm, _normal, 0)
#define _imm32  CONSTRUCT_FLAGS(_32, _imm, _normal, 0)
#define _imm64  CONSTRUCT_FLAGS(_64, _imm, _normal, 0)
#define _rel8   CONSTRUCT_FLAGS(_8, _rel, _normal, 0)
#define _rel16  CONSTRUCT_FLAGS(_16, _rel, _normal, 0)
#define _rel32  CONSTRUCT_FLAGS(_32, _rel, _normal, 0)
#define _p1616  CONSTRUCT_FLAGS(_32, _p, _normal, 0)
#define _m1616  CONSTRUCT_FLAGS(_32, _mnoi, _normal, 0)
#define _p1632  CONSTRUCT_FLAGS(_48, _p, _normal, 0 )
#define _m1632  CONSTRUCT_FLAGS(_48, _mnoi, _normal, 0)
#define _special  CONSTRUCT_FLAGS( 0, 0, _rspecial, 0 )
#define _seg    CONSTRUCT_FLAGS( 0, 0, _rseg, 0 )
#define _a16    CONSTRUCT_FLAGS( 0, 0, _addr16, 0 )
#define _a32    CONSTRUCT_FLAGS( 0, 0, _addr32, 0 )
#define _f16    CONSTRUCT_FLAGS( 0, 0, _fn16, 0)
                                                // Near function pointer
#define _f32    CONSTRUCT_FLAGS( 0, 0, _fn32, 0)
                                                // Far function pointer
#define _lbl    CONSTRUCT_FLAGS( 0, 0, _flbl, 0 )
                                                // Label (in current function)

#define _mmm32  CONSTRUCT_FLAGS( 0, _m, 0, _32)
#define _mmm64  CONSTRUCT_FLAGS( _64, _m, 0, _f64)
#define _mmm128 CONSTRUCT_FLAGS( 0, _m, 0, _f128)

#define _xmm_m16  CONSTRUCT_FLAGS( _16,      _m, _rspecial, ASM_GET_uRegmask(_xmm))
#define _xmm_m32  CONSTRUCT_FLAGS( _32,      _m, _rspecial, ASM_GET_uRegmask(_xmm))
#define _xmm_m64  CONSTRUCT_FLAGS( _anysize, _m, _rspecial, ASM_GET_uRegmask(_xmm))
#define _xmm_m128 CONSTRUCT_FLAGS( _anysize, _m, _rspecial, ASM_GET_uRegmask(_xmm))
#define _ymm_m256 CONSTRUCT_FLAGS( _anysize, _m, _rspecial, ASM_GET_uRegmask(_ymm))

#define _moffs8 (_rel8)
#define _moffs16 (_rel16 )
#define _moffs32 (_rel32 )


////////////////////////////////////////////////////////////////////
// Operand flags for floating point opcodes are all just aliases for
// normal opcode variants and only asm_determine_operator_flags should
// need to care.
//
#define _fm80   CONSTRUCT_FLAGS( 0, _m, 0, _f80 )
#define _fm64   CONSTRUCT_FLAGS( 0, _m, 0, _f64 )
#define _fm128  CONSTRUCT_FLAGS( 0, _m, 0, _f128 )
#define _fanysize (_f64 | _f80 | _f112 )

#define _float_m CONSTRUCT_FLAGS( _anysize, _float, 0, _fanysize)

#define _st     CONSTRUCT_FLAGS( 0, _float, 0, _rst )   // stack register 0
#define _m112   CONSTRUCT_FLAGS( 0, _m, 0, _f112 )
#define _m224   _m112
#define _m512   _m224
#define _sti    CONSTRUCT_FLAGS( 0, _float, 0, _rsti )

////////////////// FLAGS /////////////////////////////////////

#if 1
// bit size                      5      3     3         7
#define CONSTRUCT_FLAGS( uSizemask, aopty, amod, uRegmask ) \
    ( (uSizemask) | (aopty) << 5 | (amod) << 8 | (uRegmask) << 11)

#define ASM_GET_uSizemask(us)   ((us) & 0x1F)
#define ASM_GET_aopty(us)       ((ASM_OPERAND_TYPE)(((us) >> 5) & 7))
#define ASM_GET_amod(us)        ((ASM_MODIFIERS)(((us) >> 8) & 7))
#define ASM_GET_uRegmask(us)    (((us) >> 11) & 0x7F)
#else
#define CONSTRUCT_FLAGS( uSizemask, aopty, amod, uRegmask ) \
    ( (uSizemask) | (aopty) << 4 | (amod) << 7 | (uRegmask) << 10)

#define ASM_GET_uSizemask(us)   ((us) & 0x0F)
#define ASM_GET_aopty(us)       ((ASM_OPERAND_TYPE)(((us) & 0x70) >> 4))
#define ASM_GET_amod(us)        ((ASM_MODIFIERS)(((us) & 0x380) >> 7))
#define ASM_GET_uRegmask(us)    (((us) & 0xFC00) >> 10)
#endif

// For uSizemask (5 bits)
#define _8  0x1
#define _16 0x2
#define _32 0x4
#define _48 0x8
#define _64 0x10
#define _anysize (_8 | _16 | _32 | _48 | _64 )

// For aopty (3 bits)
enum ASM_OPERAND_TYPE {
    _reg,           // _r8, _r16, _r32
    _m,             // _m8, _m16, _m32, _m48
    _imm,           // _imm8, _imm16, _imm32, _imm64
    _rel,           // _rel8, _rel16, _rel32
    _mnoi,          // _m1616, _m1632
    _p,             // _p1616, _p1632
    _rm,            // _rm8, _rm16, _rm32
    _float          // Floating point operand, look at cRegmask for the
                    // actual size
};

// For amod (3 bits)
enum ASM_MODIFIERS {
    _normal,        // Normal register value
    _rseg,          // Segment registers
    _rspecial,      // Special registers
    _addr16,        // 16 bit address
    _addr32,        // 32 bit address
    _fn16,          // 16 bit function call
    _fn32,          // 32 bit function call
    _flbl           // Label
};

// For uRegmask (7 bits)

// uRegmask flags when aopty == _float
#define _rst    0x1
#define _rsti   0x2
#define _f64    0x4
#define _f80    0x8
#define _f112   0x10
#define _f128   0x20

// _seg register values (amod == _rseg)
//
#define _ds     CONSTRUCT_FLAGS( 0, 0, _rseg, 0x01 )
#define _es     CONSTRUCT_FLAGS( 0, 0, _rseg, 0x02 )
#define _ss     CONSTRUCT_FLAGS( 0, 0, _rseg, 0x04 )
#define _fs     CONSTRUCT_FLAGS( 0, 0, _rseg, 0x08 )
#define _gs     CONSTRUCT_FLAGS( 0, 0, _rseg, 0x10 )
#define _cs     CONSTRUCT_FLAGS( 0, 0, _rseg, 0x20 )

//
// _special register values
//
#define _crn    CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x01 ) // CRn register (0,2,3)
#define _drn    CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x02 ) // DRn register (0-3,6-7)
#define _trn    CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x04 ) // TRn register (3-7)
#define _mm     CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x08 ) // MMn register (0-7)
#define _xmm    CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x10 ) // XMMn register (0-7)
#define _xmm0   CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x20 ) // XMM0 register
#define _ymm    CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x40 ) // YMMn register (0-15)

//
// Default register values
//

#define _al     CONSTRUCT_FLAGS( 0, 0, _normal, 0x01 )  // AL register
#define _ax     CONSTRUCT_FLAGS( 0, 0, _normal, 0x02 )  // AX register
#define _eax    CONSTRUCT_FLAGS( 0, 0, _normal, 0x04 )  // EAX register
#define _dx     CONSTRUCT_FLAGS( 0, 0, _normal, 0x08 )  // DX register
#define _cl     CONSTRUCT_FLAGS( 0, 0, _normal, 0x10 )  // CL register
#define _rax    CONSTRUCT_FLAGS( 0, 0, _normal, 0x40 )  // RAX register


#define _rplus_r        0x20
#define _plus_r CONSTRUCT_FLAGS( 0, 0, 0, _rplus_r )
                // Add the register to the opcode (no mod r/m)



//////////////////////////////////////////////////////////////////

#define ITprefix        0x10    // special prefix
#define ITjump          0x20    // jump instructions CALL, Jxx and LOOPxx
#define ITimmed         0x30    // value of an immediate operand controls
                                // code generation
#define ITopt           0x40    // not all operands are required
#define ITshift         0x50    // rotate and shift instructions
#define ITfloat         0x60    // floating point coprocessor instructions
#define ITdata          0x70    // DB, DW, DD, DQ, DT pseudo-ops
#define ITaddr          0x80    // DA (define addresss) pseudo-op
#define ITMASK          0xF0
#define ITSIZE          0x0F    // mask for size

enum OP_DB
{
#if SCPP
    // These are the number of bytes
    OPdb = 1,
    OPdw = 2,
    OPdd = 4,
    OPdq = 8,
    OPdt = 10,
    OPdf = 4,
    OPde = 10,
    OPds = 2,
    OPdi = 4,
    OPdl = 8,
#endif
#if MARS
    // Integral types
    OPdb,
    OPds,
    OPdi,
    OPdl,

    // Float types
    OPdf,
    OPdd,
    OPde,

    // Deprecated
    OPdw = OPds,
    OPdq = OPdl,
    OPdt = OPde,
#endif
};


/* from iasm.c */
int asm_state(int iFlags);

void asm_process_fixup( block **ppblockLabels );

struct PTRNTAB4 {
        int opcode;
        unsigned usFlags;
        opflag_t usOp1;
        opflag_t usOp2;
        opflag_t usOp3;
        opflag_t usOp4;
};

struct PTRNTAB3 {
        int opcode;
        unsigned usFlags;
        opflag_t usOp1;
        opflag_t usOp2;
        opflag_t usOp3;
};

struct PTRNTAB2 {
        int opcode;
        unsigned usFlags;
        opflag_t usOp1;
        opflag_t usOp2;
};

struct PTRNTAB1 {
        int opcode;
        unsigned usFlags;
        opflag_t usOp1;
};

struct PTRNTAB0 {
        int opcode;
        #define ASM_END 0xffff          // special opcode meaning end of table
        unsigned usFlags;
};

union PTRNTAB {
        void            *ppt;    // avoid type-punning warnings
        PTRNTAB0        *pptb0;
        PTRNTAB1        *pptb1;
        PTRNTAB2        *pptb2;
        PTRNTAB3        *pptb3;
        PTRNTAB4        *pptb4;
};

struct OP
{
        unsigned char usNumops;
        PTRNTAB ptb;
};

