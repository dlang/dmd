/**
 * Various global symbols.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1995 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/cg.d, backend/cg.d)
 */

module dmd.backend.cg;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.global;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.type;


///////////////////// GLOBALS /////////////////////

__gshared
{
targ_size_t     localgotoffset; // offset of where localgot refers to

int cseg = CODE;                // current code segment
                                // (negative values mean it is the negative
                                // of the public name index of a COMDAT)

/* Stack offsets        */
targ_size_t localsize;          /* amt subtracted from SP for local vars */

/* The following are initialized for the 8088. cod3_set32() or cod3_set64()
 * will change them as appropriate.
 */
int     BPRM = 6;               /* R/M value for [BP] or [EBP]          */
regm_t  fregsaved;              // mask of registers saved across function calls

regm_t  FLOATREGS = FLOATREGS_16;
regm_t  FLOATREGS2 = FLOATREGS2_16;
regm_t  DOUBLEREGS = DOUBLEREGS_16;

Symbol* localgot;               // reference to GOT for this function
Symbol* tls_get_addr_sym;       // function __tls_get_addr

int TARGET_STACKALIGN = 2;      // default for 16 bit code
int STACKALIGN = 2;             // varies for each function


/// Is fl data?
bool[FL.max + 1] datafl = datafl_init;
extern (D) private enum datafl_init =
() {
    bool[FL.max + 1] datafl;
    foreach (fl; [ FL.data, FL.udata, FL.reg, FL.pseudo, FL.auto_, FL.fast, FL.para, FL.extern_,
                   FL.cs, FL.fltreg, FL.allocatmp, FL.datseg, FL.tlsdata, FL.bprel,
                   FL.stack, FL.regsave, FL.funcarg,
                   FL.ndp,  FL.fardata,
                 ])
    {
        datafl[fl] = true;
    }
    return datafl;
} ();


/// Is fl on the stack?
bool[FL.max + 1] stackfl = stackfl_init;
extern (D) private enum stackfl_init =
() {
    bool[FL.max + 1] stackfl;
    foreach (fl; [ FL.auto_, FL.fast, FL.para, FL.cs, FL.fltreg, FL.allocatmp, FL.bprel, FL.stack, FL.regsave,
                   FL.funcarg,
                   FL.ndp,
                 ])
    {
        stackfl[fl] = true;
    }
    return stackfl;
} ();

/// What segment register is associated with it?
ubyte[FL.max + 1] segfl = segfl_init;
extern (D) private enum segfl_init =
() {
    ubyte[FL.max + 1] segfl;

    // Segment registers
    enum ES = 0;
    enum CS = 1;
    enum SS = 2;
    enum DS = 3;
    enum NO = ubyte.max;        // no register

    foreach (fl, ref seg; segfl)
    {
        switch (fl)
        {
            case 0:               seg = NO;  break;
            case FL.const_:       seg = NO;  break;
            case FL.oper:         seg = NO;  break;
            case FL.func:         seg = CS;  break;
            case FL.data:         seg = DS;  break;
            case FL.udata:        seg = DS;  break;
            case FL.reg:          seg = NO;  break;
            case FL.pseudo:       seg = NO;  break;
            case FL.auto_:        seg = SS;  break;
            case FL.fast:         seg = SS;  break;
            case FL.stack:        seg = SS;  break;
            case FL.bprel:        seg = SS;  break;
            case FL.para:         seg = SS;  break;
            case FL.extern_:      seg = DS;  break;
            case FL.code:         seg = CS;  break;
            case FL.block:        seg = CS;  break;
            case FL.blockoff:     seg = CS;  break;
            case FL.cs:           seg = SS;  break;
            case FL.regsave:      seg = SS;  break;
            case FL.ndp:          seg = SS;  break;
            case FL.switch_:      seg = NO;  break;
            case FL.fltreg:       seg = SS;  break;
            case FL.offset:       seg = NO;  break;
            case FL.fardata:      seg = NO;  break;
            case FL.csdata:       seg = CS;  break;
            case FL.datseg:       seg = DS;  break;
            case FL.ctor:         seg = NO;  break;
            case FL.dtor:         seg = NO;  break;
            case FL.dsymbol:      seg = NO;  break;
            case FL.got:          seg = NO;  break;
            case FL.gotoff:       seg = NO;  break;
            case FL.tlsdata:      seg = NO;  break;
            case FL.localsize:    seg = NO;  break;
            case FL.framehandler: seg = NO;  break;
            case FL.asm_:         seg = NO;  break;
            case FL.allocatmp:    seg = SS;  break;
            case FL.funcarg:      seg = SS;  break;

            default:
                assert(0);
        }
    }

    return segfl;
} ();

/// Is fl in the symbol table?
bool[FL.max + 1] flinsymtab = flinsymtab_init;
extern (D) private enum flinsymtab_init =
() {
    bool[FL.max + 1] flinsymtab;
    foreach (fl; [ FL.data, FL.udata, FL.reg, FL.pseudo, FL.auto_, FL.fast, FL.para, FL.extern_, FL.func,
                   FL.tlsdata, FL.bprel, FL.stack,
                   FL.fardata, FL.csdata,
                 ])
    {
        flinsymtab[fl] = true;
    }
    return flinsymtab;
} ();

}
