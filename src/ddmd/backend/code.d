/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/_code.d
 */

module ddmd.backend.code;

import ddmd.backend.cc;
import ddmd.backend.cdef;
import ddmd.backend.code_x86;
import ddmd.backend.outbuf;
import ddmd.backend.type;

extern (C++):

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

code *code_calloc();
void code_free(code *);
void code_term();

code *code_next(code *c) { return c.next; }

/************************************
 * Local sections on the stack
 */
struct LocalSection
{
    targ_size_t offset;         // offset of section from frame pointer
    targ_size_t size;           // size of section
    int alignment;              // alignment size

    void init()                 // initialize
    {   offset = 0;
        size = 0;
        alignment = 0;
    }
}

/*******************************
 * As we generate code, collect information about
 * what parts of NT exception handling we need.
 */

extern __gshared uint usednteh;

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

extern __gshared LocalSection Para;

alias IDXSTR = uint;
alias IDXSEC = uint;
alias IDXSYM = uint;

struct seg_data
{
    segidx_t             SDseg;         // index into SegData[]
    targ_size_t          SDoffset;      // starting offset for data
    int                  SDalignment;   // power of 2

    version (Windows) // OMFOBJ
    {
        bool isfarseg;
        int segidx;                     // internal object file segment number
        int lnameidx;                   // lname idx of segment name
        int classidx;                   // lname idx of class name
        uint attr;                      // segment attribute
        targ_size_t origsize;           // original size
        long seek;                      // seek position in output file
        void* ledata;                   // (Ledatarec) current one we're filling in
    }

    //ELFOBJ || MACHOBJ
    IDXSEC           SDshtidx;          // section header table index
    Outbuffer       *SDbuf;             // buffer to hold data
    Outbuffer       *SDrel;             // buffer to hold relocation info

    //ELFOBJ
    IDXSYM           SDsymidx;          // each section is in the symbol table
    IDXSEC           SDrelidx;          // section header for relocation info
    targ_size_t      SDrelmaxoff;       // maximum offset encountered
    int              SDrelindex;        // maximum offset encountered
    int              SDrelcnt;          // number of relocations added
    IDXSEC           SDshtidxout;       // final section header table index
    Symbol          *SDsym;             // if !=NULL, comdat symbol
    segidx_t         SDassocseg;        // for COMDATs, if !=0, this is the "associated" segment

    uint             SDaranges_offset;  // if !=0, offset in .debug_aranges

    uint             SDlinnum_count;
    uint             SDlinnum_max;
    linnum_data     *SDlinnum_data;     // array of line number / offset data

    int isCode();
}



struct linnum_data
{
    const(char) *filename;
    uint filenumber;        // corresponding file number for DW_LNS_set_file

    uint linoff_count;
    uint linoff_max;
    uint[2]* linoff;        // [0] = line number, [1] = offset
}

extern __gshared seg_data **SegData;

/**************************************************/

/* Allocate registers to function parameters
 */

struct FuncParamRegs
{
    //this(tym_t tyf);
    static FuncParamRegs create(tym_t tyf);

    int alloc(type *t, tym_t ty, ubyte *reg1, ubyte *reg2);

  private:
    tym_t tyf;                  // type of function
    int i;                      // ith parameter
    int regcnt;                 // how many general purpose registers are allocated
    int xmmcnt;                 // how many fp registers are allocated
    uint numintegerregs;        // number of gp registers that can be allocated
    uint numfloatregs;          // number of fp registers that can be allocated
    const(ubyte)* argregs;      // map to gp register
    const(ubyte)* floatregs;    // map to fp register
}

extern __gshared int BPRM;

/* cgxmm.c */
bool isXMMstore(uint op);

extern __gshared LocalSection Alloca;

/* cgcod.c */
extern __gshared targ_size_t retoffset;
extern __gshared int refparam;

/* cod3.c */
targ_size_t cod3_spoff();
uint calccodsize(code *c);
targ_size_t cod3_bpoffset(Symbol *s);

/* cgxmm.c */
void checkSetVex3(code *c);
void checkSetVex(code *c, tym_t ty);

// nteh.c
code *nteh_patchindex(code* c, int index);


extern (C++) struct CodeBuilder
{
  private:

    code *head;
    code **pTail;

  public:
    //this() { pTail = &head; }
    //this(code *c);
    void ctor() { pTail = &head; }

  extern (C++):
  final:
    code *finish() { return head; }
    code *peek() { return head; }       // non-destructively look at the list
    void reset() { head = null; pTail = &head; }

    void append(ref CodeBuilder cdb);
    void append(ref CodeBuilder cdb1, ref CodeBuilder cdb2);
    void append(ref CodeBuilder cdb1, ref CodeBuilder cdb2, ref CodeBuilder cdb3);
    void append(ref CodeBuilder cdb1, ref CodeBuilder cdb2, ref CodeBuilder cdb3, ref CodeBuilder cdb4);
    void append(ref CodeBuilder cdb1, ref CodeBuilder cdb2, ref CodeBuilder cdb3, ref CodeBuilder cdb4, ref CodeBuilder cdb5);

    void append(code *c);

    void gen(code *cs);
    void gen1(uint op);
    void gen2(uint op, uint rm);
    void genf2(uint op, uint rm);
    void gen2sib(uint op, uint rm, uint sib);
    void genasm(char *s, uint slen);
    void genasm(_LabelDsymbol *label);
    void genasm(block *label);
    void gencsi(uint op, uint rm, uint FL2, SYMIDX si);
    void gencs(uint op, uint rm, uint FL2, Symbol *s);
    void genc2(uint op, uint rm, targ_size_t EV2);
    void genc1(uint op, uint rm, uint FL1, targ_size_t EV1);
    void genc(uint op, uint rm, uint FL1, targ_size_t EV1, uint FL2, targ_size_t EV2);
    void genlinnum(Srcpos);
    void genadjesp(int offset);
    void genadjfpu(int offset);
    void gennop();

    /*****************
     * Returns:
     *  code that pTail points to
     */
    code *last()
    {
        // g++ and clang++ complain about offsetof() because of the code::code() constructor.
        // return (code *)((char *)pTail - offsetof(code, next));
        // So do our own.
        return cast(code *)(cast(void *)pTail - (cast(void*)&(*pTail).next - cast(void*)*pTail));
    }
}



