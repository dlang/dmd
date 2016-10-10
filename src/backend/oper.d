/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 2000-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     backendlicense.txt
 * Source:      $(DMDSRC backend/_oper.d)
 */

module ddmd.backend.oper;

extern (C++):
@nogc:
nothrow:

alias int OPER;
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

/* Convert from token to assignment operator    */
//int asgtoktoop(int tok) { return tok + OPeq - TKeq; }


/************************************
 * Determine things about relational operators.
 */

//OPER rel_toktoop(int tk) { return tk - TKle + RELOPMIN; }

extern __gshared ubyte[RELOPMAX - RELOPMIN + 1]
        _rel_not,
        _rel_swap,
        _rel_integral,
        _rel_exception,
        _rel_unord;

int rel_not(int op)       { return _rel_not      [op - RELOPMIN]; }
int rel_swap(int op)      { return _rel_swap     [op - RELOPMIN]; }
int rel_integral(int op)  { return _rel_integral [op - RELOPMIN]; }
int rel_exception(int op) { return _rel_exception[op - RELOPMIN]; }
int rel_unord(int op)     { return _rel_unord    [op - RELOPMIN]; }

/****************************************
 * Conversion operators.
 * Convert from conversion operator to conversion index
 * parallel array invconvtab[] in cgelem.c)
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

// Workaround 2.066.x bug by resolving the TYMAX value before using it as dimension.
static if (__VERSION__ <= 2066)
    private enum computeEnumValue = OPMAX;

extern (C)
{
    extern __gshared ubyte[OPMAX] optab1;
    extern __gshared ubyte[OPMAX] optab2;
    extern __gshared ubyte[OPMAX] optab3;
    extern __gshared ubyte[OPMAX] opcost;
}

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

ubyte OTbinary(int op)    { return optab1[op] & _OTbinary; }
ubyte OTunary(int op)     { return optab1[op] & _OTunary; }
bool  OTleaf(int op)      { return !(optab1[op] & (_OTunary|_OTbinary)); }
ubyte OTcommut(int op)    { return optab1[op] & _OTcommut; }
ubyte OTassoc(int op)     { return optab1[op] & _OTassoc; }
ubyte OTassign(int op)    { return optab2[op]&_OTassign; }
bool  OTpost(int op)      { return op == OPpostinc || op == OPpostdec; }
ubyte OTeop0e(int op)     { return optab1[op] & _OTeop0e; }
ubyte OTeop00(int op)     { return optab1[op] & _OTeop00; }
ubyte OTeop1e(int op)     { return optab1[op] & _OTeop1e; }
ubyte OTsideff(int op)    { return optab1[op] & _OTsideff; }
bool  OTconv(int op)      { return op >= CNVOPMIN && op <= CNVOPMAX; }
ubyte OTlogical(int op)   { return optab2[op] & _OTlogical; }
ubyte OTwid(int op)       { return optab2[op] & _OTwid; }
bool  OTopeq(int op)      { return op >= OPaddass && op <= OPashrass; }
bool  OTop(int op)        { return op >= OPadd && op <= OPor; }
ubyte OTcall(int op)      { return optab2[op] & _OTcall; }
ubyte OTrtol(int op)      { return optab2[op] & _OTrtol; }
bool  OTrel(int op)       { return op >= OPle && op <= OPnue; }
bool  OTrel2(int op)      { return op >= OPle && op <= OPge; }
ubyte OTdef(int op)       { return optab2[op] & _OTdef; }
ubyte OTae(int op)        { return optab2[op] & _OTae; }
ubyte OTboolnop(int op)   { return optab3[op] & _OTboolnop; }
bool  OTcalldef(int op)   { return OTcall(op) || op == OPstrcpy || op == OPstrcat || op == OPmemcpy; }

/* Convert op= to op    */
int opeqtoop(int opx)   { return opx - OPaddass + OPadd; }

/* Convert op to op=    */
int optoopeq(int opx)   { return opx - OPadd + OPaddass; }

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

