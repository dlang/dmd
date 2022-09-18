/**
 * Declarations for ptrntab.d, the instruction tables for the inline assembler.
 *
 * Copyright:   Copyright (C) 1982-1998 by Symantec
 *              Copyright (C) 2000-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     Mike Cote, John Micco, $(LINK2 https://www.digitalmars.com, Walter Bright),
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/iasm.d, backend/iasm.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_iasm.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/iasm.d
 */

module dmd.backend.iasm;

// Online documentation: https://dlang.org/phobos/dmd_backend_iasm.html

import dmd.backend.cc : block;
import dmd.backend.code_x86 : opcode_t;

extern (C++):
@nogc:
nothrow:

//#include <setjmp.h>

/////////////////////////////////////////////////
// Instruction flags (usFlags)
//
//

enum _modrm = 0x10;

// This is for when the reg field of modregrm specifies which instruction it is
enum
{
    NUM_MASK  = 0x7,
    NUM_MASKR = 0x8,             // for REX extended registers
    _0      = (0x0 | _modrm),    // insure that some _modrm bit is set
    _1      = 0x1,               // with _0
    _2      = 0x2,
    _3      = 0x3,
    _4      = 0x4,
    _5      = 0x5,
    _6      = 0x6,
    _7      = 0x7,
}

enum
{
    _r           = _modrm,
    _cb          = _modrm,
    _cw          = _modrm,
    _cd          = _modrm,
    _cq          = _modrm,
    _cp          = _modrm,
    _ib          = 0,
    _iw          = 0,
    _id          = 0,
    _rb          = 0,
    _rw          = 0,
    _rd          = 0,
    _16_bit      = 0x20,
    _32_bit      = 0x40,
    _64_bit      = 0x10000,
    _i64_bit     = 0x20000,  // opcode is invalid in 64bit mode
    _I386        = 0x80,     // opcode is only for 386 and later
    _16_bit_addr = 0x100,
    _32_bit_addr = 0x200,
    _fwait       = 0x400,    // Add an FWAIT prior to the instruction opcode
    _nfwait      = 0x800,    // Do not add an FWAIT prior to the instruction
}

enum
{
    MOD_MASK        = 0xF000,  // Mod mask
    _modsi          = 0x1000,  // Instruction modifies SI
    _moddx          = 0x2000,  // Instruction modifies DX
    _mod2           = 0x3000,  // Instruction modifies second operand
    _modax          = 0x4000,  // Instruction modifies AX
    _modnot1        = 0x5000,  // Instruction does not modify first operand
    _modaxdx        = 0x6000,  // instruction modifies AX and DX
    _moddi          = 0x7000,  // Instruction modifies DI
    _modsidi        = 0x8000,  // Instruction modifies SI and DI
    _modcx          = 0x9000,  // Instruction modifies CX
    _modes          = 0xa000,  // Instruction modifies ES
    _modall         = 0xb000,  // Instruction modifies all register values
    _modsiax        = 0xc000,  // Instruction modifies AX and SI
    _modsinot1      = 0xd000,  // Instruction modifies SI and not first param
    _modcxr11       = 0xe000,  // Instruction modifies CX and R11
    _modxmm0        = 0xf000,  // Instruction modifies XMM0
}

// translates opcode into equivalent vex encoding
uint VEX_128_W0(opcode_t op)            { return _VEX(op)|_VEX_NOO; }
uint VEX_128_W1(opcode_t op)            { return _VEX(op)|_VEX_NOO|_VEX_W; }
uint VEX_128_WIG(opcode_t op)           { return  VEX_128_W0(op); }
uint VEX_256_W0(opcode_t op)            { return _VEX(op)|_VEX_NOO|_VEX_L; }
uint VEX_256_W1(opcode_t op)            { return _VEX(op)|_VEX_NOO|_VEX_W|_VEX_L; }
uint VEX_256_WIG(opcode_t op)           { return  VEX_256_W0(op); }
uint VEX_NDS_128_W0(opcode_t op)        { return _VEX(op)|_VEX_NDS; }
uint VEX_NDS_128_W1(opcode_t op)        { return _VEX(op)|_VEX_NDS|_VEX_W; }
uint VEX_NDS_128_WIG(opcode_t op)       { return  VEX_NDS_128_W0(op); }
uint VEX_NDS_256_W0(opcode_t op)        { return _VEX(op)|_VEX_NDS|_VEX_L; }
uint VEX_NDS_256_W1(opcode_t op)        { return _VEX(op)|_VEX_NDS|_VEX_W|_VEX_L; }
uint VEX_NDS_256_WIG(opcode_t op)       { return  VEX_NDS_256_W0(op); }
uint VEX_NDD_128_W0(opcode_t op)        { return _VEX(op)|_VEX_NDD; }
uint VEX_NDD_128_W1(opcode_t op)        { return _VEX(op)|_VEX_NDD|_VEX_W; }
uint VEX_NDD_128_WIG(opcode_t op)       { return  VEX_NDD_128_W0(op); }
uint VEX_NDD_256_W0(opcode_t op)        { return _VEX(op)|_VEX_NDD|_VEX_L; }
uint VEX_NDD_256_W1(opcode_t op)        { return _VEX(op)|_VEX_NDD|_VEX_W|_VEX_L; }
uint VEX_NDD_256_WIG(opcode_t op)       { return  VEX_NDD_256_W0(op); }
uint VEX_DDS_128_W0(opcode_t op)        { return _VEX(op)|_VEX_DDS; }
uint VEX_DDS_128_W1(opcode_t op)        { return _VEX(op)|_VEX_DDS|_VEX_W; }
uint VEX_DDS_128_WIG(opcode_t op)       { return  VEX_DDS_128_W0(op); }
uint VEX_DDS_256_W0(opcode_t op)        { return _VEX(op)|_VEX_DDS|_VEX_L; }
uint VEX_DDS_256_W1(opcode_t op)        { return _VEX(op)|_VEX_DDS|_VEX_W|_VEX_L; }
uint VEX_DDS_256_WIG(opcode_t op)       { return  VEX_DDS_256_W0(op); }

enum _VEX_W   = 0x8000;
/* Don't encode LIG/LZ use 128 for these.
 */
enum _VEX_L   = 0x0400;
/* Encode nds, ndd, dds in the vvvv field, it gets
 * overwritten with the actual register later.
 */
enum
{
     VEX_NOO = 0, // neither of nds, ndd, dds
     VEX_NDS = 1,
     VEX_NDD = 2,
     VEX_DDS = 3,
    _VEX_NOO  = VEX_NOO << 11,
    _VEX_NDS  = VEX_NDS << 11,
    _VEX_NDD  = VEX_NDD << 11,
    _VEX_DDS  = VEX_DDS << 11,
}

uint _VEX(opcode_t op) { return (0xC4 << 24) | _VEX_MM(op >> 8) | (op & 0xFF); }

uint _VEX_MM(opcode_t op)
{
    return
        (op & 0x00FF) == 0x000F ? (0x1 << 16 | _VEX_PP(op >>  8)) :
        (op & 0xFFFF) == 0x0F38 ? (0x2 << 16 | _VEX_PP(op >> 16)) :
        (op & 0xFFFF) == 0x0F3A ? (0x3 << 16 | _VEX_PP(op >> 16)) :
        _VEX_ASSERT0;
}

uint _VEX_PP(opcode_t op)
{
    return
        op == 0x00 ? 0x00 << 8 :
        op == 0x66 ? 0x01 << 8 :
        op == 0xF3 ? 0x02 << 8 :
        op == 0xF2 ? 0x03 << 8 :
        _VEX_ASSERT0;
}

// avoid dynamic initialization of the asm tables
debug
{
    @property uint _VEX_ASSERT0() { assert(0); }
}
else
{
    @property uint _VEX_ASSERT0() { return 0; }
}


/////////////////////////////////////////////////
// Operand flags - usOp1, usOp2, usOp3
//

alias opflag_t = uint;

// Operand flags for normal opcodes
enum
{
    _r8     = CONSTRUCT_FLAGS(OpndSize._8, _reg, _normal, 0 ),
    _r16    = CONSTRUCT_FLAGS(OpndSize._16, _reg, _normal, 0 ),
    _r32    = CONSTRUCT_FLAGS(OpndSize._32, _reg, _normal, 0 ),
    _r64    = CONSTRUCT_FLAGS(OpndSize._64, _reg, _normal, 0 ),
    _m8     = CONSTRUCT_FLAGS(OpndSize._8, _m, _normal, 0 ),
    _m16    = CONSTRUCT_FLAGS(OpndSize._16, _m, _normal, 0 ),
    _m32    = CONSTRUCT_FLAGS(OpndSize._32, _m, _normal, 0 ),
    _m48    = CONSTRUCT_FLAGS(OpndSize._48, _m, _normal, 0 ),
    _m64    = CONSTRUCT_FLAGS(OpndSize._64, _m, _normal, 0 ),
    _m128   = CONSTRUCT_FLAGS(OpndSize._128, _m, _normal, 0 ),
    _m256   = CONSTRUCT_FLAGS(OpndSize._anysize, _m, _normal, 0 ),
    _m48_32_16_8    = CONSTRUCT_FLAGS(OpndSize._48_32_16_8, _m, _normal, 0 ),
    _m64_48_32_16_8 = CONSTRUCT_FLAGS(OpndSize._64_48_32_16_8, _m, _normal, 0 ),
    _rm8    = CONSTRUCT_FLAGS(OpndSize._8, _rm, _normal, 0 ),
    _rm16   = CONSTRUCT_FLAGS(OpndSize._16, _rm, _normal, 0 ),
    _rm32   = CONSTRUCT_FLAGS(OpndSize._32, _rm, _normal, 0),
    _rm64   = CONSTRUCT_FLAGS(OpndSize._64, _rm, _normal, 0),
    _r32m8  = CONSTRUCT_FLAGS(OpndSize._32_8, _rm, _normal, 0),
    _r32m16 = CONSTRUCT_FLAGS(OpndSize._32_16, _rm, _normal, 0),
    _regm8  = CONSTRUCT_FLAGS(OpndSize._64_32_8, _rm, _normal, 0),
    _imm8   = CONSTRUCT_FLAGS(OpndSize._8, _imm, _normal, 0 ),
    _imm16  = CONSTRUCT_FLAGS(OpndSize._16, _imm, _normal, 0),
    _imm32  = CONSTRUCT_FLAGS(OpndSize._32, _imm, _normal, 0),
    _imm64  = CONSTRUCT_FLAGS(OpndSize._64, _imm, _normal, 0),
    _rel8   = CONSTRUCT_FLAGS(OpndSize._8, _rel, _normal, 0),
    _rel16  = CONSTRUCT_FLAGS(OpndSize._16, _rel, _normal, 0),
    _rel32  = CONSTRUCT_FLAGS(OpndSize._32, _rel, _normal, 0),
    _p1616  = CONSTRUCT_FLAGS(OpndSize._32, _p, _normal, 0),
    _m1616  = CONSTRUCT_FLAGS(OpndSize._32, _mnoi, _normal, 0),
    _p1632  = CONSTRUCT_FLAGS(OpndSize._48, _p, _normal, 0 ),
    _m1632  = CONSTRUCT_FLAGS(OpndSize._48, _mnoi, _normal, 0),
    _special  = CONSTRUCT_FLAGS( 0, 0, _rspecial, 0 ),
    _seg    = CONSTRUCT_FLAGS( 0, 0, _rseg, 0 ),
    _a16    = CONSTRUCT_FLAGS( 0, 0, _addr16, 0 ),
    _a32    = CONSTRUCT_FLAGS( 0, 0, _addr32, 0 ),
    _f16    = CONSTRUCT_FLAGS( 0, 0, _fn16, 0),
                                                // Near function pointer
    _f32    = CONSTRUCT_FLAGS( 0, 0, _fn32, 0),
                                                // Far function pointer
    _lbl    = CONSTRUCT_FLAGS( 0, 0, _flbl, 0 ),
                                                // Label (in current function)

    _mmm32  = CONSTRUCT_FLAGS( 0, _m, 0, OpndSize._32),
    _mmm64  = CONSTRUCT_FLAGS( OpndSize._64, _m, 0, _f64),
    _mmm128 = CONSTRUCT_FLAGS( 0, _m, 0, _f128),

    _xmm_m16  = CONSTRUCT_FLAGS( OpndSize._16,      _m, _rspecial, ASM_GET_uRegmask(_xmm)),
    _xmm_m32  = CONSTRUCT_FLAGS( OpndSize._32,      _m, _rspecial, ASM_GET_uRegmask(_xmm)),
    _xmm_m64  = CONSTRUCT_FLAGS( OpndSize._anysize, _m, _rspecial, ASM_GET_uRegmask(_xmm)),
    _xmm_m128 = CONSTRUCT_FLAGS( OpndSize._128,     _m, _rspecial, ASM_GET_uRegmask(_xmm)),
    _ymm_m256 = CONSTRUCT_FLAGS( OpndSize._anysize, _m, _rspecial, ASM_GET_uRegmask(_ymm)),

    _moffs8  = _rel8,
    _moffs16 = _rel16,
    _moffs32 = _rel32,
}

////////////////////////////////////////////////////////////////////
// Operand flags for floating point opcodes are all just aliases for
// normal opcode variants and only asm_determine_operator_flags should
// need to care.

enum
{
    _fm80   = CONSTRUCT_FLAGS( 0, _m, 0, _f80 ),
    _fm64   = CONSTRUCT_FLAGS( 0, _m, 0, _f64 ),
    _fm128  = CONSTRUCT_FLAGS( 0, _m, 0, _f128 ),
    _fanysize = (_f64 | _f80 | _f112 ),

    _float_m = CONSTRUCT_FLAGS( OpndSize._anysize, _float, 0, _fanysize),

    _st     = CONSTRUCT_FLAGS( 0, _float, 0, _rst ),   // stack register 0
    _m112   = CONSTRUCT_FLAGS( 0, _m, 0, _f112 ),
    _m224   = _m112,
    _m512   = _m224,
    _sti    = CONSTRUCT_FLAGS( 0, _float, 0, _rsti ),
}

////////////////// FLAGS /////////////////////////////////////

// bit size                      5            3          3              7
opflag_t CONSTRUCT_FLAGS(uint uSizemask, uint aopty, uint amod, uint uRegmask)
{
    return uSizemask | (aopty << 5) | (amod << 8) | (uRegmask << 11);
}

uint ASM_GET_aopty(uint us)     { return cast(ASM_OPERAND_TYPE)((us >> 5) & 7); }
uint ASM_GET_amod(uint us)      { return cast(ASM_MODIFIERS)((us >> 8) & 7); }
uint ASM_GET_uRegmask(uint us)  { return (us >> 11) & 0x7F; }

// For uSizemask (5 bits)
enum OpndSize : ubyte
{
    none = 0,

    _8,  // 0x1,
    _16, // 0x2,
    _32, // 0x4,
    _48, // 0x8,
    _64, // 0x10,
    _128, // 0x20,

    _16_8,       // _16 | _8,
    _32_8,       // _32 | _8,
    _32_16,      // _32 | _16,
    _32_16_8,    // _32 | _16 | _8,
    _48_32,      // _48 | _32,
    _48_32_16_8, // _48 | _32 | _16 | _8,
    _64_32,      // _64 | _32,
    _64_32_8,    // _64 | _32 | _8,
    _64_32_16,   // _64 | _32 | _16,
    _64_32_16_8, // _64 | _32 | _16 | _8,
    _64_48_32_16_8, // _64 | _48 | _32 | _16 | _8,

    _anysize,
}

/*************************************
 * Extract OpndSize from opflag_t.
 */
OpndSize getOpndSize(opflag_t us) { return cast(OpndSize) (us & 0x1F); }

// For aopty (3 bits)
alias ASM_OPERAND_TYPE = uint;
enum
{
    _reg,           // _r8, _r16, _r32
    _m,             // _m8, _m16, _m32, _m48
    _imm,           // _imm8, _imm16, _imm32, _imm64
    _rel,           // _rel8, _rel16, _rel32
    _mnoi,          // _m1616, _m1632
    _p,             // _p1616, _p1632
    _rm,            // _rm8, _rm16, _rm32
    _float          // Floating point operand, look at cRegmask for the
                    // actual size
}

// For amod (3 bits)
alias ASM_MODIFIERS = uint;
enum
{
    _normal,        // Normal register value
    _rseg,          // Segment registers
    _rspecial,      // Special registers
    _addr16,        // 16 bit address
    _addr32,        // 32 bit address
    _fn16,          // 16 bit function call
    _fn32,          // 32 bit function call
    _flbl           // Label
}

// For uRegmask (7 bits)

// uRegmask flags when aopty == _float
enum
{
    _rst    = 0x1,
    _rsti   = 0x2,
    _f64    = 0x4,
    _f80    = 0x8,
    _f112   = 0x10,
    _f128   = 0x20,
}

// _seg register values (amod == _rseg)
//
enum
{
    _ds     = CONSTRUCT_FLAGS( 0, 0, _rseg, 0x01 ),
    _es     = CONSTRUCT_FLAGS( 0, 0, _rseg, 0x02 ),
    _ss     = CONSTRUCT_FLAGS( 0, 0, _rseg, 0x04 ),
    _fs     = CONSTRUCT_FLAGS( 0, 0, _rseg, 0x08 ),
    _gs     = CONSTRUCT_FLAGS( 0, 0, _rseg, 0x10 ),
    _cs     = CONSTRUCT_FLAGS( 0, 0, _rseg, 0x20 ),
}

//
// _special register values
//
enum
{
    _crn    = CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x01 ), // CRn register (0,2,3)
    _drn    = CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x02 ), // DRn register (0-3,6-7)
    _trn    = CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x04 ), // TRn register (3-7)
    _mm     = CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x08 ), // MMn register (0-7)
    _xmm    = CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x10 ), // XMMn register (0-7)
    _xmm0   = CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x20 ), // XMM0 register
    _ymm    = CONSTRUCT_FLAGS( 0, 0, _rspecial, 0x40 ), // YMMn register (0-15)
}

//
// Default register values
//
enum
{
    _al     = CONSTRUCT_FLAGS( 0, 0, _normal, 0x01 ),  // AL register
    _ax     = CONSTRUCT_FLAGS( 0, 0, _normal, 0x02 ),  // AX register
    _eax    = CONSTRUCT_FLAGS( 0, 0, _normal, 0x04 ),  // EAX register
    _dx     = CONSTRUCT_FLAGS( 0, 0, _normal, 0x08 ),  // DX register
    _cl     = CONSTRUCT_FLAGS( 0, 0, _normal, 0x10 ),  // CL register
    _rax    = CONSTRUCT_FLAGS( 0, 0, _normal, 0x40 ),  // RAX register
}


enum _rplus_r        = 0x20;
enum _plus_r = CONSTRUCT_FLAGS( 0, 0, 0, _rplus_r );
                // Add the register to the opcode (no mod r/m)



//////////////////////////////////////////////////////////////////

enum
{
    ITprefix        = 0x10,    // special prefix
    ITjump          = 0x20,    // jump instructions CALL, Jxx and LOOPxx
    ITimmed         = 0x30,    // value of an immediate operand controls
                               // code generation
    ITopt           = 0x40,    // not all operands are required
    ITshift         = 0x50,    // rotate and shift instructions
    ITfloat         = 0x60,    // floating point coprocessor instructions
    ITdata          = 0x70,    // DB, DW, DD, DQ, DT pseudo-ops
    ITaddr          = 0x80,    // DA (define addresss) pseudo-op
    ITMASK          = 0xF0,
    ITSIZE          = 0x0F,    // mask for size
}

version (SCPP)
{
    alias OP_DB = int;
    enum
    {
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
    }
}
version (MARS)
{
    alias OP_DB = int;
    enum
    {
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
    }
}


/* from iasm.c */
int asm_state(int iFlags);

void asm_process_fixup( block **ppblockLabels );

struct PTRNTAB4
{
        opcode_t opcode;
        uint usFlags;
        opflag_t usOp1;
        opflag_t usOp2;
        opflag_t usOp3;
        opflag_t usOp4;
}

struct PTRNTAB3 {
        opcode_t opcode;
        uint usFlags;
        opflag_t usOp1;
        opflag_t usOp2;
        opflag_t usOp3;
}

struct PTRNTAB2 {
        opcode_t opcode;
        uint usFlags;
        opflag_t usOp1;
        opflag_t usOp2;
}

struct PTRNTAB1 {
        opcode_t opcode;
        uint usFlags;
        opflag_t usOp1;
}

enum ASM_END = 0xffff;      // special opcode meaning end of PTRNTABx table

struct PTRNTAB0 {
        opcode_t opcode;
        uint usFlags;
}

union PTRNTAB {
        void            *ppt;
        PTRNTAB0        *pptb0;
        PTRNTAB1        *pptb1;
        PTRNTAB2        *pptb2;
        PTRNTAB3        *pptb3;
        PTRNTAB4        *pptb4;
}

struct OP
{
    string str;   // opcode string
    ubyte usNumops;
    PTRNTAB ptb;
}
