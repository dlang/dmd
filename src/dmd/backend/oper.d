/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/oper.d, backend/oper.d)
 */

module dmd.backend.oper;

// Online documentation: https://dlang.org/phobos/dmd_backend_oper.html

extern (C++):
@nogc:
nothrow:
@safe:

alias OPER = int;
enum
{
        OPunde,                 // place holder for undefined operator

        OPadd,
        OPmin,
        OPmul,
        OPdiv,
        OPmod,
        OPshr,                  // unsigned right shift
        OPshl,
        OPand,
        OPxor,
        OPor,
        OPashr,                 // signed right shift
        OPnot,
        OPbool,                 // "booleanize"
        OPcom,
        OPcond,
        OPcomma,
        OPoror,
        OPandand,
        OPbit,                  // ref to bit field
        OPind,                  // *E
        OPaddr,                 // &E
        OPneg,                  // unary -
        OPuadd,                 // unary +
        OPvoid,                 // where casting to void is not a no-op
        OPabs,                  // absolute value
        OPtoprec,               // round to precision (for 80 bit reals)
        OPrndtol,               // round to short, long, long long (inline 8087 only)
        OPrint,                 // round to int

        OPsqrt,                 // square root
        OPsin,                  // sine
        OPcos,                  // cosine
        OPscale,                // ldexp
        OPyl2x,                 // y * log2(x)
        OPyl2xp1,               // y * log2(x + 1)
        OPcmpxchg,              // cmpxchg

        OPstrlen,               // strlen()
        OPstrcpy,               // strcpy()
        OPstrcat,               // strcat()
        OPstrcmp,               // strcmp()
        OPmemcpy,
        OPmemcmp,
        OPmemset,
        OPsetjmp,               // setjmp()

        OPremquo,               // / and % in one operation

        OPbsf,                  // bit scan forward
        OPbsr,                  // bit scan reverse
        OPbt,                   // bit test
        OPbtc,                  // bit test and complement
        OPbtr,                  // bit test and reset
        OPbts,                  // bit test and set
        OPbswap,                // swap bytes
        OProl,                  // rotate left
        OPror,                  // rotate right
        OPbtst,                 // bit test
        OPpopcnt,               // count of number of bits set to 1

        OPstreq,                // structure assignment

        OPnegass,               // x = -x
        OPpostinc,              // x++
        OPpostdec,              // x--

        OPeq,
        OPaddass,
        OPminass,
        OPmulass,
        OPdivass,
        OPmodass,
        OPshrass,
        OPshlass,
        OPandass,
        OPxorass,
        OPorass,

        OPashrass,

        // relational operators (in same order as corresponding tokens)
        RELOPMIN,
        OPle = RELOPMIN,
        OPgt,
        OPlt,
        OPge,
        OPeqeq,
        OPne,

        OPunord,        // !<>=
        OPlg,           // <>
        OPleg,          // <>=
        OPule,          // !>
        OPul,           // !>=
        OPuge,          // !<
        OPug,           // !<=
        OPue,           // !<>
        OPngt,
        OPnge,
        OPnlt,
        OPnle,
        OPord,
        OPnlg,
        OPnleg,
        OPnule,
        OPnul,
        OPnuge,
        OPnug,
        RELOPMAX,
        OPnue = RELOPMAX,

//**************** End of relational operators *****************

/*      8,16,32,64      integral type of unspecified sign
        s,u             signed/unsigned
        f,d,ld          float/double/long double
        np,fp,vp,f16p   near pointer/far pointer/handle pointer/far16 pointer
        cvp             const handle pointer
*/

        CNVOPMIN,
        OPb_8 = CNVOPMIN,   // convert bit to byte
        OPd_s32,
        OPs32_d,
        OPd_s16,
        OPs16_d,
        OPd_u16,
        OPu16_d,
        OPd_u32,
        OPu32_d,
        OPd_s64,
        OPs64_d,
        OPd_u64,
        OPu64_d,
        OPd_f,
        OPf_d,
        OPs16_32,       // short to long
        OPu16_32,       // unsigned short to long
        OP32_16,        // long to short
        OPu8_16,        // unsigned char to short
        OPs8_16,        // signed char to short
        OP16_8,         // short to 8 bits
        OPu32_64,       // unsigned long to long long
        OPs32_64,       // long to long long
        OP64_32,        // long long to long
        OPu64_128,
        OPs64_128,
        OP128_64,

        // segmented
        OPvp_fp,
        OPcvp_fp,       // const handle * => far *
        OPoffset,       // get offset of far pointer
        OPnp_fp,        // convert near pointer to far
        OPnp_f16p,      // from 0:32 to 16:16
        OPf16p_np,      // from 16:16 to 0:32

        OPld_d,
        OPd_ld,
        CNVOPMAX,
        OPld_u64 = CNVOPMAX,

//**************** End of conversion operators *****************

        OPc_r,          // complex to real
        OPc_i,          // complex to imaginary
        OPmsw,          // top 32 bits of 64 bit word (32 bit code gen)
                        // top 16 bits of 32 bit word (16 bit code gen)

        OPparam,                // function parameter separator
        OPcall,                 // binary function call
        OPucall,                // unary function call
        OPcallns,               // binary function call, no side effects
        OPucallns,              // unary function call, no side effects

        OPsizeof,               // for forward-ref'd structs
        OPstrctor,              // call ctor on struct param
        OPstrthis,              // 'this' pointer for OPstrctor
        OPstrpar,               // structure func param
        OPconst,                // constant
        OPrelconst,             // constant that contains an address
        OPvar,                  // variable
        OPreg,                  // register (used in inline asm operand expressions)
        OPcolon,                // : as in ?:
        OPcolon2,               // alternate version with different EH semantics
        OPstring,               // address of string
        OPnullptr,              // null pointer
        OPasm,                  // in-line assembly code
        OPinfo,                 // attach info (used to attach ctor/dtor
                                // info for exception handling)
        OPhalt,                 // insert HLT instruction
        OPctor,
        OPdtor,
        OPmark,
        OPdctor,                // D constructor
        OPddtor,                // D destructor

        OPpair,                 // build register pair, E1 is lsb, E2 = msb
        OPrpair,                // build reversed register pair, E1 is msb, E2 = lsb
        OPframeptr,             // load pointer to base of frame
        OPgot,                  // load pointer to global offset table
        OPvector,               // SIMD vector operations
        OPvecsto,               // SIMD vector store operations
        OPvecfill,              // fill SIMD vector with E1

        OPinp,                  // input from I/O port
        OPoutp,                 // output to I/O port

        // C++ operators
        OPnew,                  // operator new
        OPanew,                 // operator new[]
        OPdelete,               // operator delete
        OPadelete,              // operator delete[]
        OPbrack,                // [] subscript
        OParrow,                // for -> overloading
        OParrowstar,            // for ->* overloading
        OPpreinc,               // ++x overloading
        OPpredec,               // --x overloading

        OPva_start,             // va_start intrinsic (dmd)
        OPprefetch,             // prefetch intrinsic (dmd)

        OPMAX                   // 1 past last operator
}


/************************************
 * Determine things about relational operators.
 */

OPER rel_not(OPER op)       { return _rel_not      [op - RELOPMIN]; }
OPER rel_swap(OPER op)      { return _rel_swap     [op - RELOPMIN]; }
OPER rel_integral(OPER op)  { return _rel_integral [op - RELOPMIN]; }
OPER rel_exception(OPER op) { return _rel_exception[op - RELOPMIN]; }
OPER rel_unord(OPER op)     { return _rel_unord    [op - RELOPMIN]; }

/****************************************
 * Conversion operators.
 * Convert from conversion operator to conversion index
 * parallel array invconvtab[] in cgelem.c
 * Params:
 *   op = conversion operator
 */
int convidx(OPER op) { return op - CNVOPMIN; }


/**********************************
 * Various types of operators:
 *      OTbinary        binary
 *      OTunary         unary
 *      OTleaf          leaf
 *      OTcommut        commutative (e1 op e2) == (e2 op e1)
 *                      (assoc == !=)
 *      OTassoc         associative (e1 op (e2 op e3)) == ((e1 op e2) op e3)
 *                      (also commutative)
 *      OTassign        assignment = op= i++ i-- i=-i str=
 *      OTpost          post inc or post dec operator
 *      OTeop0e         if (e op 0) => e
 *      OTeop00         if (e op 0) => 0
 *      OTeop1e         if (e op 1) => e
 *      OTsideff        there are side effects to the operator (assign call
 *                      post ?: && ||)
 *      OTconv          type conversion operator that could appear on lhs of
 *                      assignment operator
 *      OTlogical       logical operator (result is 0 or 1)
 *      OTwid           high order bits of operation are irrelevant
 *      OTopeq          an op= operator
 *      OTop            an operator that has a corresponding op=
 *      OTcall          function call
 *      OTrtol          operators that evaluate right subtree first then left
 *      OTrel           == != < <= > >= operators
 *      OTrel2          < <= > >= operators
 *      OTdef           definition operator (assign call post asm)
 *      OTae            potential common subexpression operator
 *      OTboolnop       operation is a nop if boolean result is desired
 */

/* optab1[]     */      /* Use byte arrays to avoid index scaling       */
enum
{
    _OTbinary       = 1,
    _OTunary        = 2,
    _OTcommut       = 4,
    _OTassoc        = 8,
    _OTsideff       = 0x10,
    _OTeop0e        = 0x20,
    _OTeop00        = 0x40,
    _OTeop1e        = 0x80,
}

/* optab2[]     */
enum
{
    _OTlogical      = 1,
    _OTwid          = 2,
    _OTcall         = 4,
    _OTrtol         = 8,
    _OTassign       = 0x10,
    _OTdef          = 0x20,
    _OTae           = 0x40,
}

// optab3[]
enum
{
    _OTboolnop      = 1,
}

ubyte OTbinary(OPER op)    { return optab1[op] & _OTbinary; }
ubyte OTunary(OPER op)     { return optab1[op] & _OTunary; }
bool  OTleaf(OPER op)      { return !(optab1[op] & (_OTunary|_OTbinary)); }
ubyte OTcommut(OPER op)    { return optab1[op] & _OTcommut; }
ubyte OTassoc(OPER op)     { return optab1[op] & _OTassoc; }
ubyte OTassign(OPER op)    { return optab2[op]&_OTassign; }
bool  OTpost(OPER op)      { return op == OPpostinc || op == OPpostdec; }
ubyte OTeop0e(OPER op)     { return optab1[op] & _OTeop0e; }
ubyte OTeop00(OPER op)     { return optab1[op] & _OTeop00; }
ubyte OTeop1e(OPER op)     { return optab1[op] & _OTeop1e; }
ubyte OTsideff(OPER op)    { return optab1[op] & _OTsideff; }
bool  OTconv(OPER op)      { return op >= CNVOPMIN && op <= CNVOPMAX; }
ubyte OTlogical(OPER op)   { return optab2[op] & _OTlogical; }
ubyte OTwid(OPER op)       { return optab2[op] & _OTwid; }
bool  OTopeq(OPER op)      { return op >= OPaddass && op <= OPashrass; }
bool  OTop(OPER op)        { return op >= OPadd && op <= OPor; }
ubyte OTcall(OPER op)      { return optab2[op] & _OTcall; }
ubyte OTrtol(OPER op)      { return optab2[op] & _OTrtol; }
bool  OTrel(OPER op)       { return op >= OPle && op <= OPnue; }
bool  OTrel2(OPER op)      { return op >= OPle && op <= OPge; }
ubyte OTdef(OPER op)       { return optab2[op] & _OTdef; }
ubyte OTae(OPER op)        { return optab2[op] & _OTae; }
ubyte OTboolnop(OPER op)   { return optab3[op] & _OTboolnop; }
bool  OTcalldef(OPER op)   { return OTcall(op) || op == OPstrcpy || op == OPstrcat || op == OPmemcpy; }

/* Convert op= to op    */
OPER opeqtoop(OPER opx)   { return opx - OPaddass + OPadd; }

/* Convert op to op=    */
OPER optoopeq(OPER opx)   { return opx - OPadd + OPaddass; }

OPER swaprel(OPER);

/***************************
 * Determine properties of an elem.
 * EBIN         binary node?
 * EUNA         unary node?
 * EOP          operator node (unary or binary)?
 * ERTOL        right to left evaluation (left to right is default)
 * Eunambig     unambiguous definition elem?
 */

//#define EBIN(e) (OTbinary((e)->Eoper))
//#define EUNA(e) (OTunary((e)->Eoper))

/* ERTOL(e) is moved to el.c    */

//#define Elvalue(e)      ((e)->E1)
//#define Eunambig(e)     (OTassign((e)->Eoper) && (e)->E1->Eoper == OPvar)

//#define EOP(e)  (!OTleaf((e)->Eoper))

extern (D):

extern (C) immutable ubyte[OPMAX] optab1 =
() {
    ubyte[OPMAX] tab;
    foreach (i; Ebinary) { tab[i] |= _OTbinary; }
    foreach (i; Eunary)  { tab[i] |= _OTunary;  }
    foreach (i; Ecommut) { tab[i] |= _OTcommut; }
    foreach (i; Eassoc)  { tab[i] |= _OTassoc;  }
    foreach (i; Esideff) { tab[i] |= _OTsideff; }
    foreach (i; Eeop0e)  { tab[i] |= _OTeop0e;  }
    foreach (i; Eeop00)  { tab[i] |= _OTeop00;  }
    foreach (i; Eeop1e)  { tab[i] |= _OTeop1e;  }
    return tab;
} ();

immutable ubyte[OPMAX] optab2 =
() {
    ubyte[OPMAX] tab;
    foreach (i; Elogical) { tab[i] |= _OTlogical; }
    foreach (i; Ewid)     { tab[i] |= _OTwid;     }
    foreach (i; Ecall)    { tab[i] |= _OTcall;    }
    foreach (i; Ertol)    { tab[i] |= _OTrtol;    }
    foreach (i; Eassign)  { tab[i] |= _OTassign;  }
    foreach (i; Edef)     { tab[i] |= _OTdef;     }
    foreach (i; Eae)      { tab[i] |= _OTae;      }
    return tab;
} ();

immutable ubyte[OPMAX] optab3 =
() {
    ubyte[OPMAX] tab;
    foreach (i; Eboolnop) { tab[i] |= _OTboolnop; }
    return tab;
} ();

private enum RELMAX = RELOPMAX - RELOPMIN + 1;

immutable ubyte[RELMAX] _rel_exception =
() {
    ubyte[RELMAX] tab;
    foreach (i; Eexception) { tab[cast(int)i - RELOPMIN] = 1; }
    return tab;
} ();

immutable ubyte[RELMAX] _rel_unord =
() {
    ubyte[RELMAX] tab;
    foreach (i; Eunord) { tab[cast(int)i - RELOPMIN] = 1; }
    return tab;
} ();

/// Logical negation
immutable ubyte[RELMAX] _rel_not =
() {
    ubyte[RELMAX] tab;
    foreach (op; RELOPMIN .. RELOPMAX + 1)
    {
        OPER opnot;
        switch (op)
        {
            case OPeqeq:  opnot = OPne;    break;
            case OPne:    opnot = OPeqeq;  break;
            case OPgt:    opnot = OPngt;   break;
            case OPge:    opnot = OPnge;   break;
            case OPlt:    opnot = OPnlt;   break;
            case OPle:    opnot = OPnle;   break;

            case OPunord: opnot = OPord;   break;
            case OPlg:    opnot = OPnlg;   break;
            case OPleg:   opnot = OPnleg;  break;
            case OPule:   opnot = OPnule;  break;
            case OPul:    opnot = OPnul;   break;
            case OPuge:   opnot = OPnuge;  break;
            case OPug:    opnot = OPnug;   break;
            case OPue:    opnot = OPnue;   break;

            case OPngt:   opnot = OPgt;    break;
            case OPnge:   opnot = OPge;    break;
            case OPnlt:   opnot = OPlt;    break;
            case OPnle:   opnot = OPle;    break;
            case OPord:   opnot = OPunord; break;
            case OPnlg:   opnot = OPlg;    break;
            case OPnleg:  opnot = OPleg;   break;
            case OPnule:  opnot = OPule;   break;
            case OPnul:   opnot = OPul;    break;
            case OPnuge:  opnot = OPuge;   break;
            case OPnug:   opnot = OPug;    break;
            case OPnue:   opnot = OPue;    break;

            default:
                assert(0);
        }
        tab[cast(int)op - RELOPMIN] = cast(ubyte)opnot;
    }

    foreach (op; RELOPMIN .. RELOPMAX + 1)
    {
        OPER opnot = tab[cast(int)op - RELOPMIN];
        assert(op == tab[cast(int)opnot - RELOPMIN]);  // symmetry check
    }
    return tab;
} ();


/// Operand swap
immutable ubyte[RELMAX] _rel_swap =
() {
    ubyte[RELMAX] tab;
    foreach (op; RELOPMIN .. RELOPMAX + 1)
    {
        OPER opswap;
        switch (op)
        {
            case OPeqeq:  opswap = op;      break;
            case OPne:    opswap = op;      break;
            case OPgt:    opswap = OPlt;    break;
            case OPge:    opswap = OPle;    break;
            case OPlt:    opswap = OPgt;    break;
            case OPle:    opswap = OPge;    break;

            case OPunord: opswap = op;      break;
            case OPlg:    opswap = op;      break;
            case OPleg:   opswap = op;      break;
            case OPule:   opswap = OPuge;   break;
            case OPul:    opswap = OPug;    break;
            case OPuge:   opswap = OPule;   break;
            case OPug:    opswap = OPul;    break;
            case OPue:    opswap = op;      break;

            case OPngt:   opswap = OPnlt;   break;
            case OPnge:   opswap = OPnle;   break;
            case OPnlt:   opswap = OPngt;   break;
            case OPnle:   opswap = OPnge;   break;
            case OPord:   opswap = op;      break;
            case OPnlg:   opswap = op;      break;
            case OPnleg:  opswap = op;      break;
            case OPnule:  opswap = OPnuge;  break;
            case OPnul:   opswap = OPnug;   break;
            case OPnuge:  opswap = OPnule;  break;
            case OPnug:   opswap = OPnul;   break;
            case OPnue:   opswap = op;      break;

            default:
                assert(0);
        }
        tab[cast(int)op - RELOPMIN] = cast(ubyte)opswap;
    }

    foreach (op; RELOPMIN .. RELOPMAX + 1)
    {
        OPER opswap = tab[cast(int)op - RELOPMIN];
        assert(op == tab[cast(int)opswap - RELOPMIN]);  // symmetry check
    }
    return tab;
} ();

/// If operands are integral types
immutable ubyte[RELMAX] _rel_integral =
() {
    ubyte[RELMAX] tab;
    foreach (op; RELOPMIN .. RELOPMAX + 1)
    {
        OPER opintegral;
        switch (op)
        {
            case OPeqeq:  opintegral = op;          break;
            case OPne:    opintegral = op;          break;
            case OPgt:    opintegral = op;          break;
            case OPge:    opintegral = op;          break;
            case OPlt:    opintegral = op;          break;
            case OPle:    opintegral = op;          break;

            case OPunord: opintegral = cast(OPER)0; break;
            case OPlg:    opintegral = OPne;        break;
            case OPleg:   opintegral = cast(OPER)1; break;
            case OPule:   opintegral = OPle;        break;
            case OPul:    opintegral = OPlt;        break;
            case OPuge:   opintegral = OPge;        break;
            case OPug:    opintegral = OPgt;        break;
            case OPue:    opintegral = OPeqeq;      break;

            case OPngt:   opintegral = OPle;        break;
            case OPnge:   opintegral = OPlt;        break;
            case OPnlt:   opintegral = OPge;        break;
            case OPnle:   opintegral = OPgt;        break;
            case OPord:   opintegral = cast(OPER)1; break;
            case OPnlg:   opintegral = OPeqeq;      break;
            case OPnleg:  opintegral = cast(OPER)0; break;
            case OPnule:  opintegral = OPgt;        break;
            case OPnul:   opintegral = OPge;        break;
            case OPnuge:  opintegral = OPlt;        break;
            case OPnug:   opintegral = OPle;        break;
            case OPnue:   opintegral = OPne;        break;

            default:
                assert(0);
        }
        tab[cast(int)op - RELOPMIN] = cast(ubyte)opintegral;
    }
    return tab;
} ();

/*************************************
 * Determine the cost of evaluating an operator.
 *
 * Used for reordering elem trees to minimize register usage.
 */

immutable ubyte[OPMAX] opcost =
() {
    ubyte[OPMAX] tab;
    foreach (op; 0 .. OPMAX)
    {
        ubyte c = 0;        // default cost
        foreach (o; Eunary)
        {
            if (o == op)
            {
                c += 2;
                break;
            }
        }

        foreach (o; Ebinary)
        {
            if (o == op)
            {
                c += 7;
                break;
            }
        }

        foreach (o; Elogical)
        {
            if (o == op)
            {
                c += 3;
                break;
            }
        }

        switch (op)
        {
            case OPvar: c += 1; break;
            case OPmul: c += 3; break;
            case OPdiv:
            case OPmod: c += 4; break;
            case OProl:
            case OPror:
            case OPshl:
            case OPashr:
            case OPshr: c += 2; break;
            case OPcall:
            case OPucall:
            case OPcallns:
            case OPucallns:
                        c += 10; break; // very high cost for function calls
            default:
                break;
        }
        tab[op] = c;
    }
    return tab;
} ();

extern (C++) __gshared const(char)*[OPMAX] debtab =
[
    OPunde:    "unde",
    OPadd:     "+",
    OPmul:     "*",
    OPand:     "&",
    OPmin:     "-",
    OPnot:     "!",
    OPcom:     "~",
    OPcond:    "?",
    OPcomma:   ",",
    OPremquo:  "/%",
    OPdiv:     "/",
    OPmod:     "%",
    OPxor:     "^",
    OPstring:  "string",
    OPrelconst: "relconst",
    OPinp:     "inp",
    OPoutp:    "outp",
    OPasm:     "asm",
    OPinfo:    "info",
    OPdctor:   "dctor",
    OPddtor:   "ddtor",
    OPctor:    "ctor",
    OPdtor:    "dtor",
    OPmark:    "mark",
    OPvoid:    "void",
    OPhalt:    "halt",
    OPnullptr: "nullptr",
    OPpair:    "pair",
    OPrpair:   "rpair",
    OPtoprec:  "toprec",

    OPor:      "|",
    OPoror:    "||",
    OPandand:  "&&",
    OProl:     "<<|",
    OPror:     ">>|",
    OPshl:     "<<",
    OPshr:     ">>>",
    OPashr:    ">>",
    OPbit:     "bit",
    OPind:     "*",
    OPaddr:    "&",
    OPneg:     "-",
    OPuadd:    "+",
    OPabs:     "abs",
    OPsqrt:    "sqrt",
    OPsin:     "sin",
    OPcos:     "cos",
    OPscale:   "scale",
    OPyl2x:    "yl2x",
    OPyl2xp1:  "yl2xp1",
    OPcmpxchg:     "cas",
    OPrint:    "rint",
    OPrndtol:  "rndtol",
    OPstrlen:  "strlen",
    OPstrcpy:  "strcpy",
    OPmemcpy:  "memcpy",
    OPmemset:  "memset",
    OPstrcat:  "strcat",
    OPstrcmp:  "strcmp",
    OPmemcmp:  "memcmp",
    OPsetjmp:  "setjmp",
    OPnegass:  "negass",
    OPpreinc:  "U++",
    OPpredec:  "U--",
    OPstreq:   "streq",
    OPpostinc: "++",
    OPpostdec: "--",
    OPeq:      "=",
    OPaddass:  "+=",
    OPminass:  "-=",
    OPmulass:  "*=",
    OPdivass:  "/=",
    OPmodass:  "%=",
    OPshrass:  ">>>=",
    OPashrass: ">>=",
    OPshlass:  "<<=",
    OPandass:  "&=",
    OPxorass:  "^=",
    OPorass:   "|=",

    OPle:      "<=",
    OPgt:      ">",
    OPlt:      "<",
    OPge:      ">=",
    OPeqeq:    "==",
    OPne:      "!=",

    OPunord:   "!<>=",
    OPlg:      "<>",
    OPleg:     "<>=",
    OPule:     "!>",
    OPul:      "!>=",
    OPuge:     "!<",
    OPug:      "!<=",
    OPue:      "!<>",
    OPngt:     "~>",
    OPnge:     "~>=",
    OPnlt:     "~<",
    OPnle:     "~<=",
    OPord:     "~!<>=",
    OPnlg:     "~<>",
    OPnleg:    "~<>=",
    OPnule:    "~!>",
    OPnul:     "~!>=",
    OPnuge:    "~!<",
    OPnug:     "~!<=",
    OPnue:     "~!<>",

    OPvp_fp:   "vptrfptr",
    OPcvp_fp:  "cvptrfptr",
    OPoffset:  "offset",
    OPnp_fp:   "ptrlptr",
    OPnp_f16p: "tofar16",
    OPf16p_np: "fromfar16",

    OPs16_32:  "s16_32",
    OPu16_32:  "u16_32",
    OPd_s32:   "d_s32",
    OPb_8:     "b_8",
    OPs32_d:   "s32_d",
    OPd_s16:   "d_s16",
    OPs16_d:   "s16_d",
    OPd_u16:   "d_u16",
    OPu16_d:   "u16_d",
    OPd_u32:   "d_u32",
    OPu32_d:   "u32_d",
    OP32_16:   "32_16",
    OPd_f:     "d_f",
    OPf_d:     "f_d",
    OPd_ld:    "d_ld",
    OPld_d:    "ld_d",
    OPc_r:     "c_r",
    OPc_i:     "c_i",
    OPu8_16:   "u8_16",
    OPs8_16:   "s8_16",
    OP16_8:    "16_8",
    OPu32_64:  "u32_64",
    OPs32_64:  "s32_64",
    OP64_32:   "64_32",
    OPu64_128: "u64_128",
    OPs64_128: "s64_128",
    OP128_64:  "128_64",
    OPmsw:     "msw",

    OPd_s64:   "d_s64",
    OPs64_d:   "s64_d",
    OPd_u64:   "d_u64",
    OPu64_d:   "u64_d",
    OPld_u64:  "ld_u64",
    OPparam:   "param",
    OPsizeof:  "sizeof",
    OParrow:   "->",
    OParrowstar: "->*",
    OPcolon:   "colon",
    OPcolon2:  "colon2",
    OPbool:    "bool",
    OPcall:    "call",
    OPucall:   "ucall",
    OPcallns:  "callns",
    OPucallns: "ucallns",
    OPstrpar:  "strpar",
    OPstrctor: "strctor",
    OPstrthis: "strthis",
    OPconst:   "const",
    OPvar:     "var",
    OPreg:     "reg",
    OPnew:     "new",
    OPanew:    "new[]",
    OPdelete:  "delete",
    OPadelete: "delete[]",
    OPbrack:   "brack",
    OPframeptr: "frameptr",
    OPgot:     "got",

    OPbsf:     "bsf",
    OPbsr:     "bsr",
    OPbtst:    "btst",
    OPbt:      "bt",
    OPbtc:     "btc",
    OPbtr:     "btr",
    OPbts:     "bts",

    OPbswap:   "bswap",
    OPpopcnt:  "popcnt",
    OPvector:  "vector",
    OPvecsto:  "vecsto",
    OPvecfill: "vecfill",
    OPva_start: "va_start",
    OPprefetch: "prefetch",
];

private:

/****
 * Different categories of operators.
 */

enum Ebinary =
    [
        OPadd,OPmul,OPand,OPmin,OPcond,OPcomma,OPdiv,OPmod,OPxor,
        OPor,OPoror,OPandand,OPshl,OPshr,OPashr,OPstreq,OPstrcpy,OPstrcat,OPstrcmp,
        OPpostinc,OPpostdec,OPeq,OPaddass,OPminass,OPmulass,OPdivass,
        OPmodass,OPshrass,OPashrass,OPshlass,OPandass,OPxorass,OPorass,
        OPle,OPgt,OPlt,OPge,OPeqeq,OPne,OPparam,OPcall,OPcallns,OPcolon,OPcolon2,
        OPbit,OPbrack,OParrowstar,OPmemcpy,OPmemcmp,OPmemset,
        OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
        OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
        OPinfo,OPpair,OPrpair,
        OPbt,OPbtc,OPbtr,OPbts,OPror,OProl,OPbtst,
        OPremquo,OPcmpxchg,
        OPoutp,OPscale,OPyl2x,OPyl2xp1,
        OPvecsto,OPprefetch
    ];

enum Eunary =
    [
        OPnot,OPcom,OPind,OPaddr,OPneg,OPuadd,
        OPabs,OPrndtol,OPrint,
        OPpreinc,OPpredec,
        OPbool,OPstrlen,
        OPb_8,OPs16_32,OPu16_32,OPd_s32,OPd_u32,
        OPs32_d,OPu32_d,OPd_s16,OPs16_d,OP32_16,
        OPd_f,OPf_d,OPu8_16,OPs8_16,OP16_8,
        OPd_ld, OPld_d,OPc_r,OPc_i,
        OPu32_64,OPs32_64,OP64_32,OPmsw,
        OPd_s64,OPs64_d,OPd_u64,OPu64_d,OPld_u64,
        OP128_64,OPs64_128,OPu64_128,
        OPucall,OPucallns,OPstrpar,OPstrctor,OPu16_d,OPd_u16,
        OParrow,OPnegass,OPtoprec,
        OPctor,OPdtor,OPsetjmp,OPvoid,
        OPbsf,OPbsr,OPbswap,OPpopcnt,
        OPddtor,
        OPvector,OPvecfill,
        OPva_start,
        OPsqrt,OPsin,OPcos,OPinp,
        OPvp_fp,OPcvp_fp,OPnp_fp,OPnp_f16p,OPf16p_np,OPoffset,
    ];

enum Ecommut =
    [
        OPadd,OPand,OPor,OPxor,OPmul,OPeqeq,OPne,OPle,OPlt,OPge,OPgt,
        OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
        OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
    ];

enum Eassoc = [ OPadd,OPand,OPor,OPxor,OPmul ];

enum Esideff =
    [
        OPasm,OPucall,OPstrcpy,OPmemcpy,OPmemset,OPstrcat,
        OPcall,OPeq,OPstreq,OPpostinc,OPpostdec,
        OPaddass,OPminass,OPmulass,OPdivass,OPmodass,OPandass,
        OPorass,OPxorass,OPshlass,OPshrass,OPashrass,
        OPnegass,OPctor,OPdtor,OPmark,OPvoid,
        OPbtc,OPbtr,OPbts,
        OPhalt,OPdctor,OPddtor,
        OPcmpxchg,
        OPva_start,
        OPinp,OPoutp,OPvecsto,OPprefetch,
    ];

enum Eeop0e =
    [
        OPadd,OPmin,OPxor,OPor,OPshl,OPshr,OPashr,OPpostinc,OPpostdec,OPaddass,
        OPminass,OPshrass,OPashrass,OPshlass,OPxorass,OPorass,
        OPror,OProl,
    ];

enum Eeop00 = [ OPmul,OPand,OPmulass,OPandass ];

enum Eeop1e = [ OPmul,OPdiv,OPmulass,OPdivass ];

enum Elogical =
    [
        OPeqeq,OPne,OPle,OPlt,OPgt,OPge,OPandand,OPoror,OPnot,OPbool,
        OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
        OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
        OPbt,OPbtst,
    ];

enum Ewid =
    [
        OPadd,OPmin,OPand,OPor,OPxor,OPcom,OPneg,OPmul,OPaddass,OPnegass,
        OPminass,OPandass,OPorass,OPxorass,OPmulass,OPshlass,OPshl,OPshrass,
        OPashrass,
    ];

enum Ecall = [ OPcall,OPucall,OPcallns,OPucallns ];

enum Ertol =
    [
        OPeq,OPstreq,OPstrcpy,OPmemcpy,OPpostinc,OPpostdec,OPaddass,
        OPminass,OPmulass,OPdivass,OPmodass,OPandass,
        OPorass,OPxorass,OPshlass,OPshrass,OPashrass,
        OPcall,OPcallns,OPinfo,OPmemset,
        OPvecsto,OPcmpxchg,
    ];

enum Eassign =
    [
        OPstreq,OPeq,OPaddass,OPminass,OPmulass,OPdivass,OPmodass,
        OPshrass,OPashrass,OPshlass,OPandass,OPxorass,OPorass,OPpostinc,OPpostdec,
        OPnegass,OPvecsto,OPcmpxchg,
    ];

enum Edef =
    [
        OPstreq,OPeq,OPaddass,OPminass,OPmulass,OPdivass,OPmodass,
        OPshrass,OPashrass,OPshlass,OPandass,OPxorass,OPorass,
        OPpostinc,OPpostdec,
        OPcall,OPucall,OPasm,OPstrcpy,OPmemcpy,OPmemset,OPstrcat,
        OPnegass,
        OPbtc,OPbtr,OPbts,
        OPvecsto,OPcmpxchg,
    ];

enum Eae =
    [
        OPvar,OPconst,OPrelconst,OPneg,
        OPabs,OPrndtol,OPrint,
        OPstrlen,OPstrcmp,OPind,OPaddr,
        OPnot,OPbool,OPcom,OPadd,OPmin,OPmul,OPand,OPor,OPmemcmp,
        OPxor,OPdiv,OPmod,OPshl,OPshr,OPashr,OPeqeq,OPne,OPle,OPlt,OPge,OPgt,
        OPunord,OPlg,OPleg,OPule,OPul,OPuge,OPug,OPue,OPngt,OPnge,
        OPnlt,OPnle,OPord,OPnlg,OPnleg,OPnule,OPnul,OPnuge,OPnug,OPnue,
        OPs16_32,OPu16_32,OPd_s32,OPd_u32,OPu16_d,OPd_u16,
        OPs32_d,OPu32_d,OPd_s16,OPs16_d,OP32_16,
        OPd_f,OPf_d,OPu8_16,OPs8_16,OP16_8,
        OPd_ld,OPld_d,OPc_r,OPc_i,
        OPu32_64,OPs32_64,OP64_32,OPmsw,
        OPd_s64,OPs64_d,OPd_u64,OPu64_d,OPld_u64,
        OP128_64,OPs64_128,OPu64_128,
        OPsizeof,OPtoprec,
        OPcallns,OPucallns,OPpair,OPrpair,
        OPbsf,OPbsr,OPbt,OPbswap,OPb_8,OPbtst,OPpopcnt,
        OPgot,OPremquo,
        OPnullptr,
        OProl,OPror,
        OPsqrt,OPsin,OPcos,OPscale,
        OPvp_fp,OPcvp_fp,OPnp_fp,OPnp_f16p,OPf16p_np,OPoffset,OPvecfill,
    ];

enum Eboolnop =
    [
        OPuadd,OPbool,OPs16_32,OPu16_32,
        OPs16_d,
        OPf_d,OPu8_16,OPs8_16,
        OPd_ld, OPld_d,
        OPu32_64,OPs32_64,/*OP64_32,OPmsw,*/
        OPs64_128,OPu64_128,
        OPu16_d,OPb_8,
        OPnullptr,
        OPnp_fp,OPvp_fp,OPcvp_fp,
        OPvecfill,
    ];

/** if invalid exception can be generated by operator */
enum Eexception =
    [
        OPgt,OPge,OPlt,OPle,
        OPlg,OPleg,
        OPngt,OPnge,OPnlt,OPnle,OPnlg,OPnleg,
    ];

/** result of unordered operands */
enum Eunord =
    [
        OPne,
        OPunord,OPule,OPul,OPuge,OPug,OPue,
        OPngt,OPnge,OPnlt,OPnle,OPnlg,OPnleg,
    ];
