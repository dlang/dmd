/**
 * Define registers, register masks, and the CPU instruction linked list
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/code.d, backend/_code.d)
 */

module dmd.backend.code;

// Online documentation: https://dlang.org/phobos/dmd_backend_code.html

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code_x86;
import dmd.backend.codebuilder : CodeBuilder;
import dmd.backend.el : elem;
import dmd.backend.oper : OPMAX;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.common.outbuffer;


nothrow:
@safe:

alias segidx_t = int;           // index into SegData[]

/**********************************
 * Code data type
 */

struct _Declaration;
struct _LabelDsymbol;

union evc
{
    targ_int    Vint;           /// also used for tmp numbers (FLtmp)
    targ_uns    Vuns;
    targ_long   Vlong;
    targ_llong  Vllong;
    targ_size_t Vsize_t;
    struct
    {
        targ_size_t Vpointer;
        int Vseg;               /// segment the pointer is in
    }
    Srcpos      Vsrcpos;        /// source position for OPlinnum
    elem       *Vtor;           /// OPctor/OPdtor elem
    block      *Vswitch;        /// when FLswitch and we have a switch table
    code       *Vcode;          /// when code is target of a jump (FLcode)
    block      *Vblock;         /// when block " (FLblock)
    struct
    {
        targ_size_t Voffset;    /// offset from symbol
        Symbol  *Vsym;          /// pointer to symbol table (FLfunc,FLextern)
    }

    struct
    {
        targ_size_t Vdoffset;   /// offset from symbol
        _Declaration *Vdsym;    /// pointer to D symbol table
    }

    struct
    {
        targ_size_t Vloffset;   /// offset from symbol
        _LabelDsymbol *Vlsym;   /// pointer to D Label
    }

    struct
    {
        size_t len;
        char *bytes;
    }                           // asm node (FLasm)
}

/********************** PUBLIC FUNCTIONS *******************/

public import dmd.backend.dcode : code_calloc, code_free, code_term, code_chunk_alloc, code_list;

code *code_next(code *c) { return c.next; }

@trusted
code *code_malloc()
{
    //printf("code %d\n", sizeof(code));
    code *c = code_list ? code_list : code_chunk_alloc();
    code_list = code_next(c);
    //printf("code_malloc: %p\n",c);
    return c;
}

/************************************
 * Register save state.
 */

struct REGSAVE
{
    targ_size_t off;            // offset on stack
    uint top;                   // high water mark
    uint idx;                   // current number in use
    int alignment;              // 8 or 16

  nothrow:
    @trusted
    void reset() { off = 0; top = 0; idx = 0; alignment = _tysize[TYnptr]/*REGSIZE*/; }
    void save(ref CodeBuilder cdb, reg_t reg, uint *pidx) { REGSAVE_save(this, cdb, reg, *pidx); }
    void restore(ref CodeBuilder cdb, reg_t reg, uint idx) { REGSAVE_restore(this, cdb, reg, idx); }
}

/************************************
 * Local sections on the stack
 */
struct LocalSection
{
    targ_size_t offset;         // offset of section from frame pointer
    targ_size_t size;           // size of section
    int alignment;              // alignment size

  nothrow:
    void initialize()
    {   offset = 0;
        size = 0;
        alignment = 0;
    }
}

/*******************************
 * As we generate code, collect information about
 * what parts of NT exception handling we need.
 */

enum
{
    NTEH_try        = 1,      // used _try statement
    NTEH_except     = 2,      // used _except statement
    NTEHexcspec     = 4,      // had C++ exception specification
    NTEHcleanup     = 8,      // destructors need to be called
    NTEHtry         = 0x10,   // had C++ try statement
    NTEHcpp         = (NTEHexcspec | NTEHcleanup | NTEHtry),
    EHcleanup       = 0x20,   // has destructors in the 'code' instructions
    EHtry           = 0x40,   // has BCtry or BC_try blocks
    NTEHjmonitor    = 0x80,   // uses Mars monitor
    NTEHpassthru    = 0x100,
}

/********************** Code Generator State ***************/

struct CGstate
{
    int stackclean;     // if != 0, then clean the stack after function call

    LocalSection funcarg;       // where function arguments are placed
    targ_size_t funcargtos;     // current high water level of arguments being moved onto
                                // the funcarg section. It is filled from top to bottom,
                                // as if they were 'pushed' on the stack.
                                // Special case: if funcargtos==~0, then no
                                // arguments are there.
    bool accessedTLS;           // set if accessed Thread Local Storage (TLS)
}

public import dmd.backend.nteh;
public import dmd.backend.cgen;
public import dmd.backend.cgreg : cgreg_init, cgreg_term, cgreg_reset, cgreg_used,
    cgreg_spillreg_prolog, cgreg_spillreg_epilog, cgreg_assign, cgreg_unregister;

public import dmd.backend.cgsched : cgsched_block;

alias IDXSTR = uint;
alias IDXSEC = uint;
alias IDXSYM = uint;

struct seg_data
{
    segidx_t             SDseg;         // index into SegData[]
    targ_size_t          SDoffset;      // starting offset for data
    int                  SDalignment;   // power of 2

    static if (1) // for Windows
    {
        bool isfarseg;
        int segidx;                     // internal object file segment number
        int lnameidx;                   // lname idx of segment name
        int classidx;                   // lname idx of class name
        uint attr;                      // segment attribute
        targ_size_t origsize;           // original size
        int seek;                       // seek position in output file
        void* ledata;                   // (Ledatarec) current one we're filling in
    }

    //ELFOBJ || MACHOBJ
    IDXSEC           SDshtidx;          // section header table index
    OutBuffer       *SDbuf;             // buffer to hold data
    OutBuffer       *SDrel;             // buffer to hold relocation info

    //ELFOBJ
    IDXSYM           SDsymidx;          // each section is in the symbol table
    IDXSEC           SDrelidx;          // section header for relocation info
    int              SDrelcnt;          // number of relocations added
    IDXSEC           SDshtidxout;       // final section header table index
    Symbol          *SDsym;             // if !=NULL, comdat symbol
    segidx_t         SDassocseg;        // for COMDATs, if !=0, this is the "associated" segment

    uint             SDaranges_offset;  // if !=0, offset in .debug_aranges

    Barray!(linnum_data) SDlinnum_data;     // array of line number / offset data

  nothrow:
    @trusted
    int isCode() { return config.objfmt == OBJ_MACH ? mach_seg_data_isCode(this) : mscoff_seg_data_isCode(this); }
}

public import dmd.backend.machobj : mach_seg_data_isCode;
public import dmd.backend.mscoffobj : mscoff_seg_data_isCode;

struct linnum_data
{
    const(char) *filename;
    uint filenumber;        // corresponding file number for DW_LNS_set_file

    Barray!(LinOff) linoff;    // line numbers and offsets
}

struct LinOff
{
    uint lineNumber;
    uint offset;
}

public import dmd.backend.cgobj : SegData;

@trusted
ref targ_size_t Offset(int seg) { return SegData[seg].SDoffset; }

@trusted
ref targ_size_t Doffset() { return Offset(DATA); }

@trusted
ref targ_size_t CDoffset() { return Offset(CDATA); }

/**************************************************/

/* Allocate registers to function parameters
 */

struct FuncParamRegs
{
    //this(tym_t tyf);
    @trusted
    static FuncParamRegs create(tym_t tyf) { return FuncParamRegs_create(tyf); }

    @trusted
    int alloc(type *t, tym_t ty, ubyte *reg1, ubyte *reg2)
    { return FuncParamRegs_alloc(this, t, ty, reg1, reg2); }

  private:
  public: // for the moment
    tym_t tyf;                  // type of function
    int i;                      // ith parameter
    int regcnt;                 // how many general purpose registers are allocated
    int xmmcnt;                 // how many fp registers are allocated
    uint numintegerregs;        // number of gp registers that can be allocated
    uint numfloatregs;          // number of fp registers that can be allocated
    const(ubyte)* argregs;      // map to gp register
    const(ubyte)* floatregs;    // map to fp register
}

public import dmd.backend.cg : BPRM, FLOATREGS, FLOATREGS2, DOUBLEREGS,
    localsize, framehandleroffset, cseg, STACKALIGN, TARGET_STACKALIGN;

public import dmd.backend.cgcod;
enum BackendPass
{
    initial,    /// initial pass through code generator
    reg,        /// register assignment pass
    final_,     /// final pass
}

public import dmd.backend.cgcod : retsize, findreg;

reg_t findregmsw(uint regm) { return findreg(regm & mMSW); }
reg_t findreglsw(uint regm) { return findreg(regm & (mLSW | mBP)); }

public import dmd.backend.cod1;
public import dmd.backend.cod2;
public import dmd.backend.cod3;
public import dmd.backend.cod4;
public import dmd.backend.cod5;
public import dmd.backend.cgen : outfixlist, addtofixlist;

public import dmd.backend.cgxmm;
public import dmd.backend.cg87;

/**********************************
 * Get registers used by a given block
 * Params: bp = asm block
 * Returns: mask of registers used by block bp.
 */
@system
regm_t iasm_regs(block *bp)
{
    debug (debuga)
        printf("Block iasm regs = 0x%X\n", bp.usIasmregs);

    refparam |= bp.bIasmrefparam;
    return bp.usIasmregs;
}

/**********************************
 * Set value in regimmed for reg.
 * NOTE: For 16 bit generator, this is always a (targ_short) sign-extended
 *      value.
 */
@trusted
void regimmed_set(int reg, targ_size_t e)
{
    regcon.immed.value[reg] = e;
    regcon.immed.mval |= 1 << (reg);
    //printf("regimmed_set %s %d\n", regm_str(1 << reg), cast(int)e);
}
