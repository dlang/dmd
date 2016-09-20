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

import ddmd.backend.cdef;
import ddmd.backend.type;

extern (C++):

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


