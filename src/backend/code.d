/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1996 by Symantec
 *              Copyright (c) 2000-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     backendlicense.txt
 * Source:      $(DMDSRC backend/_code.d)
 */

module ddmd.backend.code;

import ddmd.backend.cc;
import ddmd.backend.cdef;
import ddmd.backend.outbuf;
import ddmd.backend.type;

extern (C++):

alias segidx_t = int;           // index into SegData[]

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


