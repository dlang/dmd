/**
 * Inline assembler implementation for DMD.
 * https://dlang.org/spec/iasm.html
 *
 * Copyright:   Copyright (c) 1992-1999 by Symantec
 *              Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     Mike Cote, John Micco and $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/iasmdmd.d, _iasmdmd.d)
 * Documentation:  https://dlang.org/phobos/dmd_iasmdmd.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/iasmdmd.d
 */

module dmd.iasmdmd;

import core.stdc.stdio;
import core.stdc.stdarg;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.astenums;
import dmd.declaration;
import dmd.denum;
import dmd.dscope;
import dmd.dsymbol;
import dmd.errors;
import dmd.expression;
import dmd.expressionsem;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.mtype;
import dmd.optimize;
import dmd.statement;
import dmd.target;
import dmd.tokens;

import dmd.root.ctfloat;
import dmd.root.outbuffer;
import dmd.root.rmem;
import dmd.root.rootobject;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.codebuilder : CodeBuilder;
import dmd.backend.global;
import dmd.backend.iasm;
import dmd.backend.ptrntab : asm_opstr, asm_op_lookup, init_optab;
import dmd.backend.xmm;

//debug = EXTRA_DEBUG;
//debug = debuga;

/*******************************
 * Clean up iasm things before exiting the compiler.
 * Currently not called.
 */

version (none)
public void iasm_term()
{
    if (asmstate.bInit)
    {
        asmstate.psDollar = null;
        asmstate.psLocalsize = null;
        asmstate.bInit = false;
    }
}

/************************
 * Perform semantic analysis on InlineAsmStatement.
 * Params:
 *      s = inline asm statement
 *      sc = context
 * Returns:
 *      `s` on success, ErrorStatement if errors happened
 */
public Statement inlineAsmSemantic(InlineAsmStatement s, Scope *sc)
{
    //printf("InlineAsmStatement.semantic()\n");

    OP *o;
    OPND[4] opnds;
    int nOps;
    PTRNTAB ptb;
    int usNumops;

    asmstate.ucItype = 0;
    asmstate.bReturnax = false;
    asmstate.lbracketNestCount = 0;
    asmstate.errors = false;

    asmstate.statement = s;
    asmstate.sc = sc;

version (none) // don't use bReturnax anymore, and will fail anyway if we use return type inference
{
    // Scalar return values will always be in AX.  So if it is a scalar
    // then asm block sets return value if it modifies AX, if it is non-scalar
    // then always assume that the ASM block sets up an appropriate return
    // value.

    asmstate.bReturnax = true;
    if (sc.func.type.nextOf().isscalar())
        asmstate.bReturnax = false;
}

    if (!asmstate.bInit)
    {
        asmstate.bInit = true;
        init_optab();
        asmstate.psDollar = LabelDsymbol.create(Id._dollar);
        asmstate.psLocalsize = Dsymbol.create(Id.__LOCAL_SIZE);
    }

    asmstate.loc = s.loc;

    asmstate.tok = s.tokens;
    asm_token_trans(asmstate.tok);

    switch (asmstate.tokValue)
    {
        case cast(TOK)ASMTKnaked:
            s.naked = true;
            sc.func.naked = true;
            asm_token();
            break;

        case cast(TOK)ASMTKeven:
            asm_token();
            s.asmalign = 2;
            break;

        case TOK.align_:
        {
            asm_token();
            uint _align = asm_getnum();
            if (ispow2(_align) == -1)
            {
                asmerr("`align %d` must be a power of 2", _align);
                goto AFTER_EMIT;
            }
            else
                s.asmalign = _align;
            break;
        }

        // The following three convert the keywords 'int', 'in', 'out'
        // to identifiers, since they are x86 instructions.
        case TOK.int32:
            o = asm_op_lookup(Id.__int.toChars());
            goto Lopcode;

        case TOK.in_:
            o = asm_op_lookup(Id.___in.toChars());
            goto Lopcode;

        case TOK.out_:
            o = asm_op_lookup(Id.___out.toChars());
            goto Lopcode;

        case TOK.identifier:
            o = asm_op_lookup(asmstate.tok.ident.toChars());
            if (!o)
                goto OPCODE_EXPECTED;

        Lopcode:
            asmstate.ucItype = o.usNumops & ITMASK;
            asm_token();
            if (o.usNumops > 4)
            {
                switch (asmstate.ucItype)
                {
                    case ITdata:
                        s.asmcode = asm_db_parse(o);
                        goto AFTER_EMIT;

                    case ITaddr:
                        s.asmcode = asm_da_parse(o);
                        goto AFTER_EMIT;

                    default:
                        break;
                }
            }
            // get the first part of an expr
            if (asmstate.tokValue != TOK.endOfFile)
            {
                foreach (i; 0 .. 4)
                {
                    asm_cond_exp(opnds[i]);
                    if (asmstate.errors)
                        goto AFTER_EMIT;
                    nOps = i + 1;
                    if (asmstate.tokValue != TOK.comma)
                        break;
                    asm_token();
                }
            }

            // match opcode and operands in ptrntab to verify legal inst and
            // generate

            ptb = asm_classify(o, opnds[0 .. nOps], usNumops);
            if (asmstate.errors)
                goto AFTER_EMIT;

            assert(ptb.pptb0);

            //
            // The Multiply instruction takes 3 operands, but if only 2 are seen
            // then the third should be the second and the second should
            // be a duplicate of the first.
            //

            if (asmstate.ucItype == ITopt &&
                    nOps == 2 && usNumops == 2 &&
                    (ASM_GET_aopty(opnds[1].usFlags) == _imm) &&
                    ((o.usNumops & ITSIZE) == 3))
            {
                nOps = 3;
                opnds[2] = opnds[1];
                opnds[1] = opnds[0];

                // Re-classify the opcode because the first classification
                // assumed 2 operands.

                ptb = asm_classify(o, opnds[0 .. nOps], usNumops);
            }
            else
            {
version (none)
{
                if (asmstate.ucItype == ITshift && (ptb.pptb2.usOp2 == 0 ||
                        (ptb.pptb2.usOp2 & _cl)))
                {
                    o2 = null;
                    usNumops = 1;
                }
}
            }
            s.asmcode = asm_emit(s.loc, usNumops, ptb, o, opnds[0 .. nOps]);
            break;

        default:
        OPCODE_EXPECTED:
            asmerr("opcode expected, not `%s`", asmstate.tok.toChars());
            break;
    }

AFTER_EMIT:

    if (asmstate.tokValue != TOK.endOfFile)
    {
        asmerr("end of instruction expected, not `%s`", asmstate.tok.toChars());  // end of line expected
    }
    return asmstate.errors ? new ErrorStatement() : s;
}

/**********************************
 * Called from back end.
 * Params: bp = asm block
 * Returns: mask of registers used by block bp.
 */
extern (C++) public regm_t iasm_regs(block *bp)
{
    debug (debuga)
        printf("Block iasm regs = 0x%X\n", bp.usIasmregs);

    refparam |= bp.bIasmrefparam;
    return bp.usIasmregs;
}



private:

enum ADDFWAIT = false;


// Additional tokens for the inline assembler
alias ASMTK = int;
enum
{
    ASMTKlocalsize = TOK.max + 1,
    ASMTKdword,
    ASMTKeven,
    ASMTKfar,
    ASMTKnaked,
    ASMTKnear,
    ASMTKptr,
    ASMTKqword,
    ASMTKseg,
    ASMTKword,
    ASMTKmax = ASMTKword - ASMTKlocalsize + 1
}

immutable char*[ASMTKmax] apszAsmtk =
[
    "__LOCAL_SIZE",
    "dword",
    "even",
    "far",
    "naked",
    "near",
    "ptr",
    "qword",
    "seg",
    "word",
];

alias ucItype_t = ubyte;
enum
{
    ITprefix        = 0x10,    /// special prefix
    ITjump          = 0x20,    /// jump instructions CALL, Jxx and LOOPxx
    ITimmed         = 0x30,    /// value of an immediate operand controls
                               /// code generation
    ITopt           = 0x40,    /// not all operands are required
    ITshift         = 0x50,    /// rotate and shift instructions
    ITfloat         = 0x60,    /// floating point coprocessor instructions
    ITdata          = 0x70,    /// DB, DW, DD, DQ, DT pseudo-ops
    ITaddr          = 0x80,    /// DA (define addresss) pseudo-op
    ITMASK          = 0xF0,
    ITSIZE          = 0x0F,    /// mask for size
}

struct ASM_STATE
{
    ucItype_t ucItype;  /// Instruction type
    Loc loc;
    bool bInit;
    bool errors;        /// true if semantic errors occurred
    LabelDsymbol psDollar;
    Dsymbol psLocalsize;
    bool bReturnax;
    InlineAsmStatement statement;
    Scope* sc;
    Token* tok;
    TOK tokValue;
    int lbracketNestCount;
}

__gshared ASM_STATE asmstate;


/**
 * Describes a register
 *
 * This struct is only used for manifest constant
 */
struct REG
{
immutable:
    string regstr;
    ubyte val;
    opflag_t ty;

    bool isSIL_DIL_BPL_SPL() const
    {
        // Be careful as these have the same val's as AH CH DH BH
        return ty == _r8 &&
            ((val == _SIL && regstr == "SIL") ||
             (val == _DIL && regstr == "DIL") ||
             (val == _BPL && regstr == "BPL") ||
             (val == _SPL && regstr == "SPL"));
    }
}

immutable REG regFp =      { "ST", 0, _st };

immutable REG[8] aregFp =
[
    { "ST(0)", 0, _sti },
    { "ST(1)", 1, _sti },
    { "ST(2)", 2, _sti },
    { "ST(3)", 3, _sti },
    { "ST(4)", 4, _sti },
    { "ST(5)", 5, _sti },
    { "ST(6)", 6, _sti },
    { "ST(7)", 7, _sti }
];


enum // the x86 CPU numbers for these registers
{
    _AL           = 0,
    _AH           = 4,
    _AX           = 0,
    _EAX          = 0,
    _BL           = 3,
    _BH           = 7,
    _BX           = 3,
    _EBX          = 3,
    _CL           = 1,
    _CH           = 5,
    _CX           = 1,
    _ECX          = 1,
    _DL           = 2,
    _DH           = 6,
    _DX           = 2,
    _EDX          = 2,
    _BP           = 5,
    _EBP          = 5,
    _SP           = 4,
    _ESP          = 4,
    _DI           = 7,
    _EDI          = 7,
    _SI           = 6,
    _ESI          = 6,
    _ES           = 0,
    _CS           = 1,
    _SS           = 2,
    _DS           = 3,
    _GS           = 5,
    _FS           = 4,
}

immutable REG[71] regtab =
[
    {"AL",   _AL,    _r8 | _al},
    {"AH",   _AH,    _r8},
    {"AX",   _AX,    _r16 | _ax},
    {"EAX",  _EAX,   _r32 | _eax},
    {"BL",   _BL,    _r8},
    {"BH",   _BH,    _r8},
    {"BX",   _BX,    _r16},
    {"EBX",  _EBX,   _r32},
    {"CL",   _CL,    _r8 | _cl},
    {"CH",   _CH,    _r8},
    {"CX",   _CX,    _r16},
    {"ECX",  _ECX,   _r32},
    {"DL",   _DL,    _r8},
    {"DH",   _DH,    _r8},
    {"DX",   _DX,    _r16 | _dx},
    {"EDX",  _EDX,   _r32},
    {"BP",   _BP,    _r16},
    {"EBP",  _EBP,   _r32},
    {"SP",   _SP,    _r16},
    {"ESP",  _ESP,   _r32},
    {"DI",   _DI,    _r16},
    {"EDI",  _EDI,   _r32},
    {"SI",   _SI,    _r16},
    {"ESI",  _ESI,   _r32},
    {"ES",   _ES,    _seg | _es},
    {"CS",   _CS,    _seg | _cs},
    {"SS",   _SS,    _seg | _ss },
    {"DS",   _DS,    _seg | _ds},
    {"GS",   _GS,    _seg | _gs},
    {"FS",   _FS,    _seg | _fs},
    {"CR0",  0,      _special | _crn},
    {"CR2",  2,      _special | _crn},
    {"CR3",  3,      _special | _crn},
    {"CR4",  4,      _special | _crn},
    {"DR0",  0,      _special | _drn},
    {"DR1",  1,      _special | _drn},
    {"DR2",  2,      _special | _drn},
    {"DR3",  3,      _special | _drn},
    {"DR4",  4,      _special | _drn},
    {"DR5",  5,      _special | _drn},
    {"DR6",  6,      _special | _drn},
    {"DR7",  7,      _special | _drn},
    {"TR3",  3,      _special | _trn},
    {"TR4",  4,      _special | _trn},
    {"TR5",  5,      _special | _trn},
    {"TR6",  6,      _special | _trn},
    {"TR7",  7,      _special | _trn},
    {"MM0",  0,      _mm},
    {"MM1",  1,      _mm},
    {"MM2",  2,      _mm},
    {"MM3",  3,      _mm},
    {"MM4",  4,      _mm},
    {"MM5",  5,      _mm},
    {"MM6",  6,      _mm},
    {"MM7",  7,      _mm},
    {"XMM0", 0,      _xmm | _xmm0},
    {"XMM1", 1,      _xmm},
    {"XMM2", 2,      _xmm},
    {"XMM3", 3,      _xmm},
    {"XMM4", 4,      _xmm},
    {"XMM5", 5,      _xmm},
    {"XMM6", 6,      _xmm},
    {"XMM7", 7,      _xmm},
    {"YMM0",   0,    _ymm},
    {"YMM1",   1,    _ymm},
    {"YMM2",   2,    _ymm},
    {"YMM3",   3,    _ymm},
    {"YMM4",   4,    _ymm},
    {"YMM5",   5,    _ymm},
    {"YMM6",   6,    _ymm},
    {"YMM7",   7,    _ymm},
];


enum // 64 bit only registers
{
    _RAX  = 0,
    _RBX  = 3,
    _RCX  = 1,
    _RDX  = 2,
    _RSI  = 6,
    _RDI  = 7,
    _RBP  = 5,
    _RSP  = 4,
    _R8   = 8,
    _R9   = 9,
    _R10  = 10,
    _R11  = 11,
    _R12  = 12,
    _R13  = 13,
    _R14  = 14,
    _R15  = 15,

    _R8D  = 8,
    _R9D  = 9,
    _R10D = 10,
    _R11D = 11,
    _R12D = 12,
    _R13D = 13,
    _R14D = 14,
    _R15D = 15,

    _R8W  = 8,
    _R9W  = 9,
    _R10W = 10,
    _R11W = 11,
    _R12W = 12,
    _R13W = 13,
    _R14W = 13,
    _R15W = 15,

    _SIL  = 6,
    _DIL  = 7,
    _BPL  = 5,
    _SPL  = 4,
    _R8B  = 8,
    _R9B  = 9,
    _R10B = 10,
    _R11B = 11,
    _R12B = 12,
    _R13B = 13,
    _R14B = 14,
    _R15B = 15,

    _RIP = 0xFF,   // some unique value
}

immutable REG[65] regtab64 =
[
    {"RAX",  _RAX,   _r64 | _rax},
    {"RBX",  _RBX,   _r64},
    {"RCX",  _RCX,   _r64},
    {"RDX",  _RDX,   _r64},
    {"RSI",  _RSI,   _r64},
    {"RDI",  _RDI,   _r64},
    {"RBP",  _RBP,   _r64},
    {"RSP",  _RSP,   _r64},
    {"R8",   _R8,    _r64},
    {"R9",   _R9,    _r64},
    {"R10",  _R10,   _r64},
    {"R11",  _R11,   _r64},
    {"R12",  _R12,   _r64},
    {"R13",  _R13,   _r64},
    {"R14",  _R14,   _r64},
    {"R15",  _R15,   _r64},

    {"R8D",  _R8D,   _r32},
    {"R9D",  _R9D,   _r32},
    {"R10D", _R10D,  _r32},
    {"R11D", _R11D,  _r32},
    {"R12D", _R12D,  _r32},
    {"R13D", _R13D,  _r32},
    {"R14D", _R14D,  _r32},
    {"R15D", _R15D,  _r32},

    {"R8W",  _R8W,   _r16},
    {"R9W",  _R9W,   _r16},
    {"R10W", _R10W,  _r16},
    {"R11W", _R11W,  _r16},
    {"R12W", _R12W,  _r16},
    {"R13W", _R13W,  _r16},
    {"R14W", _R14W,  _r16},
    {"R15W", _R15W,  _r16},

    {"SIL",  _SIL,   _r8},
    {"DIL",  _DIL,   _r8},
    {"BPL",  _BPL,   _r8},
    {"SPL",  _SPL,   _r8},
    {"R8B",  _R8B,   _r8},
    {"R9B",  _R9B,   _r8},
    {"R10B", _R10B,  _r8},
    {"R11B", _R11B,  _r8},
    {"R12B", _R12B,  _r8},
    {"R13B", _R13B,  _r8},
    {"R14B", _R14B,  _r8},
    {"R15B", _R15B,  _r8},

    {"XMM8",   8,    _xmm},
    {"XMM9",   9,    _xmm},
    {"XMM10", 10,    _xmm},
    {"XMM11", 11,    _xmm},
    {"XMM12", 12,    _xmm},
    {"XMM13", 13,    _xmm},
    {"XMM14", 14,    _xmm},
    {"XMM15", 15,    _xmm},

    {"YMM8",   8,    _ymm},
    {"YMM9",   9,    _ymm},
    {"YMM10", 10,    _ymm},
    {"YMM11", 11,    _ymm},
    {"YMM12", 12,    _ymm},
    {"YMM13", 13,    _ymm},
    {"YMM14", 14,    _ymm},
    {"YMM15", 15,    _ymm},
    {"CR8",   8,     _r64 | _special | _crn},
    {"RIP",   _RIP,  _r64},
];


alias ASM_JUMPTYPE = int;
enum
{
    ASM_JUMPTYPE_UNSPECIFIED,
    ASM_JUMPTYPE_SHORT,
    ASM_JUMPTYPE_NEAR,
    ASM_JUMPTYPE_FAR
}

struct OPND
{
    immutable(REG) *base;        // if plain register
    immutable(REG) *pregDisp1;   // if [register1]
    immutable(REG) *pregDisp2;
    immutable(REG) *segreg;      // if segment override
    bool bOffset;            // if 'offset' keyword
    bool bSeg;               // if 'segment' keyword
    bool bPtr;               // if 'ptr' keyword
    bool bRIP;               // if [RIP] addressing
    uint uchMultiplier;      // register multiplier; valid values are 0,1,2,4,8
    opflag_t usFlags;
    Dsymbol s;
    targ_llong disp;
    real_t vreal = 0.0;
    Type ptype;
    ASM_JUMPTYPE ajt;
}


/*******************************
 */

void asm_chktok(TOK toknum, const(char)* msg)
{
    if (asmstate.tokValue != toknum)
    {
        /* When we run out of tokens, asmstate.tok is null.
         * But when this happens when a ';' was hit.
         */
        asmerr(msg, asmstate.tok ? asmstate.tok.toChars() : ";");
    }
    asm_token();        // keep consuming tokens
}


/*******************************
 */

PTRNTAB asm_classify(OP *pop, OPND[] opnds, out int outNumops)
{
    opflag_t[4] opflags;
    bool    bInvalid64bit = false;

    bool   bRetry = false;

    // How many arguments are there?  the parser is strictly left to right
    // so this should work.
    foreach (i, ref opnd; opnds)
    {
        opnd.usFlags = opflags[i] = asm_determine_operand_flags(opnd);
    }
    const usNumops = cast(int)opnds.length;


    // Now check to insure that the number of operands is correct
    auto usActual = (pop.usNumops & ITSIZE);

    void paramError()
    {
        asmerr("%u operands found for `%s` instead of the expected %d", usNumops, asm_opstr(pop), usActual);
    }

    if (usActual != usNumops && asmstate.ucItype != ITopt &&
        asmstate.ucItype != ITfloat)
    {
        paramError();
    }
    if (usActual < usNumops)
        outNumops = usActual;
    else
        outNumops = usNumops;


    void TYPE_SIZE_ERROR()
    {
        foreach (i, ref opnd; opnds)
        {
            if (ASM_GET_aopty(opnd.usFlags) == _reg)
                continue;

            opflags[i] = opnd.usFlags = (opnd.usFlags & ~0x1F) | OpndSize._anysize;
            if(asmstate.ucItype != ITjump)
                continue;

            if (i == 0 && bRetry && opnd.s && !opnd.s.isLabel())
            {
                asmerr("label expected", opnd.s.toChars());
                return;
            }
            opnd.usFlags |= CONSTRUCT_FLAGS(0, 0, 0, _fanysize);
        }
        if (bRetry)
        {
            if(bInvalid64bit)
                asmerr("operand for `%s` invalid in 64bit mode", asm_opstr(pop));
            else
                asmerr("bad type/size of operands `%s`", asm_opstr(pop));
            return;
        }
        bRetry = true;
    }

    PTRNTAB returnIt(PTRNTAB ret)
    {
        if (bRetry)
        {
            asmerr("bad type/size of operands `%s`", asm_opstr(pop));
        }
        return ret;
    }

    void printMismatches(int usActual)
    {
        printOperands(pop, opnds);
        printf("OPCODE mismatch = ");
        foreach (i; 0 .. usActual)
        {
            if (i < opnds.length)
                asm_output_flags(opnds[i].usFlags);
            else
                printf("NONE");
        }
        printf("\n");
    }

//
//  The number of arguments matches, now check to find the opcode
//  in the associated opcode table
//
RETRY:
    //printf("usActual = %d\n", usActual);
    switch (usActual)
    {
        case 0:
            if (target.is64bit && (pop.ptb.pptb0.usFlags & _i64_bit))
            {
                asmerr("opcode `%s` is unavailable in 64bit mode", asm_opstr(pop));  // illegal opcode in 64bit mode
                break;
            }
            if ((asmstate.ucItype == ITopt ||
                 asmstate.ucItype == ITfloat) &&
                usNumops != 0)
            {
                paramError();
                break;
            }
            return returnIt(pop.ptb);

        case 1:
        {
            enum log = false;
            if (log) { printf("`%s`\n", asm_opstr(pop)); }
            if (log) { printf("opflags1 = "); asm_output_flags(opflags[0]); printf("\n"); }

            if (pop.ptb.pptb1.opcode == 0xE8 &&
                opnds[0].s == asmstate.psDollar &&
                (opnds[0].disp >= byte.min && opnds[0].disp <= byte.max)
               )
                // Rewrite CALL $+disp from rel8 to rel32
                opflags[0] = CONSTRUCT_FLAGS(OpndSize._32, _rel, _flbl, 0);

            PTRNTAB1 *table1;
            for (table1 = pop.ptb.pptb1; table1.opcode != ASM_END;
                    table1++)
            {
                if (log) { printf("table    = "); asm_output_flags(table1.usOp1); printf("\n"); }
                const bMatch1 = asm_match_flags(opflags[0], table1.usOp1);
                if (log) { printf("bMatch1 = x%x\n", bMatch1); }
                if (bMatch1)
                {
                    if (table1.opcode == 0x68 &&
                        table1.usOp1 == _imm16
                      )
                        // Don't match PUSH imm16 in 32 bit code
                        continue;

                    // Check if match is invalid in 64bit mode
                    if (target.is64bit && (table1.usFlags & _i64_bit))
                    {
                        bInvalid64bit = true;
                        continue;
                    }

                    // Check for ambiguous size
                    if (getOpndSize(opflags[0]) == OpndSize._anysize &&
                        !opnds[0].bPtr &&
                        (table1 + 1).opcode != ASM_END &&
                        getOpndSize(table1.usOp1) == OpndSize._8)
                    {
                        asmerr("operand size for opcode `%s` is ambiguous, add `ptr byte/short/int/long` prefix", asm_opstr(pop));
                        break RETRY;
                    }

                    break;
                }
                if ((asmstate.ucItype == ITimmed) &&
                    asm_match_flags(opflags[0],
                        CONSTRUCT_FLAGS(OpndSize._32_16_8, _imm, _normal,
                                         0)) &&
                        opnds[0].disp == table1.usFlags)
                    break;
                if (asmstate.ucItype == ITopt ||
                    asmstate.ucItype == ITfloat)
                {
                    switch (usNumops)
                    {
                        case 0:
                            if (!table1.usOp1)
                                goto Lfound1;
                            break;
                        case 1:
                            break;
                        default:
                            paramError();
                            break RETRY;
                    }
                }
            }
        Lfound1:
            if (table1.opcode != ASM_END)
            {
                PTRNTAB ret = { pptb1 : table1 };
                return returnIt(ret);
            }
            debug (debuga) printMismatches(usActual);
            TYPE_SIZE_ERROR();
            if (asmstate.errors)
                break;
            goto RETRY;
        }
        case 2:
        {
            enum log = false;
            if (log) { printf("`%s`\n", asm_opstr(pop)); }
            if (log) { printf("`%s`\n", asm_opstr(pop)); }
            if (log) { printf("opflags1 = "); asm_output_flags(opflags[0]); printf("\n"); }
            if (log) { printf("opflags2 = "); asm_output_flags(opflags[1]); printf("\n"); }
            PTRNTAB2 *table2;
            for (table2 = pop.ptb.pptb2;
                 table2.opcode != ASM_END;
                 table2++)
            {
                if (log) { printf("table1   = "); asm_output_flags(table2.usOp1); printf("\n"); }
                if (log) { printf("table2   = "); asm_output_flags(table2.usOp2); printf("\n"); }
                if (target.is64bit && (table2.usFlags & _i64_bit))
                    asmerr("opcode `%s` is unavailable in 64bit mode", asm_opstr(pop));

                const bMatch1 = asm_match_flags(opflags[0], table2.usOp1);
                const bMatch2 = asm_match_flags(opflags[1], table2.usOp2);
                if (log) printf("match1 = %d, match2 = %d\n",bMatch1,bMatch2);
                if (bMatch1 && bMatch2)
                {
                    if (log) printf("match\n");

                    /* Don't match if implicit sign-extension will
                     * change the value of the immediate operand
                     */
                    if (!bRetry && ASM_GET_aopty(table2.usOp2) == _imm)
                    {
                        OpndSize op1size = getOpndSize(table2.usOp1);
                        if (!op1size) // implicit register operand
                        {
                            switch (ASM_GET_uRegmask(table2.usOp1))
                            {
                                case ASM_GET_uRegmask(_al):
                                case ASM_GET_uRegmask(_cl):  op1size = OpndSize._8; break;
                                case ASM_GET_uRegmask(_ax):
                                case ASM_GET_uRegmask(_dx):  op1size = OpndSize._16; break;
                                case ASM_GET_uRegmask(_eax): op1size = OpndSize._32; break;
                                case ASM_GET_uRegmask(_rax): op1size = OpndSize._64; break;
                                default:
                                    assert(0);
                            }
                        }
                        if (op1size > getOpndSize(table2.usOp2))
                        {
                            switch(getOpndSize(table2.usOp2))
                            {
                                case OpndSize._8:
                                    if (opnds[1].disp > byte.max)
                                        continue;
                                    break;
                                case OpndSize._16:
                                    if (opnds[1].disp > short.max)
                                        continue;
                                    break;
                                case OpndSize._32:
                                    if (opnds[1].disp > int.max)
                                        continue;
                                    break;
                                default:
                                    assert(0);
                            }
                        }
                    }

                    // Check for ambiguous size
                    if (asmstate.ucItype == ITopt &&
                        getOpndSize(opflags[0]) == OpndSize._anysize &&
                        !opnds[0].bPtr &&
                        opflags[1] == 0 &&
                        table2.usOp2 == 0 &&
                        (table2 + 1).opcode != ASM_END &&
                        getOpndSize(table2.usOp1) == OpndSize._8)
                    {
                        asmerr("operand size for opcode `%s` is ambiguous, add `ptr byte/short/int/long` prefix", asm_opstr(pop));
                        break RETRY;
                    }

                    break;
                }

                if (asmstate.ucItype == ITopt ||
                    asmstate.ucItype == ITfloat)
                {
                    switch (usNumops)
                    {
                        case 0:
                            if (!table2.usOp1)
                                goto Lfound2;
                            break;
                        case 1:
                            if (bMatch1 && !table2.usOp2)
                                goto Lfound2;
                            break;
                        case 2:
                            break;
                        default:
                            paramError();
                            break RETRY;
                    }
                }
version (none)
{
                if (asmstate.ucItype == ITshift &&
                    !table2.usOp2 &&
                    bMatch1 && opnds[1].disp == 1 &&
                    asm_match_flags(opflags2,
                        CONSTRUCT_FLAGS(OpndSize._32_16_8, _imm,_normal,0))
                  )
                    break;
}
            }
        Lfound2:
            if (table2.opcode != ASM_END)
            {
                PTRNTAB ret = { pptb2 : table2 };
                return returnIt(ret);
            }
            debug (debuga) printMismatches(usActual);
            TYPE_SIZE_ERROR();
            if (asmstate.errors)
                break;
            goto RETRY;
        }
        case 3:
        {
            enum log = false;
            if (log) { printf("`%s`\n", asm_opstr(pop)); }
            if (log) { printf("opflags1 = "); asm_output_flags(opflags[0]); printf("\n"); }
            if (log) { printf("opflags2 = "); asm_output_flags(opflags[1]); printf("\n"); }
            if (log) { printf("opflags3 = "); asm_output_flags(opflags[2]); printf("\n"); }
            PTRNTAB3 *table3;
            for (table3 = pop.ptb.pptb3;
                 table3.opcode != ASM_END;
                 table3++)
            {
                if (log) { printf("table1   = "); asm_output_flags(table3.usOp1); printf("\n"); }
                if (log) { printf("table2   = "); asm_output_flags(table3.usOp2); printf("\n"); }
                if (log) { printf("table3   = "); asm_output_flags(table3.usOp3); printf("\n"); }
                const bMatch1 = asm_match_flags(opflags[0], table3.usOp1);
                const bMatch2 = asm_match_flags(opflags[1], table3.usOp2);
                const bMatch3 = asm_match_flags(opflags[2], table3.usOp3);
                if (bMatch1 && bMatch2 && bMatch3)
                {
                    if (log) printf("match\n");

                    // Check for ambiguous size
                    if (asmstate.ucItype == ITopt &&
                        getOpndSize(opflags[0]) == OpndSize._anysize &&
                        !opnds[0].bPtr &&
                        opflags[1] == 0 &&
                        opflags[2] == 0 &&
                        table3.usOp2 == 0 &&
                        table3.usOp3 == 0 &&
                        (table3 + 1).opcode != ASM_END &&
                        getOpndSize(table3.usOp1) == OpndSize._8)
                    {
                        asmerr("operand size for opcode `%s` is ambiguous, add `ptr byte/short/int/long` prefix", asm_opstr(pop));
                        break RETRY;
                    }

                    goto Lfound3;
                }
                if (asmstate.ucItype == ITopt)
                {
                    switch (usNumops)
                    {
                        case 0:
                            if (!table3.usOp1)
                                goto Lfound3;
                            break;
                        case 1:
                            if (bMatch1 && !table3.usOp2)
                                goto Lfound3;
                            break;
                        case 2:
                            if (bMatch1 && bMatch2 && !table3.usOp3)
                                goto Lfound3;
                            break;
                        case 3:
                            break;
                        default:
                            paramError();
                            break RETRY;
                    }
                }
            }
        Lfound3:
            if (table3.opcode != ASM_END)
            {
                PTRNTAB ret = { pptb3 : table3 };
                return returnIt(ret);
            }
            debug (debuga) printMismatches(usActual);
            TYPE_SIZE_ERROR();
            if (asmstate.errors)
                break;
            goto RETRY;
        }
        case 4:
        {
            PTRNTAB4 *table4;
            for (table4 = pop.ptb.pptb4;
                 table4.opcode != ASM_END;
                 table4++)
            {
                const bMatch1 = asm_match_flags(opflags[0], table4.usOp1);
                const bMatch2 = asm_match_flags(opflags[1], table4.usOp2);
                const bMatch3 = asm_match_flags(opflags[2], table4.usOp3);
                const bMatch4 = asm_match_flags(opflags[3], table4.usOp4);
                if (bMatch1 && bMatch2 && bMatch3 && bMatch4)
                    goto Lfound4;
                if (asmstate.ucItype == ITopt)
                {
                    switch (usNumops)
                    {
                        case 0:
                            if (!table4.usOp1)
                                goto Lfound4;
                            break;
                        case 1:
                            if (bMatch1 && !table4.usOp2)
                                goto Lfound4;
                            break;
                        case 2:
                            if (bMatch1 && bMatch2 && !table4.usOp3)
                                goto Lfound4;
                            break;
                        case 3:
                            if (bMatch1 && bMatch2 && bMatch3 && !table4.usOp4)
                                goto Lfound4;
                            break;
                        case 4:
                            break;
                        default:
                            paramError();
                            break RETRY;
                    }
                }
            }
        Lfound4:
            if (table4.opcode != ASM_END)
            {
                PTRNTAB ret = { pptb4 : table4 };
                return returnIt(ret);
            }
            debug (debuga) printMismatches(usActual);
            TYPE_SIZE_ERROR();
            if (asmstate.errors)
                break;
            goto RETRY;
        }
        default:
            break;
    }

    return returnIt(PTRNTAB(null));
}

/*******************************
 */

opflag_t asm_determine_float_flags(ref OPND popnd)
{
    //printf("asm_determine_float_flags()\n");

    opflag_t us, usFloat;

    // Insure that if it is a register, that it is not a normal processor
    // register.

    if (popnd.base &&
        !popnd.s && !popnd.disp && !popnd.vreal
        && !isOneOf(getOpndSize(popnd.base.ty), OpndSize._32_16_8))
    {
        return popnd.base.ty;
    }
    if (popnd.pregDisp1 && !popnd.base)
    {
        us = asm_float_type_size(popnd.ptype, &usFloat);
        //printf("us = x%x, usFloat = x%x\n", us, usFloat);
        if (getOpndSize(popnd.pregDisp1.ty) == OpndSize._16)
            return CONSTRUCT_FLAGS(us, _m, _addr16, usFloat);
        else
            return CONSTRUCT_FLAGS(us, _m, _addr32, usFloat);
    }
    else if (popnd.s !is null)
    {
        us = asm_float_type_size(popnd.ptype, &usFloat);
        return CONSTRUCT_FLAGS(us, _m, _normal, usFloat);
    }

    if (popnd.segreg)
    {
        us = asm_float_type_size(popnd.ptype, &usFloat);
        return(CONSTRUCT_FLAGS(us, _m, _addr32, usFloat));
    }

version (none)
{
    if (popnd.vreal)
    {
        switch (popnd.ptype.ty)
        {
            case Tfloat32:
                popnd.s = fconst(popnd.vreal);
                return(CONSTRUCT_FLAGS(_32, _m, _normal, 0));

            case Tfloat64:
                popnd.s = dconst(popnd.vreal);
                return(CONSTRUCT_FLAGS(0, _m, _normal, _f64));

            case Tfloat80:
                popnd.s = ldconst(popnd.vreal);
                return(CONSTRUCT_FLAGS(0, _m, _normal, _f80));
        }
    }
}

    asmerr("unknown operand for floating point instruction");
    return 0;
}

/*******************************
 */

opflag_t asm_determine_operand_flags(ref OPND popnd)
{
    //printf("asm_determine_operand_flags()\n");
    Dsymbol ps;
    int ty;
    opflag_t us;
    opflag_t sz;
    ASM_OPERAND_TYPE opty;
    ASM_MODIFIERS amod;

    // If specified 'offset' or 'segment' but no symbol
    if ((popnd.bOffset || popnd.bSeg) && !popnd.s)
    {
        asmerr("specified 'offset' or 'segment' but no symbol");
        return 0;
    }

    if (asmstate.ucItype == ITfloat)
        return asm_determine_float_flags(popnd);

    // If just a register
    if (popnd.base && !popnd.s && !popnd.disp && !popnd.vreal)
            return popnd.base.ty;
    debug (debuga)
        printf("popnd.base = %s\n, popnd.pregDisp1 = %p\n", (popnd.base ? popnd.base.regstr : "NONE").ptr, popnd.pregDisp1);

    ps = popnd.s;
    Declaration ds = ps ? ps.isDeclaration() : null;
    if (ds && ds.storage_class & STC.lazy_)
        sz = OpndSize._anysize;
    else
    {
        auto ptype = (ds && ds.storage_class & (STC.out_ | STC.ref_)) ? popnd.ptype.pointerTo() : popnd.ptype;
        sz = asm_type_size(ptype, popnd.bPtr);
    }

    if (popnd.bRIP)
        return CONSTRUCT_FLAGS(sz, _m, _addr32, 0);
    else if (popnd.pregDisp1 && !popnd.base)
    {
        if (ps && ps.isLabel() && sz == OpndSize._anysize)
            sz = OpndSize._32;
        return getOpndSize(popnd.pregDisp1.ty) == OpndSize._16
            ? CONSTRUCT_FLAGS(sz, _m, _addr16, 0)
            : CONSTRUCT_FLAGS(sz, _m, _addr32, 0);
    }
    else if (ps)
    {
        if (popnd.bOffset || popnd.bSeg || ps == asmstate.psLocalsize)
            return CONSTRUCT_FLAGS(OpndSize._32, _imm, _normal, 0);

        if (ps.isLabel())
        {
            switch (popnd.ajt)
            {
                case ASM_JUMPTYPE_UNSPECIFIED:
                    if (ps == asmstate.psDollar)
                    {
                        if (popnd.disp >= byte.min &&
                            popnd.disp <= byte.max)
                            us = CONSTRUCT_FLAGS(OpndSize._8, _rel, _flbl,0);
                        //else if (popnd.disp >= short.min &&
                            //popnd.disp <= short.max && global.params.is16bit)
                            //us = CONSTRUCT_FLAGS(OpndSize._16, _rel, _flbl,0);
                        else
                            us = CONSTRUCT_FLAGS(OpndSize._32, _rel, _flbl,0);
                    }
                    else if (asmstate.ucItype != ITjump)
                    {
                        if (sz == OpndSize._8)
                        {
                            us = CONSTRUCT_FLAGS(OpndSize._8,_rel,_flbl,0);
                            break;
                        }
                        goto case_near;
                    }
                    else
                        us = CONSTRUCT_FLAGS(OpndSize._32_8, _rel, _flbl,0);
                    break;

                case ASM_JUMPTYPE_NEAR:
                case_near:
                    us = CONSTRUCT_FLAGS(OpndSize._32, _rel, _flbl, 0);
                    break;
                case ASM_JUMPTYPE_SHORT:
                    us = CONSTRUCT_FLAGS(OpndSize._8, _rel, _flbl, 0);
                    break;
                case ASM_JUMPTYPE_FAR:
                    us = CONSTRUCT_FLAGS(OpndSize._48, _rel, _flbl, 0);
                    break;
                default:
                    assert(0);
            }
            return us;
        }
        if (!popnd.ptype)
            return CONSTRUCT_FLAGS(sz, _m, _normal, 0);
        ty = popnd.ptype.ty;
        if (popnd.ptype.isPtrToFunction() &&
            !ps.isVarDeclaration())
        {
            return CONSTRUCT_FLAGS(OpndSize._32, _m, _fn16, 0);
        }
        else if (ty == Tfunction)
        {
            return CONSTRUCT_FLAGS(OpndSize._32, _rel, _fn16, 0);
        }
        else if (asmstate.ucItype == ITjump)
        {
            amod = _normal;
            goto L1;
        }
        else
            return CONSTRUCT_FLAGS(sz, _m, _normal, 0);
    }

    if (popnd.segreg /*|| popnd.bPtr*/)
    {
        amod = _addr32;
        if (asmstate.ucItype == ITjump)
        {
        L1:
            opty = _m;
            if (sz == OpndSize._48)
                opty = _mnoi;
            us = CONSTRUCT_FLAGS(sz,opty,amod,0);
        }
        else
            us = CONSTRUCT_FLAGS(sz,
//                               _rel, amod, 0);
                                 _m, amod, 0);
    }
    else if (popnd.ptype)
        us = CONSTRUCT_FLAGS(sz, _imm, _normal, 0);
    else if (popnd.disp >= byte.min && popnd.disp <= ubyte.max)
        us = CONSTRUCT_FLAGS( OpndSize._64_32_16_8, _imm, _normal, 0);
    else if (popnd.disp >= short.min && popnd.disp <= ushort.max)
        us = CONSTRUCT_FLAGS( OpndSize._64_32_16, _imm, _normal, 0);
    else if (popnd.disp >= int.min && popnd.disp <= uint.max)
        us = CONSTRUCT_FLAGS( OpndSize._64_32, _imm, _normal, 0);
    else
        us = CONSTRUCT_FLAGS( OpndSize._64, _imm, _normal, 0);
    return us;
}

/******************************
 * Convert assembly instruction into a code, and append
 * it to the code generated for this block.
 */

code *asm_emit(Loc loc,
    uint usNumops, PTRNTAB ptb,
    OP *pop, OPND[] opnds)
{
    ubyte[16] instruction = void;
    size_t insIdx = 0;
    debug
    {
        void emit(ubyte op) { instruction[insIdx++] = op; }
    }
    else
    {
        void emit(ubyte op) { }
    }
//  uint us;
    code *pc = null;
    OPND *popndTmp = null;
    //ASM_OPERAND_TYPE    aopty1 = _reg , aopty2 = 0, aopty3 = 0;
    ASM_MODIFIERS[2] amods = _normal;
    OpndSize[3] uSizemaskTable;
    ASM_OPERAND_TYPE[3] aoptyTable = _reg;
    ASM_MODIFIERS[2] amodTable = _normal;
    uint[2] uRegmaskTable = 0;

    pc = code_calloc();
    pc.Iflags |= CFpsw;            // assume we want to keep the flags


    void setImmediateFlags(size_t i)
    {
        emit(0x67);
        pc.Iflags |= CFaddrsize;
        if (!target.is64bit)
            amods[i] = _addr16;
        else
            amods[i] = _addr32;
        opnds[i].usFlags &= ~CONSTRUCT_FLAGS(0,0,7,0);
        opnds[i].usFlags |= CONSTRUCT_FLAGS(0,0,amods[i],0);
    }

    void setCodeForImmediate(ref OPND opnd, uint sizeMask){
        Declaration d = opnd.s ? opnd.s.isDeclaration() : null;
        if (opnd.bSeg)
        {
            if (!(d && d.isDataseg()))
            {
                asmerr("bad addr mode");
                return;
            }
        }
        switch (sizeMask)
        {
            case OpndSize._8:
            case OpndSize._16:
            case OpndSize._32:
            case OpndSize._64:
                if (opnd.s == asmstate.psLocalsize)
                {
                    pc.IFL2 = FLlocalsize;
                    pc.IEV2.Vdsym = null;
                    pc.Iflags |= CFoff;
                    pc.IEV2.Voffset = opnd.disp;
                }
                else if (d)
                {
                    //if ((pc.IFL2 = d.Sfl) == 0)
                    pc.IFL2 = FLdsymbol;
                    pc.Iflags &= ~(CFseg | CFoff);
                    if (opnd.bSeg)
                        pc.Iflags |= CFseg;
                    else
                        pc.Iflags |= CFoff;
                    pc.IEV2.Voffset = opnd.disp;
                    pc.IEV2.Vdsym = cast(_Declaration*)d;
                }
                else
                {
                    pc.IEV2.Vllong = opnd.disp;
                    pc.IFL2 = FLconst;
                }
                break;

            default:
                break;
        }
    }

    static code* finalizeCode(Loc loc, code* pc, PTRNTAB ptb)
    {
        if ((pc.Iop & ~7) == 0xD8 &&
            ADDFWAIT &&
            !(ptb.pptb0.usFlags & _nfwait))
            pc.Iflags |= CFwait;
        else if ((ptb.pptb0.usFlags & _fwait) &&
                 config.target_cpu >= TARGET_80386)
            pc.Iflags |= CFwait;

        debug (debuga)
        {
            foreach (u; instruction[0 .. insIdx])
                printf("  %02X", u);

            printOperands(pop, opnds);
        }

        CodeBuilder cdb;
        cdb.ctor();

        if (global.params.symdebug)
        {
            cdb.genlinnum(Srcpos.create(loc.filename, loc.linnum, loc.charnum));
        }

        cdb.append(pc);
        return cdb.finish();
    }

    if (opnds.length >= 1)
    {
        amods[0] = ASM_GET_amod(opnds[0].usFlags);

        uSizemaskTable[0] = getOpndSize(ptb.pptb1.usOp1);
        aoptyTable[0] = ASM_GET_aopty(ptb.pptb1.usOp1);
        amodTable[0] = ASM_GET_amod(ptb.pptb1.usOp1);
        uRegmaskTable[0] = ASM_GET_uRegmask(ptb.pptb1.usOp1);

    }
    if (opnds.length >= 2)
    {
        version (none)
        {
            printf("\nasm_emit:\nop: ");
            asm_output_flags(opnds[1].usFlags);
            printf("\ntb: ");
            asm_output_flags(ptb.pptb2.usOp2);
            printf("\n");
        }

        amods[1] = ASM_GET_amod(opnds[1].usFlags);

        uSizemaskTable[1] = getOpndSize(ptb.pptb2.usOp2);
        aoptyTable[1] = ASM_GET_aopty(ptb.pptb2.usOp2);
        amodTable[1] = ASM_GET_amod(ptb.pptb2.usOp2);
        uRegmaskTable[1] = ASM_GET_uRegmask(ptb.pptb2.usOp2);
    }
    if (opnds.length >= 3)
    {
        uSizemaskTable[2] = getOpndSize(ptb.pptb3.usOp3);
        aoptyTable[2] = ASM_GET_aopty(ptb.pptb3.usOp3);
    }

    asmstate.statement.regs |= asm_modify_regs(ptb, opnds);

    if (ptb.pptb0.usFlags & _64_bit && !target.is64bit)
        asmerr("use -m64 to compile 64 bit instructions");

    if (target.is64bit && (ptb.pptb0.usFlags & _64_bit))
    {
        emit(REX | REX_W);
        pc.Irex |= REX_W;
    }

    final switch (usNumops)
    {
        case 0:
            if (ptb.pptb0.usFlags & _16_bit)
            {
                emit(0x66);
                pc.Iflags |= CFopsize;
            }
            break;

        // vex adds 4 operand instructions, but already provides
        // encoded operation size
        case 4:
            break;

        // 3 and 2 are the same because the third operand is always
        // an immediate and does not affect operation size
        case 3:
        case 2:
            if ((!target.is64bit &&
                  (amods[1] == _addr16 ||
                   (isOneOf(OpndSize._16, uSizemaskTable[1]) && aoptyTable[1] == _rel ) ||
                   (isOneOf(OpndSize._32, uSizemaskTable[1]) && aoptyTable[1] == _mnoi) ||
                   (ptb.pptb2.usFlags & _16_bit_addr)
                 )
                )
              )
                setImmediateFlags(1);

        /* Fall through, operand 1 controls the opsize, but the
            address size can be in either operand 1 or operand 2,
            hence the extra checking the flags tested for SHOULD
            be mutex on operand 1 and operand 2 because there is
            only one MOD R/M byte
         */
            goto case;

        case 1:
            if ((!target.is64bit &&
                  (amods[0] == _addr16 ||
                   (isOneOf(OpndSize._16, uSizemaskTable[0]) && aoptyTable[0] == _rel ) ||
                   (isOneOf(OpndSize._32, uSizemaskTable[0]) && aoptyTable[0] == _mnoi) ||
                    (ptb.pptb1.usFlags & _16_bit_addr))))
                setImmediateFlags(0);

            // If the size of the operand is unknown, assume that it is
            // the default size
            if (ptb.pptb0.usFlags & _16_bit)
            {
                //if (asmstate.ucItype != ITjump)
                {
                    emit(0x66);
                    pc.Iflags |= CFopsize;
                }
            }

            const(REG) *pregSegment;
            if (opnds[0].segreg != null)
            {
                popndTmp = &opnds[0];
                pregSegment = opnds[0].segreg;
            }
            if (!pregSegment)
            {
                popndTmp = opnds.length >= 2 ? &opnds[1] : null;
                pregSegment = popndTmp ? popndTmp.segreg : null;
            }
            if (pregSegment)
            {
                uint usDefaultseg;
                if ((popndTmp.pregDisp1 &&
                        popndTmp.pregDisp1.val == _BP) ||
                        popndTmp.pregDisp2 &&
                        popndTmp.pregDisp2.val == _BP)
                        usDefaultseg = _SS;
                else if (asmstate.ucItype == ITjump)
                        usDefaultseg = _CS;
                else
                        usDefaultseg = _DS;
                if (pregSegment.val != usDefaultseg)
                {
                    if (asmstate.ucItype == ITjump)
                        asmerr("Cannot generate a segment prefix for a branching instruction");
                    else
                        switch (pregSegment.val)
                        {
                        case _CS:
                            emit(SEGCS);
                            pc.Iflags |= CFcs;
                            break;
                        case _SS:
                            emit(SEGSS);
                            pc.Iflags |= CFss;
                            break;
                        case _DS:
                            emit(SEGDS);
                            pc.Iflags |= CFds;
                            break;
                        case _ES:
                            emit(SEGES);
                            pc.Iflags |= CFes;
                            break;
                        case _FS:
                            emit(SEGFS);
                            pc.Iflags |= CFfs;
                            break;
                        case _GS:
                            emit(SEGGS);
                            pc.Iflags |= CFgs;
                            break;
                        default:
                            assert(0);
                        }
                }
            }
            break;
    }
    uint opcode = ptb.pptb0.opcode;

    pc.Iop = opcode;
    if (pc.Ivex.pfx == 0xC4)
    {
        debug const oIdx = insIdx;
        ASM_OPERAND_TYPE    aoptyTmp;
        OpndSize uSizemaskTmp;

        // vvvv
        switch (pc.Ivex.vvvv)
        {
        case VEX_NOO:
            pc.Ivex.vvvv = 0xF; // not used

            if ((aoptyTable[0] == _m || aoptyTable[0] == _rm) &&
                aoptyTable[1] == _reg)
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    opnds[0 .. opnds.length >= 2 ? 2 : 1]);
            else if (usNumops == 2 || usNumops == 3 && aoptyTable[2] == _imm)
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    [opnds[1], opnds[0]]);
            else
                assert(!usNumops); // no operands

            if (usNumops == 3)
            {
                popndTmp = &opnds[2];
                aoptyTmp = ASM_GET_aopty(ptb.pptb3.usOp3);
                uSizemaskTmp = getOpndSize(ptb.pptb3.usOp3);
                assert(aoptyTmp == _imm);
            }
            break;

        case VEX_NDD:
            pc.Ivex.vvvv = cast(ubyte) ~int(opnds[0].base.val);

            asm_make_modrm_byte(
                &emit,
                pc,
                ptb.pptb1.usFlags,
                [opnds[1]]);

            if (usNumops == 3)
            {
                popndTmp = &opnds[2];
                aoptyTmp = ASM_GET_aopty(ptb.pptb3.usOp3);
                uSizemaskTmp = getOpndSize(ptb.pptb3.usOp3);
                assert(aoptyTmp == _imm);
            }
            break;

        case VEX_DDS:
            assert(usNumops == 3);
            pc.Ivex.vvvv = cast(ubyte) ~int(opnds[1].base.val);

            asm_make_modrm_byte(
                &emit,
                pc,
                ptb.pptb1.usFlags,
                [opnds[2], opnds[0]]);
            break;

        case VEX_NDS:
            pc.Ivex.vvvv = cast(ubyte) ~int(opnds[1].base.val);

            if (aoptyTable[0] == _m || aoptyTable[0] == _rm)
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    [opnds[0], opnds[2]]);
            else
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    [opnds[2], opnds[0]]);

            if (usNumops == 4)
            {
                popndTmp = &opnds[3];
                aoptyTmp = ASM_GET_aopty(ptb.pptb4.usOp4);
                uSizemaskTmp = getOpndSize(ptb.pptb4.usOp4);
                assert(aoptyTmp == _imm);
            }
            break;

        default:
            assert(0);
        }

        // REX
        // REX_W is solely taken from WO/W1/WIG
        // pc.Ivex.w = !!(pc.Irex & REX_W);
        pc.Ivex.b =  !(pc.Irex & REX_B);
        pc.Ivex.x =  !(pc.Irex & REX_X);
        pc.Ivex.r =  !(pc.Irex & REX_R);

        /* Check if a 3-byte vex is needed.
         */
        checkSetVex3(pc);
        if (pc.Iflags & CFvex3)
        {
            debug
            {
                memmove(&instruction[oIdx+3], &instruction[oIdx], insIdx-oIdx);
                insIdx = oIdx;
            }
            emit(0xC4);
            emit(cast(ubyte)VEX3_B1(pc.Ivex));
            emit(cast(ubyte)VEX3_B2(pc.Ivex));
            pc.Iflags |= CFvex3;
        }
        else
        {
            debug
            {
                memmove(&instruction[oIdx+2], &instruction[oIdx], insIdx-oIdx);
                insIdx = oIdx;
            }
            emit(0xC5);
            emit(cast(ubyte)VEX2_B1(pc.Ivex));
        }
        pc.Iflags |= CFvex;
        emit(pc.Ivex.op);
        if (popndTmp && aoptyTmp == _imm)
            setCodeForImmediate(*popndTmp, uSizemaskTmp);
        return finalizeCode(loc, pc, ptb);
    }

    else if ((opcode & 0xFFFD00) == 0x0F3800)    // SSSE3, SSE4
    {
        emit(0xFF);
        emit(0xFD);
        emit(0x00);
        goto L3;
    }

    switch (opcode & 0xFF0000)
    {
        case 0:
            break;

        case 0x660000:
            opcode &= 0xFFFF;
            goto L3;

        case 0xF20000:                      // REPNE
        case 0xF30000:                      // REP/REPE
            // BUG: What if there's an address size prefix or segment
            // override prefix? Must the REP be adjacent to the rest
            // of the opcode?
            opcode &= 0xFFFF;
            goto L3;

        case 0x0F0000:                      // an AMD instruction
            const puc = (cast(ubyte *) &opcode);
            emit(puc[2]);
            emit(puc[1]);
            emit(puc[0]);
            pc.Iop >>= 8;
            if (puc[1] == 0x0F)             // if AMD instruction 0x0F0F
            {
                pc.IEV2.Vint = puc[0];
                pc.IFL2 = FLconst;
            }
            else
                pc.Irm = puc[0];
            goto L3;

        default:
            const puc = (cast(ubyte *) &opcode);
            emit(puc[2]);
            emit(puc[1]);
            emit(puc[0]);
            pc.Iop >>= 8;
            pc.Irm = puc[0];
            goto L3;
    }
    if (opcode & 0xff00)
    {
        const puc = (cast(ubyte *) &(opcode));
        emit(puc[1]);
        emit(puc[0]);
        pc.Iop = puc[1];
        if (pc.Iop == 0x0f)
        {
            pc.Iop = 0x0F00 | puc[0];
        }
        else
        {
            if (opcode == 0xDFE0) // FSTSW AX
            {
                pc.Irm = puc[0];
                return finalizeCode(loc, pc, ptb);
            }
            if (asmstate.ucItype == ITfloat)
            {
                pc.Irm = puc[0];
            }
            else if (opcode == PAUSE)
            {
                pc.Iop = PAUSE;
            }
            else
            {
                pc.IEV2.Vint = puc[0];
                pc.IFL2 = FLconst;
            }
        }
    }
    else
    {
        emit(cast(ubyte)opcode);
    }
L3:

    // If CALL, Jxx or LOOPx to a symbolic location
    if (/*asmstate.ucItype == ITjump &&*/
        opnds.length >= 1 && opnds[0].s && opnds[0].s.isLabel())
    {
        Dsymbol s = opnds[0].s;
        if (s == asmstate.psDollar)
        {
            pc.IFL2 = FLconst;
            if (isOneOf(OpndSize._8,  uSizemaskTable[0]) ||
                isOneOf(OpndSize._16, uSizemaskTable[0]))
                pc.IEV2.Vint = cast(int)opnds[0].disp;
            else if (isOneOf(OpndSize._32, uSizemaskTable[0]))
                pc.IEV2.Vpointer = cast(targ_size_t) opnds[0].disp;
        }
        else
        {
            LabelDsymbol label = s.isLabel();
            if (label)
            {
                if ((pc.Iop & ~0x0F) == 0x70)
                    pc.Iflags |= CFjmp16;
                if (usNumops == 1)
                {
                    pc.IFL2 = FLblock;
                    pc.IEV2.Vlsym = cast(_LabelDsymbol*)label;
                }
                else
                {
                    pc.IFL1 = FLblock;
                    pc.IEV1.Vlsym = cast(_LabelDsymbol*)label;
                }
            }
        }
    }

    final switch (usNumops)
    {
        case 0:
            break;
        case 1:
            if (((aoptyTable[0] == _reg || aoptyTable[0] == _float) &&
                 amodTable[0] == _normal && (uRegmaskTable[0] & _rplus_r)))
            {
                uint reg = opnds[0].base.val;
                if (reg & 8)
                {
                    reg &= 7;
                    pc.Irex |= REX_B;
                    assert(target.is64bit);
                }
                if (asmstate.ucItype == ITfloat)
                    pc.Irm += reg;
                else
                    pc.Iop += reg;
                debug instruction[insIdx-1] += reg;
            }
            else
            {
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    [opnds[0]]);
            }
            if (aoptyTable[0] == _imm)
                setCodeForImmediate(opnds[0], uSizemaskTable[0]);
            break;
    case 2:
//
// If there are two immediate operands then
//
        if (aoptyTable[0] == _imm &&
            aoptyTable[1] == _imm)
        {
                pc.IEV1.Vint = cast(int)opnds[0].disp;
                pc.IFL1 = FLconst;
                pc.IEV2.Vint = cast(int)opnds[1].disp;
                pc.IFL2 = FLconst;
                break;
        }
        if (aoptyTable[1] == _m ||
            aoptyTable[1] == _rel ||
            // If not MMX register (_mm) or XMM register (_xmm)
            (amodTable[0] == _rspecial && !(uRegmaskTable[0] & (0x08 | 0x10)) && !uSizemaskTable[0]) ||
            aoptyTable[1] == _rm ||
            (opnds[0].usFlags == _r32 && opnds[1].usFlags == _xmm) ||
            (opnds[0].usFlags == _r32 && opnds[1].usFlags == _mm))
        {
            version (none)
            {
                printf("test4 %d,%d,%d,%d\n",
                    (aoptyTable[1] == _m),
                    (aoptyTable[1] == _rel),
                    (amodTable[0] == _rspecial && !(uRegmaskTable[0] & (0x08 | 0x10))),
                    (aoptyTable[1] == _rm)
                    );
                printf("opcode = %x\n", opcode);
            }
            if (ptb.pptb0.opcode == 0x0F7E ||    // MOVD _rm32,_mm
                ptb.pptb0.opcode == 0x660F7E     // MOVD _rm32,_xmm
               )
            {
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    opnds[0 .. 2]);
            }
            else
            {
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    [opnds[1], opnds[0]]);
            }
            if(aoptyTable[0] == _imm)
                setCodeForImmediate(opnds[0], uSizemaskTable[0]);
        }
        else
        {
            if (((aoptyTable[0] == _reg || aoptyTable[0] == _float) &&
                 amodTable[0] == _normal &&
                 (uRegmaskTable[0] & _rplus_r)))
            {
                uint reg = opnds[0].base.val;
                if (reg & 8)
                {
                    reg &= 7;
                    pc.Irex |= REX_B;
                    assert(target.is64bit);
                }
                else if (opnds[0].base.isSIL_DIL_BPL_SPL())
                {
                    pc.Irex |= REX;
                    assert(target.is64bit);
                }
                if (asmstate.ucItype == ITfloat)
                    pc.Irm += reg;
                else
                    pc.Iop += reg;
                debug instruction[insIdx-1] += reg;
            }
            else if (((aoptyTable[1] == _reg || aoptyTable[1] == _float) &&
                 amodTable[1] == _normal &&
                 (uRegmaskTable[1] & _rplus_r)))
            {
                uint reg = opnds[1].base.val;
                if (reg & 8)
                {
                    reg &= 7;
                    pc.Irex |= REX_B;
                    assert(target.is64bit);
                }
                else if (opnds[0].base.isSIL_DIL_BPL_SPL())
                {
                    pc.Irex |= REX;
                    assert(target.is64bit);
                }
                if (asmstate.ucItype == ITfloat)
                    pc.Irm += reg;
                else
                    pc.Iop += reg;
                debug instruction[insIdx-1] += reg;
            }
            else if (ptb.pptb0.opcode == 0xF30FD6 ||
                     ptb.pptb0.opcode == 0x0F12 ||
                     ptb.pptb0.opcode == 0x0F16 ||
                     ptb.pptb0.opcode == 0x660F50 ||
                     ptb.pptb0.opcode == 0x0F50 ||
                     ptb.pptb0.opcode == 0x660FD7 ||
                     ptb.pptb0.opcode == MOVDQ2Q ||
                     ptb.pptb0.opcode == 0x0FD7)
            {
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    [opnds[1], opnds[0]]);
            }
            else
            {
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    opnds[0 .. 2]);

            }
            if (aoptyTable[0] == _imm)
            {
                setCodeForImmediate(opnds[0], uSizemaskTable[0]);
            }
            else if(aoptyTable[1] == _imm)
            {
                setCodeForImmediate(opnds[1], uSizemaskTable[1]);
            }
        }
        break;

    case 3:
        if (aoptyTable[1] == _m || aoptyTable[1] == _rm ||
            opcode == 0x0FC5     ||    // pextrw  _r32,  _mm,    _imm8
            opcode == 0x660FC5   ||    // pextrw  _r32, _xmm,    _imm8
            opcode == 0x660F3A20 ||    // pinsrb  _xmm, _r32/m8, _imm8
            opcode == 0x660F3A22 ||    // pinsrd  _xmm, _rm32,   _imm8
            opcode == VEX_128_WIG(0x660FC5)    // vpextrw  _r32,  _mm,    _imm8
           )
        {
            asm_make_modrm_byte(
                &emit,
                pc,
                ptb.pptb1.usFlags,
                [opnds[1], opnds[0]]);  // swap operands
        }
        else
        {

            bool setRegisterProperties(int i)
            {
                if (((aoptyTable[i] == _reg || aoptyTable[i] == _float) &&
                     amodTable[i] == _normal &&
                     (uRegmaskTable[i] &_rplus_r)))
                {
                    uint reg = opnds[i].base.val;
                    if (reg & 8)
                    {
                        reg &= 7;
                        pc.Irex |= REX_B;
                        assert(target.is64bit);
                    }
                    if (asmstate.ucItype == ITfloat)
                        pc.Irm += reg;
                    else
                        pc.Iop += reg;
                    debug instruction[insIdx-1] += reg;
                    return true;
                }
                return false;
            }

            if(!setRegisterProperties(0) && !setRegisterProperties(1))
                asm_make_modrm_byte(
                    &emit,
                    pc,
                    ptb.pptb1.usFlags,
                    opnds[0 .. 2]);
        }
        if (aoptyTable[2] == _imm)
            setCodeForImmediate(opnds[2], uSizemaskTable[2]);
        break;
    }
    return finalizeCode(loc, pc, ptb);
}


/*******************************
 */

void asmerr(const(char)* format, ...)
{
    if (asmstate.errors)
        return;

    va_list ap;
    va_start(ap, format);
    verror(asmstate.loc, format, ap);
    va_end(ap);

    asmstate.errors = true;
}

/*******************************
 */

opflag_t asm_float_type_size(Type ptype, opflag_t *pusFloat)
{
    *pusFloat = 0;

    //printf("asm_float_type_size('%s')\n", ptype.toChars());
    if (ptype && ptype.isscalar())
    {
        int sz = cast(int)ptype.size();
        if (sz == target.realsize)
        {
            *pusFloat = _f80;
            return 0;
        }
        switch (sz)
        {
            case 2:
                return OpndSize._16;
            case 4:
                return OpndSize._32;
            case 8:
                *pusFloat = _f64;
                return 0;
            case 10:
                *pusFloat = _f80;
                return 0;
            default:
                break;
        }
    }
    *pusFloat = _fanysize;
    return OpndSize._anysize;
}

/*******************************
 */

private @safe pure bool asm_isint(const ref OPND o)
{
    if (o.base || o.s)
        return false;
    return true;
}

private @safe pure bool asm_isNonZeroInt(const ref OPND o)
{
    if (o.base || o.s)
        return false;
    return o.disp != 0;
}

/*******************************
 */

private @safe pure bool asm_is_fpreg(const(char)[] szReg)
{
    return szReg == "ST";
}

/*******************************
 * Merge operands o1 and o2 into a single operand, o1.
 */

private void asm_merge_opnds(ref OPND o1, ref OPND o2)
{
    void illegalAddressError(string debugWhy)
    {
        debug (debuga) printf("Invalid addr because /%.s/\n",
                              debugWhy.ptr, cast(int)debugWhy.length);
        asmerr("cannot have two symbols in addressing mode");
    }

    //printf("asm_merge_opnds()\n");
    debug (EXTRA_DEBUG) debug (debuga)
    {
        printf("asm_merge_opnds(o1 = ");
        asm_output_popnd(&o1);
        printf(", o2 = ");
        asm_output_popnd(&o2);
        printf(")\n");
    }
    debug (EXTRA_DEBUG)
        printf("Combining Operands: mult1 = %d, mult2 = %d",
                o1.uchMultiplier, o2.uchMultiplier);
    /*      combine the OPND's disp field */
    if (o2.segreg)
    {
        if (o1.segreg)
            return illegalAddressError("o1.segment && o2.segreg");
        else
            o1.segreg = o2.segreg;
    }

    // combine the OPND's symbol field
    if (o1.s && o2.s)
    {
        return illegalAddressError("o1.s && os.s");
    }
    else if (o2.s)
    {
        o1.s = o2.s;
    }
    else if (o1.s && o1.s.isTupleDeclaration())
    {
        TupleDeclaration tup = o1.s.isTupleDeclaration();
        size_t index = cast(int)o2.disp;
        if (index >= tup.objects.dim)
        {
            asmerr("tuple index %llu exceeds length %llu",
                    cast(ulong) index, cast(ulong) tup.objects.dim);
        }
        else
        {
            RootObject o = (*tup.objects)[index];
            if (o.dyncast() == DYNCAST.dsymbol)
            {
                o1.s = cast(Dsymbol)o;
                return;
            }
            else if (o.dyncast() == DYNCAST.expression)
            {
                Expression e = cast(Expression)o;
                if (e.op == TOK.variable)
                {
                    o1.s = (cast(VarExp)e).var;
                    return;
                }
                else if (e.op == TOK.function_)
                {
                    o1.s = (cast(FuncExp)e).fd;
                    return;
                }
            }
            asmerr("invalid asm operand `%s`", o1.s.toChars());
        }
    }

    if (o1.disp && o2.disp)
        o1.disp += o2.disp;
    else if (o2.disp)
        o1.disp = o2.disp;

    /* combine the OPND's base field */
    if (o1.base != null && o2.base != null)
        return illegalAddressError("o1.base != null && o2.base != null");
    else if (o2.base)
        o1.base = o2.base;

    /* Combine the displacement register fields */
    if (o2.pregDisp1)
    {
        if (o1.pregDisp2)
            return illegalAddressError("o2.pregDisp1 && o1.pregDisp2");
        else if (o1.pregDisp1)
        {
            if (o1.uchMultiplier ||
                    (o2.pregDisp1.val == _ESP &&
                    (getOpndSize(o2.pregDisp1.ty) == OpndSize._32) &&
                    !o2.uchMultiplier))
            {
                o1.pregDisp2 = o1.pregDisp1;
                o1.pregDisp1 = o2.pregDisp1;
            }
            else
                o1.pregDisp2 = o2.pregDisp1;
        }
        else
            o1.pregDisp1 = o2.pregDisp1;
    }
    if (o2.pregDisp2)
    {
        if (o1.pregDisp2)
            return illegalAddressError("o1.pregDisp2 && o2.pregDisp2");
        else
            o1.pregDisp2 = o2.pregDisp2;
    }

    if (o1.bRIP && (o1.pregDisp1 || o2.bRIP || o1.base))
        return illegalAddressError("o1.pregDisp1 && RIP");
    o1.bRIP |= o2.bRIP;

    if (o1.base && o1.pregDisp1)
    {
        asmerr("operand cannot have both %s and [%s]", o1.base.regstr.ptr, o1.pregDisp1.regstr.ptr);
        return;
    }

    if (o1.base && o1.disp)
    {
        asmerr("operand cannot have both %s and 0x%llx", o1.base.regstr.ptr, o1.disp);
        return;
    }

    if (o2.uchMultiplier)
    {
        if (o1.uchMultiplier)
            return illegalAddressError("o1.uchMultiplier && o2.uchMultiplier");
        else
            o1.uchMultiplier = o2.uchMultiplier;
    }
    if (o2.ptype && !o1.ptype)
        o1.ptype = o2.ptype;
    if (o2.bOffset)
        o1.bOffset = o2.bOffset;
    if (o2.bSeg)
        o1.bSeg = o2.bSeg;

    if (o2.ajt && !o1.ajt)
        o1.ajt = o2.ajt;

    debug (EXTRA_DEBUG)
        printf("Result = %d\n", o1.uchMultiplier);
    debug (debuga)
    {
        printf("Merged result = /");
        asm_output_popnd(o1);
        printf("/\n");
    }
}

/***************************************
 */

void asm_merge_symbol(ref OPND o1, Dsymbol s)
{
    EnumMember em;

    //printf("asm_merge_symbol(s = %s %s)\n", s.kind(), s.toChars());
    s = s.toAlias();
    //printf("s = %s %s\n", s.kind(), s.toChars());
    if (s.isLabel())
    {
        o1.s = s;
        return;
    }

    if (auto v = s.isVarDeclaration())
    {
        if (auto fd = asmstate.sc.func)
        {
             /* https://issues.dlang.org/show_bug.cgi?id=6166
              * We could leave it on unless fd.nrvo_var==v,
              * but fd.nrvo_var isn't set yet
              */
             fd.nrvo_can = false;
        }

        if (v.isParameter())
            asmstate.statement.refparam = true;

        v.checkNestedReference(asmstate.sc, asmstate.loc);
        if (v.isField())
        {
            o1.disp += v.offset;
            goto L2;
        }

        if (!v.type.isfloating() && v.type.ty != Tvector)
        {
            if (auto e = expandVar(WANTexpand, v))
            {
                if (e.isErrorExp())
                    return;
                o1.disp = e.toInteger();
                return;
            }
        }

        if (v.isThreadlocal())
        {
            asmerr("cannot directly load TLS variable `%s`", v.toChars());
            return;
        }
        else if (v.isDataseg() && global.params.pic != PIC.fixed)
        {
            asmerr("cannot directly load global variable `%s` with PIC or PIE code", v.toChars());
            return;
        }
    }
    em = s.isEnumMember();
    if (em)
    {
        o1.disp = em.value().toInteger();
        return;
    }
    o1.s = s;  // a C identifier
L2:
    Declaration d = s.isDeclaration();
    if (!d)
    {
        asmerr("%s `%s` is not a declaration", s.kind(), s.toChars());
    }
    else if (d.getType())
        asmerr("cannot use type `%s` as an operand", d.getType().toChars());
    else if (d.isTupleDeclaration())
    {
    }
    else
        o1.ptype = d.type.toBasetype();
}

/****************************
 * Fill in the modregrm and sib bytes of code.
 * Params:
 *      emit = where to store instruction bytes generated (for debugging)
 *      pc = instruction to be filled in
 *      usFlags = opflag_t value from ptrntab
 *      opnds = one for each operand
 */

void asm_make_modrm_byte(
        void delegate(ubyte) emit,
        code *pc,
        opflag_t usFlags,
        scope OPND[] opnds)
{
    struct MODRM_BYTE
    {
        uint rm;
        uint reg;
        uint mod;
        uint auchOpcode()
        {
            assert(rm < 8);
            assert(reg < 8);
            assert(mod < 4);
            return (mod << 6) | (reg << 3) | rm;
        }
    }

    struct SIB_BYTE
    {
        uint base;
        uint index;
        uint ss;
        uint auchOpcode()
        {
            assert(base < 8);
            assert(index < 8);
            assert(ss < 4);
            return (ss << 6) | (index << 3) | base;
        }
    }

    MODRM_BYTE  mrmb = { 0, 0, 0 };
    SIB_BYTE    sib = { 0, 0, 0 };
    bool                bSib = false;
    bool                bDisp = false;
    debug ubyte        *puc;
    Dsymbol             s;

    bool                bOffsetsym = false;

    version (none)
    {
        printf("asm_make_modrm_byte(usFlags = x%x)\n", usFlags);
        printf("op1: ");
        asm_output_flags(opnds[0].usFlags);
        printf("\n");
        if (opnds.length == 2)
        {
            printf("op2: ");
            asm_output_flags(opnds[1].usFlags);
        }
        printf("\n");
    }

    const OpndSize uSizemask = getOpndSize(opnds[0].usFlags);
    auto aopty = ASM_GET_aopty(opnds[0].usFlags);
    const amod = ASM_GET_amod(opnds[0].usFlags);
    s = opnds[0].s;
    if (s)
    {
        Declaration d = s.isDeclaration();

        if ((amod == _fn16 || amod == _flbl) && aopty == _rel && opnds.length == 2)
        {
            aopty = _m;
            goto L1;
        }

        if (amod == _fn16 || amod == _fn32)
        {
            pc.Iflags |= CFoff;
            debug
            {
                emit(0);
                emit(0);
            }
            if (aopty == _m || aopty == _mnoi)
            {
                pc.IFL1 = FLdata;
                pc.IEV1.Vdsym = cast(_Declaration*)d;
                pc.IEV1.Voffset = 0;
            }
            else
            {
                if (aopty == _p)
                    pc.Iflags |= CFseg;

                debug
                {
                    if (aopty == _p || aopty == _rel)
                    {
                        emit(0);
                        emit(0);
                    }
                }

                pc.IFL2 = FLfunc;
                pc.IEV2.Vdsym = cast(_Declaration*)d;
                pc.IEV2.Voffset = 0;
                //return;
            }
        }
        else
        {
          L1:
            LabelDsymbol label = s.isLabel();
            if (label)
            {
                if (s == asmstate.psDollar)
                {
                    pc.IFL1 = FLconst;
                    if (isOneOf(uSizemask, OpndSize._16_8))
                        pc.IEV1.Vint = cast(int)opnds[0].disp;
                    else if (isOneOf(uSizemask, OpndSize._32))
                        pc.IEV1.Vpointer = cast(targ_size_t) opnds[0].disp;
                }
                else
                {
                    pc.IFL1 = target.is64bit ? FLblock : FLblockoff;
                    pc.IEV1.Vlsym = cast(_LabelDsymbol*)label;
                }
                pc.Iflags |= CFoff;
            }
            else if (s == asmstate.psLocalsize)
            {
                pc.IFL1 = FLlocalsize;
                pc.IEV1.Vdsym = null;
                pc.Iflags |= CFoff;
                pc.IEV1.Voffset = opnds[0].disp;
            }
            else if (s.isFuncDeclaration())
            {
                pc.IFL1 = FLfunc;
                pc.IEV1.Vdsym = cast(_Declaration*)d;
                pc.Iflags |= CFoff;
                pc.IEV1.Voffset = opnds[0].disp;
            }
            else
            {
                debug (debuga)
                    printf("Setting up symbol %s\n", d.ident.toChars());
                pc.IFL1 = FLdsymbol;
                pc.IEV1.Vdsym = cast(_Declaration*)d;
                pc.Iflags |= CFoff;
                pc.IEV1.Voffset = opnds[0].disp;
            }
        }
    }
    mrmb.reg = usFlags & NUM_MASK;

    if (s && (aopty == _m || aopty == _mnoi))
    {
        if (s.isLabel)
        {
            mrmb.rm = BPRM;
            mrmb.mod = 0x0;
        }
        else if (s == asmstate.psLocalsize)
        {
    DATA_REF:
            mrmb.rm = BPRM;
            if (amod == _addr16 || amod == _addr32)
                mrmb.mod = 0x2;
            else
                mrmb.mod = 0x0;
        }
        else
        {
            Declaration d = s.isDeclaration();
            assert(d);
            if (d.isDataseg() || d.isCodeseg())
            {
                if (!target.is64bit && amod == _addr16)
                {
                    asmerr("cannot have 16 bit addressing mode in 32 bit code");
                    return;
                }
                goto DATA_REF;
            }
            mrmb.rm = BPRM;
            mrmb.mod = 0x2;
        }
    }

    if (aopty == _reg || amod == _rspecial)
    {
        mrmb.mod = 0x3;
        mrmb.rm |= opnds[0].base.val & NUM_MASK;
        if (opnds[0].base.val & NUM_MASKR)
            pc.Irex |= REX_B;
        else if (opnds[0].base.isSIL_DIL_BPL_SPL())
            pc.Irex |= REX;
    }
    else if (amod == _addr16)
    {
        uint rm;

        debug (debuga)
            printf("This is an ADDR16\n");
        if (!opnds[0].pregDisp1)
        {
            rm = 0x6;
            if (!s)
                bDisp = true;
        }
        else
        {
            uint r1r2;
            static uint X(uint r1, uint r2) { return (r1 * 16) + r2; }
            static uint Y(uint r1) { return X(r1,9); }


            if (opnds[0].pregDisp2)
                r1r2 = X(opnds[0].pregDisp1.val,opnds[0].pregDisp2.val);
            else
                r1r2 = Y(opnds[0].pregDisp1.val);
            switch (r1r2)
            {
                case X(_BX,_SI):        rm = 0; break;
                case X(_BX,_DI):        rm = 1; break;
                case Y(_BX):    rm = 7; break;

                case X(_BP,_SI):        rm = 2; break;
                case X(_BP,_DI):        rm = 3; break;
                case Y(_BP):    rm = 6; bDisp = true;   break;

                case X(_SI,_BX):        rm = 0; break;
                case X(_SI,_BP):        rm = 2; break;
                case Y(_SI):    rm = 4; break;

                case X(_DI,_BX):        rm = 1; break;
                case X(_DI,_BP):        rm = 3; break;
                case Y(_DI):    rm = 5; break;

                default:
                    asmerr("bad 16 bit index address mode");
                    return;
            }
        }
        mrmb.rm = rm;

        debug (debuga)
            printf("This is an mod = %d, opnds[0].s =%p, opnds[0].disp = %lld\n",
               mrmb.mod, s, cast(long)opnds[0].disp);
        if (!s || (!mrmb.mod && opnds[0].disp))
        {
            if ((!opnds[0].disp && !bDisp) ||
                !opnds[0].pregDisp1)
                mrmb.mod = 0x0;
            else if (opnds[0].disp >= byte.min &&
                opnds[0].disp <= byte.max)
                mrmb.mod = 0x1;
            else
                mrmb.mod = 0X2;
        }
        else
            bOffsetsym = true;

    }
    else if (amod == _addr32 || (amod == _flbl && !target.is64bit))
    {
        bool bModset = false;

        debug (debuga)
            printf("This is an ADDR32\n");
        if (!opnds[0].pregDisp1)
            mrmb.rm = 0x5;
        else if (opnds[0].pregDisp2 ||
                 opnds[0].uchMultiplier ||
                 (opnds[0].pregDisp1.val & NUM_MASK) == _ESP)
        {
            if (opnds[0].pregDisp2)
            {
                if (opnds[0].pregDisp2.val == _ESP)
                {
                    asmerr("`ESP` cannot be scaled index register");
                    return;
                }
            }
            else
            {
                if (opnds[0].uchMultiplier &&
                    opnds[0].pregDisp1.val ==_ESP)
                {
                    asmerr("`ESP` cannot be scaled index register");
                    return;
                }
                bDisp = true;
            }

            mrmb.rm = 0x4;
            bSib = true;
            if (bDisp)
            {
                if (!opnds[0].uchMultiplier &&
                    (opnds[0].pregDisp1.val & NUM_MASK) == _ESP)
                {
                    sib.base = 4;           // _ESP or _R12
                    sib.index = 0x4;
                    if (opnds[0].pregDisp1.val & NUM_MASKR)
                        pc.Irex |= REX_B;
                }
                else
                {
                    debug (debuga)
                        printf("Resetting the mod to 0\n");
                    if (opnds[0].pregDisp2)
                    {
                        if (opnds[0].pregDisp2.val != _EBP)
                        {
                            asmerr("`EBP` cannot be base register");
                            return;
                        }
                    }
                    else
                    {
                        mrmb.mod = 0x0;
                        bModset = true;
                    }

                    sib.base = 0x5;
                    sib.index = opnds[0].pregDisp1.val & NUM_MASK;
                    if (opnds[0].pregDisp1.val & NUM_MASKR)
                        pc.Irex |= REX_X;
                }
            }
            else
            {
                sib.base = opnds[0].pregDisp1.val & NUM_MASK;
                if (opnds[0].pregDisp1.val & NUM_MASKR)
                    pc.Irex |= REX_B;
                //
                // This is to handle the special case
                // of using the EBP (or R13) register and no
                // displacement.  You must put in an
                // 8 byte displacement in order to
                // get the correct opcodes.
                //
                if ((opnds[0].pregDisp1.val == _EBP ||
                     opnds[0].pregDisp1.val == _R13) &&
                    (!opnds[0].disp && !s))
                {
                    debug (debuga)
                        printf("Setting the mod to 1 in the _EBP case\n");
                    mrmb.mod = 0x1;
                    bDisp = true;   // Need a
                                    // displacement
                    bModset = true;
                }

                sib.index = opnds[0].pregDisp2.val & NUM_MASK;
                if (opnds[0].pregDisp2.val & NUM_MASKR)
                    pc.Irex |= REX_X;

            }
            switch (opnds[0].uchMultiplier)
            {
                case 0: sib.ss = 0; break;
                case 1: sib.ss = 0; break;
                case 2: sib.ss = 1; break;
                case 4: sib.ss = 2; break;
                case 8: sib.ss = 3; break;

                default:
                    asmerr("scale factor must be one of 0,1,2,4,8");
                    return;
            }
        }
        else
        {
            uint rm;

            if (opnds[0].uchMultiplier)
            {
                asmerr("scale factor not allowed");
                return;
            }
            switch (opnds[0].pregDisp1.val & (NUM_MASKR | NUM_MASK))
            {
                case _EBP:
                    if (!opnds[0].disp && !s)
                    {
                        mrmb.mod = 0x1;
                        bDisp = true;   // Need a displacement
                        bModset = true;
                    }
                    rm = 5;
                    break;

                case _ESP:
                    asmerr("`[ESP]` addressing mode not allowed");
                    return;

                default:
                    rm = opnds[0].pregDisp1.val & NUM_MASK;
                    break;
            }
            if (opnds[0].pregDisp1.val & NUM_MASKR)
                pc.Irex |= REX_B;
            mrmb.rm = rm;
        }

        if (!bModset && (!s ||
                (!mrmb.mod && opnds[0].disp)))
        {
            if ((!opnds[0].disp && !mrmb.mod) ||
                (!opnds[0].pregDisp1 && !opnds[0].pregDisp2))
            {
                mrmb.mod = 0x0;
                bDisp = true;
            }
            else if (opnds[0].disp >= byte.min &&
                     opnds[0].disp <= byte.max)
                mrmb.mod = 0x1;
            else
                mrmb.mod = 0x2;
        }
        else
            bOffsetsym = true;
    }
    if (opnds.length == 2 && !mrmb.reg &&
        asmstate.ucItype != ITshift &&
        (ASM_GET_aopty(opnds[1].usFlags) == _reg  ||
         ASM_GET_amod(opnds[1].usFlags) == _rseg ||
         ASM_GET_amod(opnds[1].usFlags) == _rspecial))
    {
        if (opnds[1].base.isSIL_DIL_BPL_SPL())
            pc.Irex |= REX;
        mrmb.reg =  opnds[1].base.val & NUM_MASK;
        if (opnds[1].base.val & NUM_MASKR)
            pc.Irex |= REX_R;
    }
    debug emit(cast(ubyte)mrmb.auchOpcode());
    pc.Irm = cast(ubyte)mrmb.auchOpcode();
    //printf("Irm = %02x\n", pc.Irm);
    if (bSib)
    {
        debug emit(cast(ubyte)sib.auchOpcode());
        pc.Isib= cast(ubyte)sib.auchOpcode();
    }
    if ((!s || (opnds[0].pregDisp1 && !bOffsetsym)) &&
        aopty != _imm &&
        (opnds[0].disp || bDisp))
    {
        if (opnds[0].usFlags & _a16)
        {
            debug
            {
                puc = (cast(ubyte *) &(opnds[0].disp));
                emit(puc[1]);
                emit(puc[0]);
            }
            if (usFlags & (_modrm | NUM_MASK))
            {
                debug (debuga)
                    printf("Setting up value %lld\n", cast(long)opnds[0].disp);
                pc.IEV1.Vint = cast(int)opnds[0].disp;
                pc.IFL1 = FLconst;
            }
            else
            {
                pc.IEV2.Vint = cast(int)opnds[0].disp;
                pc.IFL2 = FLconst;
            }
        }
        else
        {
            debug
            {
                puc = (cast(ubyte *) &(opnds[0].disp));
                emit(puc[3]);
                emit(puc[2]);
                emit(puc[1]);
                emit(puc[0]);
            }
            if (usFlags & (_modrm | NUM_MASK))
            {
                debug (debuga)
                    printf("Setting up value %lld\n", cast(long)opnds[0].disp);
                pc.IEV1.Vpointer = cast(targ_size_t) opnds[0].disp;
                pc.IFL1 = FLconst;
            }
            else
            {
                pc.IEV2.Vpointer = cast(targ_size_t) opnds[0].disp;
                pc.IFL2 = FLconst;
            }

        }
    }
}

/*******************************
 */

regm_t asm_modify_regs(PTRNTAB ptb, scope OPND[] opnds)
{
    regm_t usRet = 0;

    switch (ptb.pptb0.usFlags & MOD_MASK)
    {
    case _modsi:
        usRet |= mSI;
        break;
    case _moddx:
        usRet |= mDX;
        break;
    case _mod2:
        if (opnds.length >= 2)
            usRet |= asm_modify_regs(ptb, opnds[1 .. 2]);
        break;
    case _modax:
        usRet |= mAX;
        break;
    case _modnot1:
        opnds = [];
        break;
    case _modaxdx:
        usRet |= (mAX | mDX);
        break;
    case _moddi:
        usRet |= mDI;
        break;
    case _modsidi:
        usRet |= (mSI | mDI);
        break;
    case _modcx:
        usRet |= mCX;
        break;
    case _modes:
        /*usRet |= mES;*/
        break;
    case _modall:
        asmstate.bReturnax = true;
        return /*mES |*/ ALLREGS;
    case _modsiax:
        usRet |= (mSI | mAX);
        break;
    case _modsinot1:
        usRet |= mSI;
        opnds = [];
        break;
    case _modcxr11:
        usRet |= (mCX | mR11);
        break;
    case _modxmm0:
        usRet |= mXMM0;
        break;
    default:
        break;
    }
    if (opnds.length >= 1 && ASM_GET_aopty(opnds[0].usFlags) == _reg)
    {
        switch (ASM_GET_amod(opnds[0].usFlags))
        {
        default:
            usRet |= 1 << opnds[0].base.val;
            usRet &= ~(mBP | mSP);              // ignore changing these
            break;

        case _rseg:
            //if (popnd1.base.val == _ES)
                //usRet |= mES;
            break;

        case _rspecial:
            break;
        }
    }
    if (usRet & mAX)
        asmstate.bReturnax = true;

    return usRet;
}

/*******************************
 * Match flags in operand against flags in opcode table.
 * Returns:
 *      true if match
 */

bool asm_match_flags(opflag_t usOp, opflag_t usTable)
{
    ASM_OPERAND_TYPE    aoptyTable;
    ASM_OPERAND_TYPE    aoptyOp;
    ASM_MODIFIERS       amodTable;
    ASM_MODIFIERS       amodOp;
    uint                uRegmaskTable;
    uint                uRegmaskOp;
    ubyte               bRegmatch;
    bool                bRetval = false;
    uint                bSizematch;

    //printf("asm_match_flags(usOp = x%x, usTable = x%x)\n", usOp, usTable);
    //printf("usOp   : "); asm_output_flags(usOp   ); printf("\n");
    //printf("usTable: "); asm_output_flags(usTable); printf("\n");
    if (asmstate.ucItype == ITfloat)
    {
        return asm_match_float_flags(usOp, usTable);
    }

    const OpndSize uSizemaskOp = getOpndSize(usOp);
    const OpndSize uSizemaskTable = getOpndSize(usTable);

    // Check #1, if the sizes do not match, NO match
    bSizematch =  isOneOf(uSizemaskOp, uSizemaskTable);

    amodOp = ASM_GET_amod(usOp);

    aoptyTable = ASM_GET_aopty(usTable);
    aoptyOp = ASM_GET_aopty(usOp);

    // _mmm64 matches with a 64 bit mem or an MMX register
    if (usTable == _mmm64)
    {
        if (usOp == _mm)
            goto Lmatch;
        if (aoptyOp == _m && (bSizematch || uSizemaskOp == OpndSize._anysize))
            goto Lmatch;
        goto EXIT;
    }

    // _xmm_m32, _xmm_m64, _xmm_m128 match with XMM register or memory
    if (usTable == _xmm_m16 ||
        usTable == _xmm_m32 ||
        usTable == _xmm_m64 ||
        usTable == _xmm_m128)
    {
        if (usOp == _xmm || usOp == (_xmm|_xmm0))
            goto Lmatch;
        if (aoptyOp == _m && (bSizematch || uSizemaskOp == OpndSize._anysize))
            goto Lmatch;
    }

    if (usTable == _ymm_m256)
    {
        if (usOp == _ymm)
            goto Lmatch;
        if (aoptyOp == _m && (bSizematch || uSizemaskOp == OpndSize._anysize))
            goto Lmatch;
    }

    if (!bSizematch && uSizemaskTable)
    {
        //printf("no size match\n");
        goto EXIT;
    }


//
// The operand types must match, otherwise return false.
// There is one exception for the _rm which is a table entry which matches
// _reg or _m
//
    if (aoptyTable != aoptyOp)
    {
        if (aoptyTable == _rm && (aoptyOp == _reg ||
                                  aoptyOp == _m ||
                                  aoptyOp == _rel))
            goto Lok;
        if (aoptyTable == _mnoi && aoptyOp == _m &&
            (uSizemaskOp == OpndSize._32 && amodOp == _addr16 ||
             uSizemaskOp == OpndSize._48 && amodOp == _addr32 ||
             uSizemaskOp == OpndSize._48 && amodOp == _normal)
          )
            goto Lok;
        goto EXIT;
    }
Lok:

//
// Looks like a match so far, check to see if anything special is going on
//
    amodTable = ASM_GET_amod(usTable);
    uRegmaskOp = ASM_GET_uRegmask(usOp);
    uRegmaskTable = ASM_GET_uRegmask(usTable);
    bRegmatch = ((!uRegmaskTable && !uRegmaskOp) ||
                 (uRegmaskTable & uRegmaskOp));

    switch (amodTable)
    {
    case _normal:               // Normal's match with normals
        switch(amodOp)
        {
            case _normal:
            case _addr16:
            case _addr32:
            case _fn16:
            case _fn32:
            case _flbl:
                bRetval = (bSizematch || bRegmatch);
                goto EXIT;
            default:
                goto EXIT;
        }
    case _rseg:
    case _rspecial:
        bRetval = (amodOp == amodTable && bRegmatch);
        goto EXIT;
    default:
        assert(0);
    }
EXIT:
    version(none)
    {
        printf("OP : ");
        asm_output_flags(usOp);
        printf("\nTBL: ");
        asm_output_flags(usTable);
        printf(": %s\n", bRetval ? "MATCH" : "NOMATCH");
    }
    return bRetval;

Lmatch:
    //printf("match\n");
    return true;
}

/*******************************
 */

bool asm_match_float_flags(opflag_t usOp, opflag_t usTable)
{
    ASM_OPERAND_TYPE    aoptyTable;
    ASM_OPERAND_TYPE    aoptyOp;
    ASM_MODIFIERS       amodTable;
    ASM_MODIFIERS       amodOp;
    uint                uRegmaskTable;
    uint                uRegmaskOp;
    uint                bRegmatch;


//
// Check #1, if the sizes do not match, NO match
//
    uRegmaskOp = ASM_GET_uRegmask(usOp);
    uRegmaskTable = ASM_GET_uRegmask(usTable);
    bRegmatch = (uRegmaskTable & uRegmaskOp);

    if (!(isOneOf(getOpndSize(usOp), getOpndSize(usTable)) ||
          bRegmatch))
        return false;

    aoptyTable = ASM_GET_aopty(usTable);
    aoptyOp = ASM_GET_aopty(usOp);
//
// The operand types must match, otherwise return false.
// There is one exception for the _rm which is a table entry which matches
// _reg or _m
//
    if (aoptyTable != aoptyOp)
    {
        if (aoptyOp != _float)
            return false;
    }

//
// Looks like a match so far, check to see if anything special is going on
//
    amodOp = ASM_GET_amod(usOp);
    amodTable = ASM_GET_amod(usTable);
    switch (amodTable)
    {
        // Normal's match with normals
        case _normal:
            switch(amodOp)
            {
                case _normal:
                case _addr16:
                case _addr32:
                case _fn16:
                case _fn32:
                case _flbl:
                    return true;
                default:
                    return false;
            }
        case _rseg:
        case _rspecial:
            return false;
        default:
            assert(0);
    }
}


/*******************************
 */

//debug
 void asm_output_flags(opflag_t opflags)
{
    ASM_OPERAND_TYPE    aopty = ASM_GET_aopty(opflags);
    ASM_MODIFIERS       amod = ASM_GET_amod(opflags);
    uint                uRegmask = ASM_GET_uRegmask(opflags);
    const OpndSize      uSizemask = getOpndSize(opflags);

    const(char)* s;
    with (OpndSize)
    switch (uSizemask)
    {
        case none:        s = "none";        break;
        case _8:          s = "_8";          break;
        case _16:         s = "_16";         break;
        case _32:         s = "_32";         break;
        case _48:         s = "_48";         break;
        case _64:         s = "_64";         break;
        case _128:        s = "_128";        break;
        case _16_8:       s = "_16_8";       break;
        case _32_8:       s = "_32_8";       break;
        case _32_16:      s = "_32_16";      break;
        case _32_16_8:    s = "_32_16_8";    break;
        case _48_32:      s = "_48_32";      break;
        case _48_32_16_8: s = "_48_32_16_8"; break;
        case _64_32:      s = "_64_32";      break;
        case _64_32_8:    s = "_64_32_8";    break;
        case _64_32_16:   s = "_64_32_16";   break;
        case _64_32_16_8: s = "_64_32_16_8"; break;
        case _64_48_32_16_8: s = "_64_48_32_16_8"; break;
        case _anysize:    s = "_anysize";    break;

        default:
            printf("uSizemask = x%x\n", uSizemask);
            assert(0);
    }
    printf("%s ", s);

    printf("_");
    switch (aopty)
    {
        case _reg:
            printf("reg   ");
            break;
        case _m:
            printf("m     ");
            break;
        case _imm:
            printf("imm   ");
            break;
        case _rel:
            printf("rel   ");
            break;
        case _mnoi:
            printf("mnoi  ");
            break;
        case _p:
            printf("p     ");
            break;
        case _rm:
            printf("rm    ");
            break;
        case _float:
            printf("float ");
            break;
        default:
            printf(" UNKNOWN ");
    }

    printf("_");
    switch (amod)
    {
        case _normal:
            printf("normal   ");
            if (uRegmask & 1) printf("_al ");
            if (uRegmask & 2) printf("_ax ");
            if (uRegmask & 4) printf("_eax ");
            if (uRegmask & 8) printf("_dx ");
            if (uRegmask & 0x10) printf("_cl ");
            if (uRegmask & 0x40) printf("_rax ");
            if (uRegmask & 0x20) printf("_rplus_r ");
            return;
        case _rseg:
            printf("rseg     ");
            break;
        case _rspecial:
            printf("rspecial ");
            break;
        case _addr16:
            printf("addr16   ");
            break;
        case _addr32:
            printf("addr32   ");
            break;
        case _fn16:
            printf("fn16     ");
            break;
        case _fn32:
            printf("fn32     ");
            break;
        case _flbl:
            printf("flbl     ");
            break;
        default:
            printf("UNKNOWN  ");
            break;
    }
    printf("uRegmask=x%02x", uRegmask);

}

/*******************************
 */

//debug
 void asm_output_popnd(const ref OPND popnd)
{
    if (popnd.segreg)
            printf("%s:", popnd.segreg.regstr.ptr);

    if (popnd.s)
            printf("%s", popnd.s.ident.toChars());

    if (popnd.base)
            printf("%s", popnd.base.regstr.ptr);
    if (popnd.pregDisp1)
    {
        if (popnd.pregDisp2)
        {
            if (popnd.usFlags & _a32)
            {
                if (popnd.uchMultiplier)
                    printf("[%s][%s*%d]",
                            popnd.pregDisp1.regstr.ptr,
                            popnd.pregDisp2.regstr.ptr,
                            popnd.uchMultiplier);
                else
                    printf("[%s][%s]",
                            popnd.pregDisp1.regstr.ptr,
                            popnd.pregDisp2.regstr.ptr);
            }
            else
                printf("[%s+%s]",
                        popnd.pregDisp1.regstr.ptr,
                        popnd.pregDisp2.regstr.ptr);
        }
        else
        {
            if (popnd.uchMultiplier)
                printf("[%s*%d]",
                        popnd.pregDisp1.regstr.ptr,
                        popnd.uchMultiplier);
            else
                printf("[%s]",
                        popnd.pregDisp1.regstr.ptr);
        }
    }
    if (ASM_GET_aopty(popnd.usFlags) == _imm)
            printf("%llxh", cast(long)popnd.disp);
    else if (popnd.disp)
            printf("+%llxh", cast(long)popnd.disp);
}

void printOperands(OP* pop, scope OPND[] opnds)
{
    printf("\t%s\t", asm_opstr(pop));
    foreach (i, ref  opnd; opnds)
    {
        asm_output_popnd(opnd);
        if (i != opnds.length - 1)
            printf(",");
    }
    printf("\n");
}



/*******************************
 */

immutable(REG)* asm_reg_lookup(const(char)[] s)
{
    //dbg_printf("asm_reg_lookup('%s')\n",s);

    for (int i = 0; i < regtab.length; i++)
    {
        if (s == regtab[i].regstr)
        {
            return &regtab[i];
        }
    }
    if (target.is64bit)
    {
        for (int i = 0; i < regtab64.length; i++)
        {
            if (s == regtab64[i].regstr)
            {
                return &regtab64[i];
            }
        }
    }
    return null;
}


/*******************************
 */

void asm_token()
{
    if (asmstate.tok)
        asmstate.tok = asmstate.tok.next;
    asm_token_trans(asmstate.tok);
}

/*******************************
 */

void asm_token_trans(Token *tok)
{
    asmstate.tokValue = TOK.endOfFile;
    if (tok)
    {
        asmstate.tokValue = tok.value;
        if (asmstate.tokValue == TOK.identifier)
        {
            const id = tok.ident.toString();
            if (id.length < 20)
            {
                ASMTK asmtk = cast(ASMTK) binary(id.ptr, cast(const(char)**)apszAsmtk.ptr, ASMTKmax);
                if (cast(int)asmtk >= 0)
                    asmstate.tokValue = cast(TOK) (asmtk + ASMTKlocalsize);
            }
        }
    }
}

/*******************************
 */

OpndSize asm_type_size(Type ptype, bool bPtr)
{
    OpndSize u;

    //if (ptype) printf("asm_type_size('%s') = %d\n", ptype.toChars(), (int)ptype.size());
    u = OpndSize._anysize;
    if (ptype && ptype.ty != Tfunction /*&& ptype.isscalar()*/)
    {
        switch (cast(int)ptype.size())
        {
            case 0:     asmerr("bad type/size of operands `%s`", "0 size".ptr);    break;
            case 1:     u = OpndSize._8;         break;
            case 2:     u = OpndSize._16;        break;
            case 4:     u = OpndSize._32;        break;
            case 6:     u = OpndSize._48;        break;

            case 8:     if (target.is64bit || bPtr)
                            u = OpndSize._64;
                        break;

            case 16:    u = OpndSize._128;       break;
            default:    break;
        }
    }
    return u;
}

/*******************************
 *      start of inline assemblers expression parser
 *      NOTE: functions in call order instead of alphabetical
 */

/*******************************************
 * Parse DA expression
 *
 * Very limited define address to place a code
 * address in the assembly
 * Problems:
 *      o       Should use dw offset and dd offset instead,
 *              for near/far support.
 *      o       Should be able to add an offset to the label address.
 *      o       Blocks addressed by DA should get their Bpred set correctly
 *              for optimizer.
 */

code *asm_da_parse(OP *pop)
{
    CodeBuilder cdb;
    cdb.ctor();
    while (1)
    {
        if (asmstate.tokValue == TOK.identifier)
        {
            LabelDsymbol label = asmstate.sc.func.searchLabel(asmstate.tok.ident, asmstate.loc);
            if (!label)
            {
                asmerr("label `%s` not found", asmstate.tok.ident.toChars());
                break;
            }
            else
                label.iasm = true;

            if (global.params.symdebug)
                cdb.genlinnum(Srcpos.create(asmstate.loc.filename, asmstate.loc.linnum, asmstate.loc.charnum));
            cdb.genasm(cast(_LabelDsymbol*)label);
        }
        else
        {
            asmerr("label expected as argument to DA pseudo-op"); // illegal addressing mode
            break;
        }
        asm_token();
        if (asmstate.tokValue != TOK.comma)
            break;
        asm_token();
    }

    asmstate.statement.regs |= mES|ALLREGS;
    asmstate.bReturnax = true;

    return cdb.finish();
}

/*******************************************
 * Parse DB, DW, DD, DQ and DT expressions.
 */

code *asm_db_parse(OP *pop)
{
    union DT
    {
        targ_ullong ul;
        targ_float f;
        targ_double d;
        targ_ldouble ld;
        byte[10] value;
    }
    DT dt;

    static const ubyte[7] opsize = [ 1,2,4,8,4,8,10 ];

    uint op = pop.usNumops & ITSIZE;
    size_t usSize = opsize[op];

    OutBuffer bytes;

    while (1)
    {
        void writeBytes(const char[] array)
        {
            if (usSize == 1)
                bytes.write(array);
            else
            {
                foreach (b; array)
                {
                    switch (usSize)
                    {
                        case 2: bytes.writeword(b); break;
                        case 4: bytes.write4(b);    break;
                        default:
                            asmerr("floating point expected");
                            break;
                    }
                }
            }
        }

        switch (asmstate.tokValue)
        {
            case TOK.int32Literal:
                dt.ul = cast(d_int32)asmstate.tok.intvalue;
                goto L1;
            case TOK.uns32Literal:
                dt.ul = cast(d_uns32)asmstate.tok.unsvalue;
                goto L1;
            case TOK.int64Literal:
                dt.ul = asmstate.tok.intvalue;
                goto L1;
            case TOK.uns64Literal:
                dt.ul = asmstate.tok.unsvalue;
                goto L1;
            L1:
                switch (op)
                {
                    case OPdb:
                    case OPds:
                    case OPdi:
                    case OPdl:
                        break;
                    default:
                        asmerr("floating point expected");
                }
                goto L2;

            case TOK.float32Literal:
            case TOK.float64Literal:
            case TOK.float80Literal:
                switch (op)
                {
                    case OPdf:
                        dt.f = cast(float) asmstate.tok.floatvalue;
                        break;
                    case OPdd:
                        dt.d = cast(double) asmstate.tok.floatvalue;
                        break;
                    case OPde:
                        dt.ld = asmstate.tok.floatvalue;
                        break;
                    default:
                        asmerr("integer expected");
                }
                goto L2;

            L2:
                bytes.write((cast(void*)&dt)[0 .. usSize]);
                break;

            case TOK.string_:
                writeBytes(asmstate.tok.ustring[0 .. asmstate.tok.len]);
                break;

            case TOK.identifier:
            {
                Expression e = IdentifierExp.create(asmstate.loc, asmstate.tok.ident);
                Scope *sc = asmstate.sc.startCTFE();
                e = e.expressionSemantic(sc);
                sc.endCTFE();
                e = e.ctfeInterpret();
                if (e.op == TOK.int64)
                {
                    dt.ul = e.toInteger();
                    goto L2;
                }
                else if (e.op == TOK.float64)
                {
                    switch (op)
                    {
                        case OPdf:
                            dt.f = cast(float) e.toReal();
                            break;
                        case OPdd:
                            dt.d = cast(double) e.toReal();
                            break;
                        case OPde:
                            dt.ld = e.toReal();
                            break;
                        default:
                            asmerr("integer expected");
                    }
                    goto L2;
                }
                else if (auto se = e.isStringExp())
                {
                    const len = se.numberOfCodeUnits();
                    auto q = cast(char *)se.peekString().ptr;
                    if (q)
                    {
                        writeBytes(q[0 .. len]);
                    }
                    else
                    {
                        auto qstart = cast(char *)mem.xmalloc(len * se.sz);
                        se.writeTo(qstart, false);
                        writeBytes(qstart[0 .. len]);
                        mem.xfree(qstart);
                    }
                    break;
                }
                goto default;
            }

            default:
                asmerr("constant initializer expected");          // constant initializer
                break;
        }

        asm_token();
        if (asmstate.tokValue != TOK.comma ||
            asmstate.errors)
            break;
        asm_token();
    }

    CodeBuilder cdb;
    cdb.ctor();
    if (global.params.symdebug)
        cdb.genlinnum(Srcpos.create(asmstate.loc.filename, asmstate.loc.linnum, asmstate.loc.charnum));
    cdb.genasm(bytes.peekChars(), cast(uint)bytes.length);
    code *c = cdb.finish();

    asmstate.statement.regs |= /* mES| */ ALLREGS;
    asmstate.bReturnax = true;

    return c;
}

/**********************************
 * Parse and get integer expression.
 */

int asm_getnum()
{
    int v;
    dinteger_t i;

    switch (asmstate.tokValue)
    {
        case TOK.int32Literal:
            v = cast(d_int32)asmstate.tok.intvalue;
            break;

        case TOK.uns32Literal:
            v = cast(d_uns32)asmstate.tok.unsvalue;
            break;

        case TOK.identifier:
        {
            Expression e = IdentifierExp.create(asmstate.loc, asmstate.tok.ident);
            Scope *sc = asmstate.sc.startCTFE();
            e = e.expressionSemantic(sc);
            sc.endCTFE();
            e = e.ctfeInterpret();
            i = e.toInteger();
            v = cast(int) i;
            if (v != i)
                asmerr("integer expected");
            break;
        }
        default:
            asmerr("integer expected");
            v = 0;              // no uninitialized values
            break;
    }
    asm_token();
    return v;
}

/*******************************
 */

void asm_cond_exp(out OPND o1)
{
    //printf("asm_cond_exp()\n");
    asm_log_or_exp(o1);
    if (asmstate.tokValue == TOK.question)
    {
        asm_token();
        OPND o2;
        asm_cond_exp(o2);
        asm_chktok(TOK.colon,"colon");
        OPND o3;
        asm_cond_exp(o3);
        if (o1.disp)
            o1 = o2;
        else
            o1 = o3;
    }
}

/*******************************
 */

void asm_log_or_exp(out OPND o1)
{
    asm_log_and_exp(o1);
    while (asmstate.tokValue == TOK.orOr)
    {
        asm_token();
        OPND o2;
        asm_log_and_exp(o2);
        if (asm_isint(o1) && asm_isint(o2))
            o1.disp = o1.disp || o2.disp;
        else
            asmerr("bad integral operand");
        o1.disp = 0;
        asm_merge_opnds(o1, o2);
    }
}

/*******************************
 */

void asm_log_and_exp(out OPND o1)
{
    asm_inc_or_exp(o1);
    while (asmstate.tokValue == TOK.andAnd)
    {
        asm_token();
        OPND o2;
        asm_inc_or_exp(o2);
        if (asm_isint(o1) && asm_isint(o2))
            o1.disp = o1.disp && o2.disp;
        else
            asmerr("bad integral operand");
        o2.disp = 0;
        asm_merge_opnds(o1, o2);
    }
}

/*******************************
 */

void asm_inc_or_exp(out OPND o1)
{
    asm_xor_exp(o1);
    while (asmstate.tokValue == TOK.or)
    {
        asm_token();
        OPND o2;
        asm_xor_exp(o2);
        if (asm_isint(o1) && asm_isint(o2))
            o1.disp |= o2.disp;
        else
            asmerr("bad integral operand");
        o2.disp = 0;
        asm_merge_opnds(o1, o2);
    }
}

/*******************************
 */

void asm_xor_exp(out OPND o1)
{
    asm_and_exp(o1);
    while (asmstate.tokValue == TOK.xor)
    {
        asm_token();
        OPND o2;
        asm_and_exp(o2);
        if (asm_isint(o1) && asm_isint(o2))
            o1.disp ^= o2.disp;
        else
            asmerr("bad integral operand");
        o2.disp = 0;
        asm_merge_opnds(o1, o2);
    }
}

/*******************************
 */

void asm_and_exp(out OPND o1)
{
    asm_equal_exp(o1);
    while (asmstate.tokValue == TOK.and)
    {
        asm_token();
        OPND o2;
        asm_equal_exp(o2);
        if (asm_isint(o1) && asm_isint(o2))
            o1.disp &= o2.disp;
        else
            asmerr("bad integral operand");
        o2.disp = 0;
        asm_merge_opnds(o1, o2);
    }
}

/*******************************
 */

void asm_equal_exp(out OPND o1)
{
    asm_rel_exp(o1);
    while (1)
    {
        switch (asmstate.tokValue)
        {
            case TOK.equal:
            {
                asm_token();
                OPND o2;
                asm_rel_exp(o2);
                if (asm_isint(o1) && asm_isint(o2))
                    o1.disp = o1.disp == o2.disp;
                else
                    asmerr("bad integral operand");
                o2.disp = 0;
                asm_merge_opnds(o1, o2);
                break;
            }

            case TOK.notEqual:
            {
                asm_token();
                OPND o2;
                asm_rel_exp(o2);
                if (asm_isint(o1) && asm_isint(o2))
                    o1.disp = o1.disp != o2.disp;
                else
                    asmerr("bad integral operand");
                o2.disp = 0;
                asm_merge_opnds(o1, o2);
                break;
            }

            default:
                return;
        }
    }
}

/*******************************
 */

void asm_rel_exp(out OPND o1)
{
    asm_shift_exp(o1);
    while (1)
    {
        switch (asmstate.tokValue)
        {
            case TOK.greaterThan:
            case TOK.greaterOrEqual:
            case TOK.lessThan:
            case TOK.lessOrEqual:
                auto tok_save = asmstate.tokValue;
                asm_token();
                OPND o2;
                asm_shift_exp(o2);
                if (asm_isint(o1) && asm_isint(o2))
                {
                    switch (tok_save)
                    {
                        case TOK.greaterThan:
                            o1.disp = o1.disp > o2.disp;
                            break;
                        case TOK.greaterOrEqual:
                            o1.disp = o1.disp >= o2.disp;
                            break;
                        case TOK.lessThan:
                            o1.disp = o1.disp < o2.disp;
                            break;
                        case TOK.lessOrEqual:
                            o1.disp = o1.disp <= o2.disp;
                            break;
                        default:
                            assert(0);
                    }
                }
                else
                    asmerr("bad integral operand");
                o2.disp = 0;
                asm_merge_opnds(o1, o2);
                break;

            default:
                return;
        }
    }
}

/*******************************
 */

void asm_shift_exp(out OPND o1)
{
    asm_add_exp(o1);
    while (asmstate.tokValue == TOK.leftShift || asmstate.tokValue == TOK.rightShift || asmstate.tokValue == TOK.unsignedRightShift)
    {
        auto tk = asmstate.tokValue;
        asm_token();
        OPND o2;
        asm_add_exp(o2);
        if (asm_isint(o1) && asm_isint(o2))
        {
            if (tk == TOK.leftShift)
                o1.disp <<= o2.disp;
            else if (tk == TOK.unsignedRightShift)
                o1.disp = cast(uint)o1.disp >> o2.disp;
            else
                o1.disp >>= o2.disp;
        }
        else
            asmerr("bad integral operand");
        o2.disp = 0;
        asm_merge_opnds(o1, o2);
    }
}

/*******************************
 */

void asm_add_exp(out OPND o1)
{
    asm_mul_exp(o1);
    while (1)
    {
        switch (asmstate.tokValue)
        {
            case TOK.add:
            {
                asm_token();
                OPND o2;
                asm_mul_exp(o2);
                asm_merge_opnds(o1, o2);
                break;
            }

            case TOK.min:
            {
                asm_token();
                OPND o2;
                asm_mul_exp(o2);
                if (o2.base || o2.pregDisp1 || o2.pregDisp2)
                    asmerr("cannot subtract register");
                if (asm_isint(o1) && asm_isint(o2))
                {
                    o1.disp -= o2.disp;
                    o2.disp = 0;
                }
                else
                    o2.disp = - o2.disp;
                asm_merge_opnds(o1, o2);
                break;
            }

            default:
                return;
        }
    }
}

/*******************************
 */

void asm_mul_exp(out OPND o1)
{
    //printf("+asm_mul_exp()\n");
    asm_br_exp(o1);
    while (1)
    {
        switch (asmstate.tokValue)
        {
            case TOK.mul:
            {
                asm_token();
                OPND o2;
                asm_br_exp(o2);
                debug (EXTRA_DEBUG) printf("Star  o1.isint=%d, o2.isint=%d, lbra_seen=%d\n",
                    asm_isint(o1), asm_isint(o2), asmstate.lbracketNestCount );
                if (asm_isNonZeroInt(o1) && asm_isNonZeroInt(o2))
                    o1.disp *= o2.disp;
                else if (asmstate.lbracketNestCount && o1.pregDisp1 && asm_isNonZeroInt(o2))
                {
                    o1.uchMultiplier = cast(uint)o2.disp;
                    debug (EXTRA_DEBUG) printf("Multiplier: %d\n", o1.uchMultiplier);
                }
                else if (asmstate.lbracketNestCount && o2.pregDisp1 && asm_isNonZeroInt(o1))
                {
                    OPND popndTmp = o2;
                    o2 = o1;
                    o1 = popndTmp;
                    o1.uchMultiplier = cast(uint)o2.disp;
                    debug (EXTRA_DEBUG) printf("Multiplier: %d\n",
                        o1.uchMultiplier);
                }
                else if (asm_isint(o1) && asm_isint(o2))
                    o1.disp *= o2.disp;
                else
                    asmerr("bad operand");
                o2.disp = 0;
                asm_merge_opnds(o1, o2);
                break;
            }

            case TOK.div:
            {
                asm_token();
                OPND o2;
                asm_br_exp(o2);
                if (asm_isint(o1) && asm_isint(o2))
                    o1.disp /= o2.disp;
                else
                    asmerr("bad integral operand");
                o2.disp = 0;
                asm_merge_opnds(o1, o2);
                break;
            }

            case TOK.mod:
            {
                asm_token();
                OPND o2;
                asm_br_exp(o2);
                if (asm_isint(o1) && asm_isint(o2))
                    o1.disp %= o2.disp;
                else
                    asmerr("bad integral operand");
                o2.disp = 0;
                asm_merge_opnds(o1, o2);
                break;
            }

            default:
                return;
        }
    }
}

/*******************************
 */

void asm_br_exp(out OPND o1)
{
    //printf("asm_br_exp()\n");
    if (asmstate.tokValue != TOK.leftBracket)
        asm_una_exp(o1);
    while (1)
    {
        switch (asmstate.tokValue)
        {
            case TOK.leftBracket:
            {
                debug (EXTRA_DEBUG) printf("Saw a left bracket\n");
                asm_token();
                asmstate.lbracketNestCount++;
                OPND o2;
                asm_cond_exp(o2);
                asmstate.lbracketNestCount--;
                asm_chktok(TOK.rightBracket,"`]` expected instead of `%s`");
                debug (EXTRA_DEBUG) printf("Saw a right bracket\n");
                asm_merge_opnds(o1, o2);
                if (asmstate.tokValue == TOK.identifier)
                {
                    asm_una_exp(o2);
                    asm_merge_opnds(o1, o2);
                }
                break;
            }
            default:
                return;
        }
    }
}

/*******************************
 */

void asm_una_exp(ref OPND o1)
{
    Type ptype;

    static void type_ref(ref OPND o1, Type ptype)
    {
        asm_token();
        // try: <BasicType>.<min/max etc>
        if (asmstate.tokValue == TOK.dot)
        {
            asm_token();
            if (asmstate.tokValue == TOK.identifier)
            {
                TypeExp te = new TypeExp(asmstate.loc, ptype);
                DotIdExp did = new DotIdExp(asmstate.loc, te, asmstate.tok.ident);
                Dsymbol s;
                tryExpressionToOperand(did, o1, s);
            }
            else
            {
                asmerr("property of basic type `%s` expected", ptype.toChars());
            }
            asm_token();
            return;
        }
        // else: ptr <BasicType>
        asm_chktok(cast(TOK) ASMTKptr, "ptr expected");
        asm_cond_exp(o1);
        o1.ptype = ptype;
        o1.bPtr = true;
    }

    static void jump_ref(ref OPND o1, ASM_JUMPTYPE ajt, bool readPtr)
    {
        if (readPtr)
        {
            asm_token();
            asm_chktok(cast(TOK) ASMTKptr, "ptr expected".ptr);
        }
        asm_cond_exp(o1);
        o1.ajt = ajt;
    }

    switch (cast(int)asmstate.tokValue)
    {
        case TOK.add:
            asm_token();
            asm_una_exp(o1);
            break;

        case TOK.min:
            asm_token();
            asm_una_exp(o1);
            if (o1.base || o1.pregDisp1 || o1.pregDisp2)
                asmerr("cannot negate register");
            if (asm_isint(o1))
                o1.disp = -o1.disp;
            break;

        case TOK.not:
            asm_token();
            asm_una_exp(o1);
            if (asm_isint(o1))
                o1.disp = !o1.disp;
            break;

        case TOK.tilde:
            asm_token();
            asm_una_exp(o1);
            if (asm_isint(o1))
                o1.disp = ~o1.disp;
            break;

version (none)
{
        case TOK.leftParenthesis:
            // stoken() is called directly here because we really
            // want the INT token to be an INT.
            stoken();
            if (type_specifier(&ptypeSpec)) /* if type_name     */
            {

                ptype = declar_abstract(ptypeSpec);
                            /* read abstract_declarator  */
                fixdeclar(ptype);/* fix declarator               */
                type_free(ptypeSpec);/* the declar() function
                                    allocates the typespec again */
                chktok(TOK.rightParenthesis,"`)` expected instead of `%s`");
                ptype.Tcount--;
                goto CAST_REF;
            }
            else
            {
                type_free(ptypeSpec);
                asm_cond_exp(o1);
                chktok(TOK.rightParenthesis, "`)` expected instead of `%s`");
            }
            break;
}

        case TOK.identifier:
            // Check for offset keyword
            if (asmstate.tok.ident == Id.offset)
            {
                asmerr("use offsetof instead of offset");
                goto Loffset;
            }
            if (asmstate.tok.ident == Id.offsetof)
            {
            Loffset:
                asm_token();
                asm_cond_exp(o1);
                o1.bOffset = true;
            }
            else
                asm_primary_exp(o1);
            break;

        case ASMTKseg:
            asm_token();
            asm_cond_exp(o1);
            o1.bSeg = true;
            break;

        case TOK.int16:
            if (asmstate.ucItype != ITjump)
            {
                return type_ref(o1, Type.tint16);
            }
            asm_token();
            return jump_ref(o1, ASM_JUMPTYPE_SHORT, false);

        case ASMTKnear:
            return jump_ref(o1, ASM_JUMPTYPE_NEAR, true);

        case ASMTKfar:
            return jump_ref(o1, ASM_JUMPTYPE_FAR, true);

        case TOK.void_:
            return type_ref(o1, Type.tvoid);

        case TOK.bool_:
            return type_ref(o1, Type.tbool);

        case TOK.char_:
            return type_ref(o1, Type.tchar);
        case TOK.wchar_:
            return type_ref(o1, Type.twchar);
        case TOK.dchar_:
            return type_ref(o1, Type.tdchar);
        case TOK.uns8:
            return type_ref(o1, Type.tuns8);
        case TOK.uns16:
            return type_ref(o1, Type.tuns16);
        case TOK.uns32:
            return type_ref(o1, Type.tuns32);
        case TOK.uns64 :
            return type_ref(o1, Type.tuns64);

        case TOK.int8:
            return type_ref(o1, Type.tint8);
        case ASMTKword:
            return type_ref(o1, Type.tint16);
        case TOK.int32:
        case ASMTKdword:
            return type_ref(o1, Type.tint32);
        case TOK.int64:
        case ASMTKqword:
            return type_ref(o1, Type.tint64);

        case TOK.float32:
            return type_ref(o1, Type.tfloat32);
        case TOK.float64:
            return type_ref(o1, Type.tfloat64);
        case TOK.float80:
            return type_ref(o1, Type.tfloat80);

        default:
            asm_primary_exp(o1);
            break;
    }
}

/*******************************
 */

void asm_primary_exp(out OPND o1)
{
    switch (asmstate.tokValue)
    {
        case TOK.dollar:
            o1.s = asmstate.psDollar;
            asm_token();
            break;

        case TOK.this_:
        case TOK.identifier:
            const regp = asm_reg_lookup(asmstate.tok.ident.toString());
            if (regp != null)
            {
                asm_token();
                // see if it is segment override (like SS:)
                if (!asmstate.lbracketNestCount &&
                        (regp.ty & _seg) &&
                        asmstate.tokValue == TOK.colon)
                {
                    o1.segreg = regp;
                    asm_token();
                    OPND o2;
                    asm_cond_exp(o2);
                    if (o2.s && o2.s.isLabel())
                        o2.segreg = null; // The segment register was specified explicitly.
                    asm_merge_opnds(o1, o2);
                }
                else if (asmstate.lbracketNestCount)
                {
                    // should be a register
                    if (regp.val == _RIP)
                        o1.bRIP = true;
                    else if (o1.pregDisp1)
                        asmerr("bad operand");
                    else
                        o1.pregDisp1 = regp;
                }
                else
                {
                    if (o1.base == null)
                        o1.base = regp;
                    else
                        asmerr("bad operand");
                }
                break;
            }
            // If floating point instruction and id is a floating register
            else if (asmstate.ucItype == ITfloat &&
                     asm_is_fpreg(asmstate.tok.ident.toString()))
            {
                asm_token();
                if (asmstate.tokValue == TOK.leftParenthesis)
                {
                    asm_token();
                    if (asmstate.tokValue == TOK.int32Literal)
                    {
                        uint n = cast(uint)asmstate.tok.unsvalue;
                        if (n > 7)
                            asmerr("bad operand");
                        else
                            o1.base = &(aregFp[n]);
                    }
                    asm_chktok(TOK.int32Literal, "integer expected");
                    asm_chktok(TOK.rightParenthesis, "`)` expected instead of `%s`");
                }
                else
                    o1.base = &regFp;
            }
            else
            {
                Dsymbol s;
                if (asmstate.sc.func.labtab)
                    s = asmstate.sc.func.labtab.lookup(asmstate.tok.ident);
                if (!s)
                    s = asmstate.sc.search(Loc.initial, asmstate.tok.ident, null);
                if (!s)
                {
                    // Assume it is a label, and define that label
                    s = asmstate.sc.func.searchLabel(asmstate.tok.ident, asmstate.loc);
                }
                if (auto label = s.isLabel())
                {
                    // Use the following for non-FLAT memory models
                    //o1.segreg = &regtab[25]; // use CS as a base for a label

                    label.iasm = true;
                }
                Identifier id = asmstate.tok.ident;
                asm_token();
                if (asmstate.tokValue == TOK.dot)
                {
                    Expression e = IdentifierExp.create(asmstate.loc, id);
                    while (1)
                    {
                        asm_token();
                        if (asmstate.tokValue == TOK.identifier)
                        {
                            e = DotIdExp.create(asmstate.loc, e, asmstate.tok.ident);
                            asm_token();
                            if (asmstate.tokValue != TOK.dot)
                                break;
                        }
                        else
                        {
                            asmerr("identifier expected");
                            break;
                        }
                    }
                    TOK e2o = tryExpressionToOperand(e, o1, s);
                    if (e2o == TOK.error)
                        return;
                    if (e2o == TOK.const_)
                        goto Lpost;
                }

                asm_merge_symbol(o1,s);

                /* This attempts to answer the question: is
                 *  char[8] foo;
                 * of size 1 or size 8? Presume it is 8 if foo
                 * is the last token of the operand.
                 * Note that this can be turned on and off by the user by
                 * adding a constant:
                 *   align(16) uint[4][2] constants =
                 *   [ [0,0,0,0],[0,0,0,0] ];
                 *   asm {
                 *      movdqa XMM1,constants;   // operand treated as size 32
                 *      movdqa XMM1,constants+0; // operand treated as size 16
                 *   }
                 * This is an inexcusable hack, but can't
                 * fix it due to backward compatibility.
                 */
                if (o1.ptype && asmstate.tokValue != TOK.comma && asmstate.tokValue != TOK.endOfFile)
                {
                    // Peel off only one layer of the array
                    if (o1.ptype.ty == Tsarray)
                        o1.ptype = o1.ptype.nextOf();
                }

            Lpost:
                // for []
                //if (asmstate.tokValue == TOK.leftBracket)
                        //o1 = asm_prim_post(o1);
                return;
            }
            break;

        case TOK.int32Literal:
            o1.disp = cast(d_int32)asmstate.tok.intvalue;
            asm_token();
            break;

        case TOK.uns32Literal:
            o1.disp = cast(d_uns32)asmstate.tok.unsvalue;
            asm_token();
            break;

        case TOK.int64Literal:
        case TOK.uns64Literal:
            o1.disp = asmstate.tok.intvalue;
            asm_token();
            break;

        case TOK.float32Literal:
            o1.vreal = asmstate.tok.floatvalue;
            o1.ptype = Type.tfloat32;
            asm_token();
            break;

        case TOK.float64Literal:
            o1.vreal = asmstate.tok.floatvalue;
            o1.ptype = Type.tfloat64;
            asm_token();
            break;

        case TOK.float80Literal:
            o1.vreal = asmstate.tok.floatvalue;
            o1.ptype = Type.tfloat80;
            asm_token();
            break;

        case cast(TOK)ASMTKlocalsize:
            o1.s = asmstate.psLocalsize;
            o1.ptype = Type.tint32;
            asm_token();
            break;

         default:
            asmerr("expression expected not `%s`", asmstate.tok ? asmstate.tok.toChars() : ";");
            break;
    }
}

/**
 * Using an expression, try to set an ASM operand as a constant or as an access
 * to a higher level variable.
 *
 * Params:
 *      e =     Input. The expression to evaluate. This can be an arbitrarily complex expression
 *              but it must either represent a constant after CTFE or give a higher level variable.
 *      o1 =    if `e` turns out to be a constant, `o1` is set to reflect that
 *      s =     if `e` turns out to be a variable, `s` is set to reflect that
 *
 * Returns:
 *      `TOK.variable` if `s` was set to a variable,
 *      `TOK.const_` if `e` was evaluated to a valid constant,
 *      `TOK.error` otherwise.
 */
TOK tryExpressionToOperand(Expression e, out OPND o1, out Dsymbol s)
{
    Scope *sc = asmstate.sc.startCTFE();
    e = e.expressionSemantic(sc);
    sc.endCTFE();
    e = e.ctfeInterpret();
    if (auto ve = e.isVarExp())
    {
        s = ve.var;
        return TOK.variable;
    }
    if (e.isConst())
    {
        if (e.type.isintegral())
        {
            o1.disp = e.toInteger();
            return TOK.const_;
        }
        if (e.type.isreal())
        {
            o1.vreal = e.toReal();
            o1.ptype = e.type;
            return TOK.const_;
        }
    }
    asmerr("bad type/size of operands `%s`", e.toChars());
    return TOK.error;
}

/**********************
 * If c is a power of 2, return that power else -1.
 */

private int ispow2(uint c)
{
    int i;

    if (c == 0 || (c & (c - 1)))
        i = -1;
    else
        for (i = 0; c >>= 1; ++i)
        { }
    return i;
}


/*************************************
 * Returns: true if szop is one of the values in sztbl
 */
private
bool isOneOf(OpndSize szop, OpndSize sztbl)
{
    with (OpndSize)
    {
        immutable ubyte[OpndSize.max + 1] maskx =
        [
            none        : 0,

            _8          : 1,
            _16         : 2,
            _32         : 4,
            _48         : 8,
            _64         : 16,
            _128        : 32,

            _16_8       : 2  | 1,
            _32_8       : 4  | 1,
            _32_16      : 4  | 2,
            _32_16_8    : 4  | 2 | 1,
            _48_32      : 8  | 4,
            _48_32_16_8 : 8  | 4  | 2 | 1,
            _64_32      : 16 | 4,
            _64_32_8    : 16 | 4 | 1,
            _64_32_16   : 16 | 4 | 2,
            _64_32_16_8 : 16 | 4 | 2 | 1,
            _64_48_32_16_8 : 16 | 8 | 4 | 2 | 1,

            _anysize    : 32 | 16 | 8 | 4 | 2 | 1,
        ];

        return (maskx[szop] & maskx[sztbl]) != 0;
    }
}

unittest
{
    with (OpndSize)
    {
        assert( isOneOf(_8, _8));
        assert(!isOneOf(_8, _16));
        assert( isOneOf(_8, _16_8));
        assert( isOneOf(_8, _32_8));
        assert(!isOneOf(_8, _32_16));
        assert( isOneOf(_8, _32_16_8));
        assert(!isOneOf(_8, _64_32));
        assert( isOneOf(_8, _64_32_8));
        assert(!isOneOf(_8, _64_32_16));
        assert( isOneOf(_8, _64_32_16_8));
        assert( isOneOf(_8, _anysize));
    }
}
