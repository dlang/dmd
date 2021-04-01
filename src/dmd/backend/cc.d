/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cc.d, backend/_cc.d)
 */

module dmd.backend.cc;

// Online documentation: https://dlang.org/phobos/dmd_backend_cc.html

import dmd.backend.barray;
import dmd.backend.cdef;        // host and target compiler definition
import dmd.backend.code_x86;
import dmd.backend.dlist;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.symtab;
import dmd.backend.type;

extern (C++):
@nogc:
nothrow:
@safe:

enum GENOBJ = 1;       // generating .obj file

uint mskl(uint i) { return 1 << i; }     // convert int to mask

// Warnings
enum WM
{
    WM_no_inline    = 1,    //function '%s' is too complicated to inline
    WM_assignment   = 2,    //possible unintended assignment
    WM_nestcomment  = 3,    //comments do not nest
    WM_assignthis   = 4,    //assignment to 'this' is obsolete, use X::operator new/delete
    WM_notagname    = 5,    //no tag name for struct or enum
    WM_valuenotused = 6,    //value of expression is not used
    WM_extra_semi   = 7,    //possible extraneous ';'
    WM_large_auto   = 8,    //very large automatic
    WM_obsolete_del = 9,    //use delete[] rather than delete[expr], expr ignored
    WM_obsolete_inc = 10,   //using operator++() (or --) instead of missing operator++(int)
    WM_init2tmp     = 11,   //non-const reference initialized to temporary
    WM_used_b4_set  = 12,   //variable '%s' used before set
    WM_bad_op       = 13,   //Illegal type/size of operands for the %s instruction
    WM_386_op       = 14,   //Reference to '%s' caused a 386 instruction to be generated
    WM_ret_auto     = 15,   //returning address of automatic '%s'
    WM_ds_ne_dgroup = 16,   //DS is not equal to DGROUP
    WM_unknown_pragma = 17, //unrecognized pragma
    WM_implied_ret  = 18,   //implied return at closing '}' does not return value
    WM_num_args     = 19,   //%d actual arguments expected for %s, had %d
    WM_before_pch   = 20,   //symbols or macros defined before #include of precompiled header
    WM_pch_first    = 21,   //precompiled header must be first #include when -H is used
    WM_pch_config   = 22,
    WM_divby0       = 23,
    WM_badnumber    = 24,
    WM_ccast        = 25,
    WM_obsolete     = 26,

    // Posix
    WM_skip_attribute   = 27, // skip GNUC attribute specification
    WM_warning_message  = 28, // preprocessor warning message
    WM_bad_vastart      = 29, // args for builtin va_start bad
    WM_undefined_inline = 30, // static inline not expanded or defined
}

static if (MEMMODELS == 1)
{
    enum LARGEDATA = 0;     // don't want 48 bit pointers
    enum LARGECODE = 0;
}
else
{
    bool LARGEDATA() { return (config.memmodel & 6) != 0; }
    bool LARGECODE() { return (config.memmodel & 5) != 0; }
}

version (SPP)
{
    enum COMPILER = "Preprocessor";
    enum ACTIVITY = "preprocessing...";
}
else version (HTOD)
{
    enum COMPILER = ".h to D Migration Tool";
    enum ACTIVITY = "migrating...";
}
else version (SCPP)
{
    enum COMPILER = "C/C++ Compiler";
    enum ACTIVITY = "compiling...";
}

//#ifdef DEBUG
//#   define debug(a)     (a)
//#   define debugx(a)    (a)
//#   define debug_assert assert
//#else
//#   define debug(a)
//#   define debugx(a)
//#   define debug_assert(e)
//#endif

/***************************
 * Print out debugging information.
 */

//#ifdef DEBUG
//#define debugmes(s)     (debugw && dbg_printf(s))
//#define cmes(s)         (debugc && dbg_printf(s))
//#define cmes2(s,b)      (debugc && dbg_printf((s),(b)))
//#define cmes3(s,b,c)    (debugc && dbg_printf((s),(b),(c)))
//#else
//#define debugmes(s)
//#define cmes(s)
//#define cmes2(s,b)
//#define cmes3(s,b,c)
//#endif


//#define arraysize(array)        (sizeof(array) / sizeof(array[0]))

enum IDMAX = 900;              // identifier max (excluding terminating 0)
enum IDOHD = 4+1+int.sizeof*3; // max amount of overhead to ID added by
enum STRMAX = 65_000;           // max length of string (determined by
                                // max ph size)

//enum SC;
struct Thunk
{   Symbol *sfunc;
    Symbol *sthunk;
    targ_size_t d;
    targ_size_t d2;
    int i;
}


version (MARS)
    struct token_t;
else
    import dtoken : token_t;

//struct param_t;
//struct block;
//struct Classsym;
//struct Nspacesym;
//struct Outbuffer;
//struct Aliassym;
//struct dt_t;
//typedef struct TYPE type;
//typedef struct Symbol symbol;
alias Funcsym = Symbol;
//#if !MARS
//typedef struct MACRO macro_t;
version (MARS)
    struct blklst;
else
    import parser : blklst;
//#endif
//typedef list_t symlist_t;       /* list of pointers to Symbols          */
alias symlist_t = list_t;
alias vec_t = size_t*;
alias enum_TK = ubyte;

__gshared Config config;

@trusted
uint CPP() { return config.flags3 & CFG3cpp; }


/////////// Position in source file

struct Srcpos
{
nothrow:
    uint Slinnum;           // 0 means no info available
    uint Scharnum;
    version (SCPP)
    {
        Sfile **Sfilptr;            // file
        short Sfilnum;              // file number
    }
    version (SPP)
    {
        Sfile **Sfilptr;            // file
        short Sfilnum;              // file number
    }
    version (HTOD)
    {
        Sfile **Sfilptr;            // file
        short Sfilnum;              // file number
    }

    version (MARS)
    {
        const(char)* Sfilename;

        const(char*) name() const { return Sfilename; }

        static Srcpos create(const(char)* filename, uint linnum, int charnum)
        {
            // Cannot have constructor because Srcpos is used in a union
            Srcpos sp;
            sp.Sfilename = filename;
            sp.Slinnum = linnum;
            sp.Scharnum = charnum;
            return sp;
        }

        /*******
         * Set fields of Srcpos
         * Params:
         *      filename = file name
         *      linnum = line number
         *      charnum = character number
         */
        void set(const(char)* filename, uint linnum, int charnum) pure
        {
            Sfilename = filename;
            Slinnum = linnum;
            Scharnum = charnum;
        }
    }

    void print(const(char)* func) const { Srcpos_print(this, func); }
}

version (SCPP)
{
    static Sfile srcpos_sfile(Srcpos p) { return **(p).Sfilptr; }
    static char* srcpos_name(Srcpos p)   { return srcpos_sfile(p).SFname; }
}
version (SPP)
{
    static Sfile srcpos_sfile(Srcpos p) { return **(p).Sfilptr; }
    static char* srcpos_name(Srcpos p)   { return srcpos_sfile(p).SFname; }
}
version (HTOD)
{
    static Sfile srcpos_sfile(Srcpos p) { return **(p).Sfilptr; }
    static char* srcpos_name(Srcpos p)   { return srcpos_sfile(p).SFname; }
}

void Srcpos_print(ref const Srcpos srcpos, const(char)* func);

//#include "token.h"

alias stflags_t = uint;
enum
{
    PFLpreprocessor  = 1,       // in preprocessor
    PFLmasm          = 2,       // in Microsoft-style inline assembler
    PFLbasm          = 4,       // in Borland-style inline assembler
    PFLsemi          = 8,       // ';' means start of comment
//  PFLautogen       = 0x10,    // automatically generate HX ph file
    PFLmftemp        = 0x20,    // if expanding member function template
    PFLextdef        = 0x40,    // we had an external def
    PFLhxwrote       = 0x80,    // already generated HX ph file
    PFLhxdone        = 0x100,   // done with HX ph file

    // if TX86
    PFLhxread        = 0x200,   // have read in an HX ph file
    PFLhxgen         = 0x400,   // need to generate HX ph file
    PFLphread        = 0x800,   // read a ph file
    PFLcomdef        = 0x1000,  // had a common block
    PFLmacdef        = 0x2000,  // defined a macro in the source code
    PFLsymdef        = 0x4000,  // declared a global Symbol in the source
    PFLinclude       = 0x8000,  // read a .h file
    PFLmfc           = 0x10000, // something will affect MFC compatibility
}

alias sthflags_t = char;
enum
{
    FLAG_INPLACE    = 0,       // in place hydration
    FLAG_HX         = 1,       // HX file hydration
    FLAG_SYM        = 2,       // .SYM file hydration
}

/**********************************
 * Current 'state' of the compiler.
 * Used to gather together most global variables.
 * This struct is saved/restored during function body parsing.
 */

struct Pstate
{
    ubyte STinopeq;             // if in n2_createopeq()
    ubyte STinarglist;          // if !=0, then '>' is the end of a template
                                // argument list, not an operator
    ubyte STinsizeof;           // !=0 if in a sizeof expression. Useful to
                                // prevent <array of> being converted to
                                // <pointer to>.
    ubyte STintemplate;         // if !=0, then expanding a function template
                                // (do not expand template Symbols)
    ubyte STdeferDefaultArg;    // defer parsing of default arg for parameter
    ubyte STnoexpand;           // if !=0, don't expand template symbols
    ubyte STignoretal;          // if !=0 ignore template argument list
    ubyte STexplicitInstantiation;      // if !=0, then template explicit instantiation
    ubyte STexplicitSpecialization;     // if !=0, then template explicit specialization
    ubyte STinconstexp;         // if !=0, then parsing a constant expression
    ubyte STisaddr;             // is this a possible pointer to member expression?
    uint STinexp;               // if !=0, then in an expression

    static if (NTEXCEPTIONS)
    {
        ubyte STinfilter;       // if !=0 then in exception filter
        ubyte STinexcept;       // if !=0 then in exception handler
        block *STbfilter;       // current exception filter
    }

    version (MARS)
    {
    }
    else
    {
        int STinitseg;          // segment for static constructor function pointer
    }
    Funcsym *STfuncsym_p;       // if inside a function, then this is the
                                // function Symbol.

    stflags_t STflags;

    version (MARS)
    {
    }
    else
    {
        int STinparamlist;      // if != 0, then parser is in
                                // function parameter list
        int STingargs;          // in template argument list
        list_t STincalias;      // list of include aliases
        list_t STsysincalias;   // list of system include aliases
    }

    // should probably be inside #if HYDRATE, but unclear for the dmc source
    sthflags_t SThflag;         // FLAG_XXXX: hydration flag

    Classsym *STclasssym;       // if in the scope of this class
    symlist_t STclasslist;      // list of classes that have deferred inline
                                // functions to parse
    Classsym *STstag;           // returned by struct_searchmember() and with_search()
    SYMIDX STmarksi;            // to determine if temporaries are created
    ubyte STnoparse;            // add to classlist instead of parsing
    ubyte STdeferparse;         // defer member func parse
    SC STgclass;                // default function storage class
    int STdefertemps;           // defer allocation of temps
    int STdeferaccesscheck;     // defer access check for members (BUG: it
                                // never does get done later)
    int STnewtypeid;            // parsing new-type-id
    int STdefaultargumentexpression;    // parsing default argument expression
    block *STbtry;              // current try block
    block *STgotolist;          // threaded goto scoping list
    int STtdbtimestamp;         // timestamp of tdb file
    Symbol *STlastfunc;         // last function symbol parsed by ext_def()

    // For "point of definition" vs "point of instantiation" template name lookup
    uint STsequence;            // sequence number (Ssequence) of next Symbol
    uint STmaxsequence;         // won't find Symbols with STsequence larger
                                // than STmaxsequence
}

@trusted
void funcsym_p(Funcsym* fp) { pstate.STfuncsym_p = fp; }

@trusted
Funcsym* funcsym_p() { return pstate.STfuncsym_p; }

@trusted
stflags_t preprocessor() { return pstate.STflags & PFLpreprocessor; }

@trusted
stflags_t inline_asm()   { return pstate.STflags & (PFLmasm | PFLbasm); }

extern __gshared Pstate pstate;

/****************************
 * Global variables.
 */

struct Cstate
{
    blklst* CSfilblk;           // current source file we are parsing
    Symbol* CSlinkage;          // table of forward referenced linkage pragmas
    list_t CSlist_freelist;     // free list for list package
    symtab_t* CSpsymtab;        // pointer to current Symbol table
//#if MEMORYHX
//    void **CSphx;               // pointer to HX data block
//#endif
    char* modname;              // module unique identifier
}

extern __gshared Cstate cstate;

/* Bits for sytab[] that give characteristics of storage classes        */
enum
{
    SCEXP = 1,      // valid inside expressions
    SCKEP = 2,      // Symbol should be kept even when function is done
    SCSCT = 4,      // storage class is valid for use in static ctor
    SCSS  = 8,      // storage class is on the stack
    SCRD  = 0x10,   // we can do reaching definitions on these
}

// Determine if Symbol has a Ssymnum associated with it.
// (That is, it is allocated on the stack or has live variable analysis
//  done on it, so it is stack and register variables.)
//char symbol_isintab(Symbol *s) { return sytab[s.Sclass] & SCSS; }

//version (Windows)
    alias enum_SC = char;
//else
//    alias SC enum_SC;


/******************************************
 * Basic blocks:
 *      Basic blocks are a linked list of all the basic blocks
 *      in a function. startblock heads the list.
 */

alias ClassDeclaration_ = void*;
alias Declaration_ = void*;
alias Module_ = void*;

struct Blockx
{
  version (MARS)
  {
    block* startblock;
    block* curblock;
    Funcsym* funcsym;
    Symbol* context;            // eh frame context variable
    int scope_index;            // current scope index
    int next_index;             // value for next scope index
    uint flags;                 // value to OR into Bflags
    block* tryblock;            // current enclosing try block
    elem* init;                 // static initializer
    ClassDeclaration_ classdec;
    Declaration_ member;        // member we're compiling for
    Module_ _module;            // module we're in
  }
}

alias bflags_t = ushort;
enum
{
    BFLvisited       = 1,       // set if block is visited
    BFLmark          = 2,       // set if block is visited
    BFLjmpoptdone    = 4,       // set when no more jump optimizations
                                //  are possible for this block
    BFLnostackopt    = 8,       // set when stack elimination should not
                                // be done
    // NTEXCEPTIONS
    BFLehcode        = 0x10,    // BC_filter: need to load exception code
    BFLunwind        = 0x1000,  // do local_unwind following block (unused)

    BFLnomerg        = 0x20,    // do not merge with other blocks
    BFLprolog        = 0x80,    // generate function prolog
    BFLepilog        = 0x100,   // generate function epilog
    BFLrefparam      = 0x200,   // referenced parameter
    BFLreflocal      = 0x400,   // referenced local
    BFLoutsideprolog = 0x800,   // outside function prolog/epilog
    BFLlabel         = 0x2000,  // block preceded by label
    BFLvolatile      = 0x4000,  // block is volatile
    BFLnounroll      = 0x8000,  // do not unroll loop
}

struct block
{
nothrow:
    union
    {
        elem *Belem;            // pointer to elem tree
        list_t  Blist;          // list of expressions
    }

    block *Bnext;               // pointer to next block in list
    list_t Bsucc;               // linked list of pointers to successors
                                //     of this block
    list_t Bpred;               // and the predecessor list
    int Bindex;                 // into created object stack
    int Bendindex;              // index at end of block
    block *Btry;                // BCtry,BC_try: enclosing try block, if any
                                // BC???: if in try-block, points to BCtry or BC_try
                                // note that can't have a BCtry and BC_try in
                                // the same function.
    union
    {
        targ_llong*      Bswitch;      // BCswitch: pointer to switch data
        struct
        {
            regm_t usIasmregs;         // Registers modified
            ubyte bIasmrefparam;       // References parameters?
        }

        struct
        {
            Symbol* catchvar;           // __throw() fills in this
        }                               // BCtry

        version (SCPP)
        {
            struct
            {
                type *Bcatchtype;       // one type for each catch block
            }                           // BCcatch
        }

        version (HTOD)
        {
            struct
            {
                type *Bcatchtype;       // one type for each catch block
            }                           // BCcatch
        }

        version (MARS)
        {
            struct
            {
                Symbol* Bcatchtype;     // one type for each catch block
                uint* actionTable;      // EH_DWARF: indices into typeTable, first is # of entries
            }                           // BCjcatch
        }

        struct
        {
            version (MARS)
            {
                Symbol *jcatchvar;      // __d_throw() fills in this
            }
            int Bscope_index;           // index into scope table
            int Blast_index;            // enclosing index into scope table
        }                               // BC_try

        struct
        {
            Symbol *flag;               // EH_DWARF: set to 'flag' symbol that encloses finally
            block *b_ret;               // EH_DWARF: associated BC_ret block
        }                               // finally

        // add member mimicking the largest of the other elements of this union, so it can be copied
        struct _BS { version (MARS) { Symbol *jcvar; } int Bscope_idx, Blast_idx; }
        _BS BS;
    }
    Srcpos      Bsrcpos;        // line number (0 if not known)
    ubyte       BC;             // exit condition (enum BC)

    ubyte       Balign;         // alignment

    bflags_t    Bflags;         // flags (BFLxxxx)
    code*       Bcode;          // code generated for this block

    uint        Bweight;        // relative number of times this block
                                // is executed (optimizer and codegen)

    uint        Bdfoidx;        // index of this block in dfo[]
    uint        Bnumber;        // sequence number of block
    union
    {
        uint _BLU;              // start of the union

        // CPP
        struct
        {
            SYMIDX      Bsymstart;      // (symstart <= symnum < symend) Symbols
            SYMIDX      Bsymend;        // are declared in this block
            block*      Bendscope;      // block that forms the end of the
                                        // scope for the declared Symbols
            uint        Bblknum;        // position of block from startblock
            Symbol*     Binitvar;       // !=NULL points to an auto variable with
                                        // an explicit or implicit initializer
            block*      Bgotolist;      // BCtry, BCcatch: backward list of try scopes
            block*      Bgotothread;    // BCgoto: threaded list of goto's to
                                        // unknown labels
        }

        // OPTIMIZER
        struct
        {
            vec_t       Bdom;           // mask of dominators for this block
            vec_t       Binrd;
            vec_t       Boutrd;         // IN and OUT for reaching definitions
            vec_t       Binlv;
            vec_t       Boutlv;         // IN and OUT for live variables
            vec_t       Bin;
            vec_t       Bout;           // IN and OUT for other flow analyses
            vec_t       Bgen;
            vec_t       Bkill;          // pointers to bit vectors used by data
                                        // flow analysis

            // BCiftrue can have different vectors for the 2nd successor:
            vec_t       Bout2;
            vec_t       Bgen2;
            vec_t       Bkill2;
        }

        // CODGEN
        struct
        {
            // For BCswitch, BCjmptab
            targ_size_t Btablesize;     // size of generated table
            targ_size_t Btableoffset;   // offset to start of table
            targ_size_t Btablebase;     // offset to instruction pointer base

            targ_size_t Boffset;        // code offset of start of this block
            targ_size_t Bsize;          // code size of this block
            con_t       Bregcon;        // register state at block exit
            targ_size_t Btryoff;        // BCtry: offset of try block data
        }
    }

    @trusted
    void appendSucc(block* b)        { list_append(&this.Bsucc, b); }

    @trusted
    void prependSucc(block* b)       { list_prepend(&this.Bsucc, b); }

    @trusted
    int numSucc()                    { return list_nitems(this.Bsucc); }

    @trusted
    block* nthSucc(int n)            { return cast(block*)list_ptr(list_nth(Bsucc, n)); }

    @trusted
    void setNthSucc(int n, block *b) { list_nth(Bsucc, n).ptr = b; }
}

@trusted
inout(block)* list_block(inout list_t lst) { return cast(inout(block)*)list_ptr(lst); }

/** Basic block control flow operators. **/

alias BC = int;
enum
{
    BCgoto      = 1,    // goto Bsucc block
    BCiftrue    = 2,    // if (Belem) goto Bsucc[0] else Bsucc[1]
    BCret       = 3,    // return (no return value)
    BCretexp    = 4,    // return with return value
    BCexit      = 5,    // never reaches end of block (like exit() was called)
    BCasm       = 6,    // inline assembler block (Belem is NULL, Bcode
                        // contains code generated).
                        // These blocks have one or more successors in Bsucc,
                        // never 0
    BCswitch    = 7,    // switch statement
                        // Bswitch points to switch data
                        // Default is Bsucc
                        // Cases follow in linked list
    BCifthen    = 8,    // a BCswitch is converted to if-then
                        // statements
    BCjmptab    = 9,    // a BCswitch is converted to a jump
                        // table (switch value is index into
                        // the table)
    BCtry       = 10,   // C++ try block
                        // first block in a try-block. The first block in
                        // Bsucc is the next one to go to, subsequent
                        // blocks are the catch blocks
    BCcatch     = 11,   // C++ catch block
    BCjump      = 12,   // Belem specifies (near) address to jump to
    BC_try      = 13,   // SEH: first block of try-except or try-finally
                        // D: try-catch or try-finally
    BC_filter   = 14,   // SEH exception-filter (always exactly one block)
    BC_finally  = 15,   // first block of SEH termination-handler,
                        // or D finally block
    BC_ret      = 16,   // last block of SEH termination-handler or D _finally block
    BC_except   = 17,   // first block of SEH exception-handler
    BCjcatch    = 18,   // D catch block
    BC_lpad     = 19,   // EH_DWARF: landing pad for BC_except
    BCMAX
}

/********************************
 * Range for blocks.
 */
struct BlockRange
{
  pure nothrow @nogc @safe:

    this(block* b)
    {
        this.b = b;
    }

    block* front() return  { return b; }
    void popFront() { b = b.Bnext; }
    bool empty() const { return !b; }

  private:
    block* b;
}

/**********************************
 * Functions
 */

alias func_flags_t = uint;
enum
{
    Fpending    = 1,           // if function has been queued for being written
    Foutput     = 2,           // if function has been written out
    Foperator   = 4,           // if operator overload
    Fcast       = 8,           // if cast overload
    Finline     = 0x10,        // if SCinline, and function really is inline
    Foverload   = 0x20,        // if function can be overloaded
    Ftypesafe   = 0x40,        // if function name needs type appended
    Fmustoutput = 0x80,        // set for forward ref'd functions that
                               // must be output
    Fvirtual    = 0x100,       // if function is a virtual function
    Fctor       = 0x200,       // if function is a constructor
    Fdtor       = 0x400,       // if function is a destructor
    Fnotparent  = 0x800,       // if function is down Foversym chain
    Finlinenest = 0x1000,      // used as a marker to prevent nested
                               // inlines from expanding
    Flinkage    = 0x2000,      // linkage is already specified
    Fstatic     = 0x4000,      // static member function (no this)
    Fbitcopy    = 0x8000,      // it's a simple bitcopy (op=() or X(X&))
    Fpure       = 0x10000,     // pure function
    Finstance   = 0x20000,     // function is an instance of a template
    Ffixed      = 0x40000,     // ctor has had cpp_fixconstructor() run on it,
                               // dtor has had cpp_fixdestructor()
    Fintro      = 0x80000,     // function doesn't hide a previous virtual function
//  unused      = 0x100000,    // unused bit
    Fkeeplink   = 0x200000,    // don't change linkage to default
    Fnodebug    = 0x400000,    // do not generate debug info for this function
    Fgen        = 0x800000,    // compiler generated function
    Finvariant  = 0x1000000,   // __invariant function
    Fexplicit   = 0x2000000,   // explicit constructor
    Fsurrogate  = 0x4000000,   // surrogate call function
}

alias func_flags3_t = uint;
enum
{
    Fvtblgen         = 1,       // generate vtbl[] when this function is defined
    Femptyexc        = 2,       // empty exception specification (obsolete, use Tflags & TFemptyexc)
    Fcppeh           = 4,       // uses C++ EH
    Fnteh            = 8,       // uses NT Structured EH
    Fdeclared        = 0x10,    // already declared function Symbol
    Fmark            = 0x20,    // has unbalanced OPctor's
    Fdoinline        = 0x40,    // do inline walk
    Foverridden      = 0x80,    // ignore for overriding purposes
    Fjmonitor        = 0x100,   // Mars synchronized function
    Fnosideeff       = 0x200,   // function has no side effects
    F3badoparrow     = 0x400,   // bad operator->()
    Fmain            = 0x800,   // function is main() or wmain()
    Fnested          = 0x1000,  // D nested function with 'this'
    Fmember          = 0x2000,  // D member function with 'this'
    Fnotailrecursion = 0x4000,  // no tail recursion optimizations
    Ffakeeh          = 0x8000,  // allocate space for NT EH context sym anyway
    Fnothrow         = 0x10000, // function does not throw (even if not marked 'nothrow')
    Feh_none         = 0x20000, // ehmethod==EH_NONE for this function only
    F3hiddenPtr      = 0x40000, // function has hidden pointer to return value
}

struct func_t
{
    symlist_t Fsymtree;         // local Symbol table
    block *Fstartblock;         // list of blocks comprising function
    symtab_t Flocsym;           // local Symbol table
    Srcpos Fstartline;          // starting line # of function
    Srcpos Fendline;            // line # of closing brace of function
    Symbol *F__func__;          // symbol for __func__[] string
    func_flags_t Fflags;
    func_flags3_t Fflags3;
    ubyte Foper;                // operator number (OPxxxx) if Foperator

    Symbol *Fparsescope;        // use this scope to parse friend functions
                                // which are defined within a class, so the
                                // class is in scope, but are not members
                                // of the class

    Classsym *Fclass;           // if member of a class, this is the class
                                // (I think this is redundant with Sscope)
    Funcsym *Foversym;          // overloaded function at same scope
    symlist_t Fclassfriends;    // Symbol list of classes of which this
                                // function is a friend
    block *Fbaseblock;          // block where base initializers get attached
    block *Fbaseendblock;       // block where member destructors get attached
    elem *Fbaseinit;            // list of member initializers (meminit_t)
                                // this field has meaning only for
                                // functions which are constructors
    token_t *Fbody;             // if deferred parse, this is the list
                                // of tokens that make up the function
                                // body
                                // also used if SCfunctempl, SCftexpspec
    uint Fsequence;             // sequence number at point of definition
    union
    {
        Symbol* Ftempl;         // if Finstance this is the template that generated it
        Thunk* Fthunk;          // !=NULL if this function is actually a thunk
    }
    Funcsym *Falias;            // SCfuncalias: function Symbol referenced
                                // by using-declaration
    symlist_t Fthunks;          // list of thunks off of this function
    param_t *Farglist;          // SCfunctempl: the template-parameter-list
    param_t *Fptal;             // Finstance: this is the template-argument-list
                                // SCftexpspec: for explicit specialization, this
                                // is the template-argument-list
    list_t Ffwdrefinstances;    // SCfunctempl: list of forward referenced instances
    list_t Fexcspec;            // List of types in the exception-specification
                                // (NULL if none or empty)
    Funcsym *Fexplicitspec;     // SCfunctempl, SCftexpspec: threaded list
                                // of SCftexpspec explicit specializations
    Funcsym *Fsurrogatesym;     // Fsurrogate: surrogate cast function

    char *Fredirect;            // redirect function name to this name in object

version (SPP) { } else
{
    version (MARS)
        // Array of catch types for EH_DWARF Types Table generation
        Barray!(Symbol*) typesTable;
}

    union
    {
        uint LSDAoffset;        // ELFOBJ: offset in LSDA segment of the LSDA data for this function
        Symbol* LSDAsym;        // MACHOBJ: GCC_except_table%d
    }
}

//func_t* func_calloc() { return cast(func_t *) mem_fcalloc(func_t.sizeof); }
//void    func_free(func_t *f) { mem_ffree(f); }

/**************************
 * Item in list for member initializer.
 */

struct meminit_t
{
    list_t  MIelemlist;         // arg list for initializer
    Symbol *MIsym;              // if NULL, then this initializer is
                                // for the base class. Otherwise, this
                                // is the member that needs the ctor
                                // called for it
}

alias baseclass_flags_t = uint;
enum
{
     BCFpublic     = 1,         // base class is public
     BCFprotected  = 2,         // base class is protected
     BCFprivate    = 4,         // base class is private

     BCFvirtual    = 8,         // base class is virtual
     BCFvfirst     = 0x10,      // virtual base class, and this is the
                                // first virtual appearance of it
     BCFnewvtbl    = 0x20,      // new vtbl generated for this base class
     BCFvirtprim   = 0x40,      // Primary base class of a virtual base class
     BCFdependent  = 0x80,      // base class is a dependent type
}
enum baseclass_flags_t BCFpmask = BCFpublic | BCFprotected | BCFprivate;


/************************************
 * Base classes are a list of these.
 */

struct baseclass_t
{
    Classsym*         BCbase;           // base class Symbol
    baseclass_t*      BCnext;           // next base class
    targ_size_t       BCoffset;         // offset from start of derived class to this
    ushort            BCvbtbloff;       // for BCFvirtual, offset from start of
                                        //     vbtbl[] to entry for this virtual base.
                                        //     Valid in Sbase list
    symlist_t         BCpublics;        // public members of base class (list is freeable)
    list_t            BCmptrlist;       // (in Smptrbase only) this is the vtbl
                                        // (NULL if not different from base class's vtbl
    Symbol*           BCvtbl;           // Symbol for vtbl[] array (in Smptrbase list)
                                        // Symbol for vbtbl[] array (in Svbptrbase list)
    baseclass_flags_t BCflags;          // base class flags
    Classsym*         BCparent;         // immediate parent of this base class
                                        //     in Smptrbase
    baseclass_t*      BCpbase;          // parent base, NULL if did not come from a parent
}

//baseclass_t* baseclass_malloc() { return cast(baseclass_t*) mem_fmalloc(baseclass_t.sizeof); }
void baseclass_free(baseclass_t *b) { }

/*************************
 * For virtual tables.
 */

alias mptr_flags_t = char;
enum
{
    MPTRvirtual     = 1,       // it's an offset to a virtual base
    MPTRcovariant   = 2,       // need covariant return pointer adjustment
}

struct mptr_t
{
    targ_short     MPd;
    targ_short     MPi;
    Symbol        *MPf;
    Symbol        *MPparent;    // immediate parent of this base class
                                //   in Smptrbase
    mptr_flags_t   MPflags;
}

@trusted
inout(mptr_t)* list_mptr(inout(list_t) lst) { return cast(inout(mptr_t)*) list_ptr(lst); }


/***********************************
 * Information gathered about externally defined template member functions,
 * member data, and member classes.
 */

struct TMF
{
    Classsym *stag;             // if !=NULL, this is the enclosing class
    token_t *tbody;             // tokens making it up
    token_t *to;                // pointer within tbody where we left off in
                                // template_function_decl()
    param_t *temp_arglist;      // template parameter list
    int member_class;           // 1: it's a member class

    // These are for member templates
    int castoverload;           // 1: it's a user defined cast
    char *name;                 // name of template (NULL if castoverload)
    int member_template;        // 0: regular template
                                // 1: member template
    param_t *temp_arglist2;     // if member template,
                                // then member's template parameter list

    param_t *ptal;              // if explicit specialization, this is the
                                // explicit template-argument-list
    Symbol *sclassfriend;       // if member function is a friend of class X,
                                // this is class X
    uint access_specifier;
}

/***********************************
 * Information gathered about primary member template explicit specialization.
 */

struct TME
{
    /* Given:
     *  template<> template<class T2> struct A<short>::B { };
     *  temp_arglist2 = <class T2>
     *  name = "B"
     *  ptal = <short>
     */
    param_t *ptal;              // explicit template-argument-list for enclosing
                                // template A
    Symbol *stempl;             // template symbol for B
}

/***********************************
 * Information gathered about nested explicit specializations.
 */

struct TMNE
{
    /* For:
     *  template<> template<> struct A<short>::B<double> { };
     */

    enum_TK tk;                 // TKstruct / TKclass / TKunion
    char *name;                 // name of template, i.e. "B"
    param_t *ptal;              // explicit template-argument-list for enclosing
                                // template A, i.e. "short"
    token_t *tdecl;             // the tokens "<double> { }"
}

/***********************************
 * Information gathered about nested class friends.
 */

struct TMNF
{
    /* Given:
     *  template<class T> struct A { struct B { }; };
     *  class C { template<class T> friend struct A<T>::B;
     */
    token_t *tdecl;             // the tokens "A<T>::B;"
    param_t *temp_arglist;      // <class T>
    Classsym *stag;             // the class symbol C
    Symbol *stempl;             // the template symbol A
}

/***********************************
 * Special information for class templates.
 */

struct template_t
{
    symlist_t     TMinstances;  // list of Symbols that are instances
    param_t*      TMptpl;       // template-parameter-list
    token_t*      TMbody;       // tokens making up class body
    uint TMsequence;            // sequence number at point of definition
    list_t TMmemberfuncs;       // templates for member functions (list of TMF's)
    list_t TMexplicit;          // list of TME's: primary member template explicit specializations
    list_t TMnestedexplicit;    // list of TMNE's: primary member template nested explicit specializations
    Symbol* TMnext;             // threaded list of template classes headed
                                // up by template_class_list
    enum_TK        TMtk;        // TKstruct, TKclass or TKunion
    int            TMflags;     // STRxxx flags

    Symbol* TMprimary;          // primary class template
    Symbol* TMpartial;          // next class template partial specialization
    param_t* TMptal;            // template-argument-list for partial specialization
                                // (NULL for primary class template)
    list_t TMfriends;           // list of Classsym's for which any instantiated
                                // classes of this template will be friends of
    list_t TMnestedfriends;     // list of TMNF's
    int TMflags2;               // !=0 means dummy template created by template_createargtab()
}

/***********************************
 * Special information for enums.
 */

alias enum_flags_t = uint;
enum
{
    SENnotagname  = 1,       // no tag name for enum
    SENforward    = 2,       // forward referenced enum
}

struct enum_t
{
    enum_flags_t SEflags;
    Symbol* SEalias;            // pointer to identifier E to use if
                                // enum was defined as:
                                //      typedef enum { ... } E;
    symlist_t SEenumlist;       // all members of enum
}

/***********************************
 * Special information for structs.
 */

alias struct_flags_t = uint;
enum
{
    STRanonymous     = 1,          // set for unions with no tag names
    STRglobal        = 2,          // defined at file scope
    STRnotagname     = 4,          // struct/class with no tag name
    STRoutdef        = 8,          // we've output the debug definition
    STRbitfields     = 0x10,       // set if struct contains bit fields
    STRabstract      = 0x20,       // abstract class
    STRbitcopy       = 0x40,       // set if operator=() is merely a bit copy
    STRanyctor       = 0x80,       // set if any constructors were defined
                                   // by the user
    STRnoctor        = 0x100,      // no constructors allowed
    STRgen           = 0x200,      // if struct is an instantiation of a
                                   // template class, and was generated by
                                   // that template
    STRvtblext       = 0x400,      // generate vtbl[] only when first member function
                                   // definition is encountered (see Fvtblgen)
    STRexport        = 0x800,      // all member functions are to be _export
    STRpredef        = 0x1000,     // a predefined struct
    STRunion         = 0x2000,     // actually, it's a union
    STRclass         = 0x4000,     // it's a class, not a struct
    STRimport        = 0x8000,     // imported class
    STRstaticmems    = 0x10000,    // class has static members
    STR0size         = 0x20000,    // zero sized struct
    STRinstantiating = 0x40000,    // if currently being instantiated
    STRexplicit      = 0x80000,    // if explicit template instantiation
    STRgenctor0      = 0x100000,   // need to gen X::X()
    STRnotpod        = 0x200000,   // struct is not POD
}

struct struct_t
{
    targ_size_t Sstructsize;    // size of struct
    symlist_t Sfldlst;          // all members of struct (list freeable)
    Symbol *Sroot;              // root of binary tree Symbol table
    uint Salignsize;            // size of struct for alignment purposes
    ubyte Sstructalign;         // struct member alignment in effect
    struct_flags_t Sflags;
    tym_t ptrtype;              // type of pointer to refer to classes by
    ushort access;              // current access privilege, here so
                                // enum declarations can get at it
    targ_size_t Snonvirtsize;   // size of struct excluding virtual classes
    list_t Svirtual;            // freeable list of mptrs
                                // that go into vtbl[]
    list_t *Spvirtder;          // pointer into Svirtual that points to start
                                // of virtual functions for this (derived) class
    symlist_t Sopoverload;      // overloaded operator funcs (list freeable)
    symlist_t Scastoverload;    // overloaded cast funcs (list freeable)
    symlist_t Sclassfriends;    // list of classes of which this is a friend
                                // (list is freeable)
    symlist_t Sfriendclass;     // classes which are a friend to this class
                                // (list is freeable)
    symlist_t Sfriendfuncs;     // functions which are a friend to this class
                                // (list is freeable)
    symlist_t Sinlinefuncs;     // list of tokenized functions
    baseclass_t *Sbase;         // list of direct base classes
    baseclass_t *Svirtbase;     // list of all virtual base classes
    baseclass_t *Smptrbase;     // list of all base classes that have
                                // their own vtbl[]
    baseclass_t *Sprimary;      // if not NULL, then points to primary
                                // base class
    Funcsym *Svecctor;          // constructor for use by vec_new()
    Funcsym *Sctor;             // constructor function

    Funcsym *Sdtor;             // basic destructor
    Funcsym *Sprimdtor;         // primary destructor
    Funcsym *Spriminv;          // primary invariant
    Funcsym *Sscaldeldtor;      // scalar deleting destructor

    Funcsym *Sinvariant;        // basic invariant function

    Symbol *Svptr;              // Symbol of vptr
    Symbol *Svtbl;              // Symbol of vtbl[]
    Symbol *Svbptr;             // Symbol of pointer to vbtbl[]
    Symbol *Svbptr_parent;      // base class for which Svbptr is a member.
                                // NULL if Svbptr is a member of this class
    targ_size_t Svbptr_off;     // offset of Svbptr member
    Symbol *Svbtbl;             // virtual base offset table
    baseclass_t *Svbptrbase;    // list of all base classes in canonical
                                // order that have their own vbtbl[]
    Funcsym *Sopeq;             // X& X::operator =(X&)
    Funcsym *Sopeq2;            // Sopeq, but no copy of virtual bases
    Funcsym *Scpct;             // copy constructor
    Funcsym *Sveccpct;          // vector copy constructor
    Symbol *Salias;             // pointer to identifier S to use if
                                // struct was defined as:
                                //      typedef struct { ... } S;

    Symbol *Stempsym;           // if this struct is an instantiation
                                // of a template class, this is the
                                // template class Symbol

    // For 64 bit Elf function ABI
    type *Sarg1type;
    type *Sarg2type;

    /* For:
     *  template<class T> struct A { };
     *  template<class T> struct A<T *> { };
     *
     *  A<int> a;               // primary
     * Gives:
     *  Sarglist = <int>
     *  Spr_arglist = NULL;
     *
     *  A<int*> a;              // specialization
     * Gives:
     *  Sarglist = <int>
     *  Spr_arglist = <int*>;
     */

    param_t *Sarglist;          // if this struct is an instantiation
                                // of a template class, this is the
                                // actual arg list used
    param_t *Spr_arglist;       // if this struct is an instantiation
                                // of a specialized template class, this is the
                                // actual primary arg list used.
                                // It is NULL for the
                                // primary template class (since it would be
                                // identical to Sarglist).
}

/**********************************
 * Symbol Table
 */

@trusted
inout(Symbol)* list_symbol(inout list_t lst) { return cast(inout(Symbol)*) list_ptr(lst); }

@trusted
void list_setsymbol(list_t lst, Symbol* s) { lst.ptr = s; }

@trusted
inout(Classsym)* list_Classsym(inout list_t lst) { return cast(inout(Classsym)*) list_ptr(lst); }

enum
{
    SFLvalue        = 1,           // Svalue contains const expression
    SFLimplem       = 2,           // if seen implementation of Symbol
                                   // (function body for functions,
                                   // initializer for variables)
    SFLdouble       = 2,           // SCregpar or SCparameter, where float
                                   // is really passed as a double
    SFLfree         = 4,           // if we can symbol_free() a Symbol in
                                   // a Symbol table[]
    SFLmark         = 8,           // temporary marker
    SFLexit         = 0x10,        // tyfunc: function does not return
                                   // (ex: exit,abort,_assert,longjmp)
    SFLtrue         = 0x200,       // value of Symbol != 0
    SFLreplace      = SFLmark,     // variable gets replaced in inline expansion
    SFLskipinit     = 0x10000,     // SCfield, SCmember: initializer is skipped
    SFLnodebug      = 0x20000,     // don't generate debug info
    SFLwasstatic    = 0x800000,    // was an uninitialized static
    SFLweak         = 0x1000000,   // resolve to NULL if not found
    SFLhidden       = 0x2000000,   // not visible outside of DSOs (-fvisibility=hidden)
    SFLartifical    = 0x4000000,   // compiler generated symbol

    // CPP
    SFLnodtor       = 0x10,        // set if destructor for Symbol is already called
    SFLdtorexp      = 0x80,        // Svalue has expression to tack onto dtor
    SFLmutable      = 0x100000,    // SCmember or SCfield is mutable
    SFLdyninit      = 0x200000,    // symbol has dynamic initializer
    SFLtmp          = 0x400000,    // symbol is a generated temporary
    SFLthunk        = 0x40000,     // symbol is temporary for thunk

    // Possible values for visibility bits
    SFLprivate      = 0x60,
    SFLprotected    = 0x40,
    SFLpublic       = 0x20,
    SFLnone         = 0x00,
    SFLpmask        = 0x60,        // mask for the visibility bits

    SFLvtbl         = 0x2000,      // VEC_VTBL_LIST: Symbol is a vtable or vbtable

    // OPTIMIZER and CODGEN
    GTregcand       = 0x100,       // if Symbol is a register candidate
    SFLdead         = 0x800,       // this variable is dead
    GTunregister    = 0x8000000,   // 'unregister' a previous register assignment

    // OPTIMIZER only
    SFLunambig      = 0x400,       // only accessible by unambiguous reference,
                                   // i.e. cannot be addressed via pointer
                                   // (GTregcand is a subset of this)
                                   // P.S. code generator turns off this
                                   // flag if any reads are done from it.
                                   // This is to eliminate stores to it
                                   // that are never read.
    SFLlivexit      = 0x1000,      // live on exit from function
    SFLnotbasiciv   = 0x4000,      // not a basic induction variable
    SFLnord         = SFLdouble,   // SCauto,SCregister,SCtmp: disallow redundant warnings

    // CODGEN only
    GTtried         = SFLmark,     // tried to place in register
    GTbyte          = 0x8000,      // variable is sometimes accessed as
    SFLread         = 0x40000,     // variable is actually read from
                                   // (to eliminate dead stores)
    SFLspill        = 0x80000,     // only in register part of the time
}

struct Symbol
{
//#ifdef DEBUG
    debug ushort      id;
    enum IDsymbol = 0x5678;
//#define class_debug(s) assert((s)->id == IDsymbol)
//#else
//#define class_debug(s)
//#endif

    nothrow:

    Symbol* Sl, Sr;             // left, right child
    Symbol* Snext;              // next in threaded list
    dt_t* Sdt;                  // variables: initializer
    int Salignment;             // variables: alignment, 0 or -1 means default alignment

    int Salignsize()            // variables: return alignment
    { return Symbol_Salignsize(&this); }

    type* Stype;                // type of Symbol
    tym_t ty() const { return Stype.Tty; }

    union                       // variants for different Symbol types
    {
        enum_t* Senum;          // SCenum

        struct
        {
             func_t* Sfunc;     // tyfunc
             list_t Spath1;     // SCfuncalias member functions: same as Spath
                                // and in same position
                                // SCadl: list of associated functions for ADL lookup
        }

        struct                  // SClabel
        {
            int Slabel;         // TRUE if label was defined
            block* Slabelblk_;  // label block
        }

        //#define Senumlist Senum->SEenumlist

        version (SCPP)
        {
            struct               // SClinkage
            {
                uint Slinkage;   // tym linkage bits
                uint Smangle;
            }
        }

        version (HTOD)
        {
            struct               // SClinkage
            {
                uint Slinkage;   // tym linkage bits
                uint Smangle;
            }
        }

        struct
        {
            ubyte Sbit;         // SCfield: bit position of start of bit field
            ubyte Swidth;       // SCfield: width in bits of bit field
            targ_size_t Smemoff; // SCmember,SCfield: offset from start of struct
        }

        elem* Svalue;           /* SFLvalue: value of const
                                   SFLdtorexp: for objects with destructor,
                                   conditional expression to precede dtor call
                                 */

        struct_t* Sstruct;      // SCstruct
        template_t* Stemplate;  // SCtemplate

        version (SCPP)
        {
            struct                  // SCnamespace
            {
                Symbol* Snameroot;  // the Symbol table for the namespace
                list_t Susing;      // other namespaces from using-directives
            }
            struct
            {
                Symbol* Smemalias;  // SCalias: pointer to Symbol to use instead
                                    // (generated by using-declarations and
                                    // namespace-alias-definitions)
                                    // SCmemalias: pointer to member of base class
                                    // to use instead (using-declarations)
                symlist_t Spath;    // SCmemalias: path of classes to get to base
                                    // class of which Salias is a member
            }
            Symbol* Simport ;       // SCextern: if dllimport Symbol, this is the
                                    // Symbol it was imported from
        }
        version (HTOD)
        {
            struct                  // SCnamespace
            {
                Symbol* Snameroot;  // the Symbol table for the namespace
                list_t Susing;      // other namespaces from using-directives
            }
            struct
            {
                Symbol* Smemalias;  // SCalias: pointer to Symbol to use instead
                                    // (generated by using-declarations and
                                    // namespace-alias-definitions)
                                    // SCmemalias: pointer to member of base class
                                    // to use instead (using-declarations)
                symlist_t Spath;    // SCmemalias: path of classes to get to base
                                    // class of which Salias is a member
            }
            Symbol* Simport ;       // SCextern: if dllimport Symbol, this is the
                                    // Symbol it was imported from
        }

        struct                  // SCfastpar, SCshadowreg
        {
            reg_t Spreg;        // register parameter is passed in
            reg_t Spreg2;       // if 2 registers, this is the most significant, else NOREG
        }
    }

    regm_t Spregm()             // return mask of Spreg and Spreg2
    {
        return (1 << Spreg) | (Spreg2 == NOREG ? 0 : (1 << Spreg2));
    }

//#if SCPP || MARS
    Symbol *Sscope;             // enclosing scope (could be struct tag,
                                // enclosing inline function for statics,
                                // or namespace)
//#endif

    version (SCPP)
    {
        Symbol *Scover;             // if there is a tag name and a regular name
                                    // of the same identifier, Scover is the tag
                                    // Scover can be SCstruct, SCenum, SCtemplate
                                    // or an SCalias to them.
        uint Ssequence;             // sequence number (used for 2 level lookup)
                                    // also used as 'parameter number' for SCTtemparg
    }
    version (HTOD)
    {
        Symbol *Scover;             // if there is a tag name and a regular name
                                    // of the same identifier, Scover is the tag
                                    // Scover can be SCstruct, SCenum, SCtemplate
                                    // or an SCalias to them.
        uint Ssequence;             // sequence number (used for 2 level lookup)
                                    // also used as 'parameter number' for SCTtemparg
    }
    version (MARS)
    {
        const(char)* prettyIdent;   // the symbol identifier as the user sees it
    }

//#if TARGET_OSX
    targ_size_t Slocalgotoffset;
//#endif

    enum_SC Sclass;             // storage class (SCxxxx)
    char Sfl;                   // flavor (FLxxxx)
    SYMFLGS Sflags;             // flag bits (SFLxxxx)

    vec_t       Srange;         // live range, if any
    vec_t       Slvreg;         // when symbol is in register
    targ_size_t Ssize;          // tyfunc: size of function
    targ_size_t Soffset;        // variables: offset of Symbol in its storage class

    // CPP || OPTIMIZER
    SYMIDX Ssymnum;             // Symbol number (index into globsym[])
                                // SCauto,SCparameter,SCtmp,SCregpar,SCregister
    // CODGEN
    int Sseg;                   // segment index
    int Sweight;                // usage count, the higher the number,
                                // the more worthwhile it is to put in
                                // a register
    int Sdw_ref_idx;            // !=0 means index of DW.ref.name symbol (Dwarf EH)

    union
    {
        uint Sxtrnnum;          // SCcomdef,SCextern,SCcomdat: external symbol # (starting from 1)
        uint Stypidx;           // SCstruct,SCunion,SCclass,SCenum,SCtypedef: debug info type index
        struct
        {
            ubyte Sreglsw;
            ubyte Sregmsw;
          regm_t Sregm;         // mask of registers
        }                       // SCregister,SCregpar,SCpseudo: register number
    }
    regm_t      Sregsaved;      // mask of registers not affected by this func

    uint lnoscopestart;         // life time of var
    uint lnoscopeend;           // the line after the scope

    /**
     * Identifier for this symbol
     *
     * Note that this is used as a flexible array member.
     * When allocating a Symbol, the allocation is for
     * `sizeof(Symbol - 1 + strlen(identifier) + "\0".length)`.
     */
    char[1] Sident;

    int needThis()              // !=0 if symbol needs a 'this' pointer
    { return Symbol_needThis(&this); }

    bool Sisdead(bool anyiasm)  // if variable is not referenced
    { return Symbol_Sisdead(&this, anyiasm); }
}

void symbol_debug(const Symbol* s)
{
    debug assert(s.id == s.IDsymbol);
}

int Symbol_Salignsize(Symbol* s);
bool Symbol_Sisdead(const Symbol* s, bool anyInlineAsm);
int Symbol_needThis(const Symbol* s);
bool Symbol_isAffected(const ref Symbol s);

bool isclassmember(const Symbol* s) { return s.Sscope && s.Sscope.Sclass == SCstruct; }

// Class, struct or union

alias Classsym = Symbol;

// Namespace Symbol
alias Nspacesym = Symbol;

// Alias for another Symbol
alias Aliassym = Symbol;

// Function symbol
//alias Funcsym = Symbol;

// Determine if this Symbol is stored in a COMDAT
//#if MARS
//#define symbol_iscomdat(s)      ((s)->Sclass == SCcomdat ||             \
//        config.flags2 & CFG2comdat && (s)->Sclass == SCinline ||        \
//        config.flags4 & CFG4allcomdat && ((s)->Sclass == SCglobal))
//#else
//#define symbol_iscomdat(s)      ((s)->Sclass == SCcomdat ||             \
//        config.flags2 & CFG2comdat && (s)->Sclass == SCinline ||        \
//        config.flags4 & CFG4allcomdat && ((s)->Sclass == SCglobal || (s)->Sclass == SCstatic))
//#endif

/* Format the identifier for presentation to the user   */
version (SCPP)
{
    const(char)* cpp_prettyident (const Symbol *s);
    const(char)* prettyident(const Symbol *s) { return CPP ? cpp_prettyident(s) : &s.Sident[0]; }
}

version (SPP)
{
    const(char)* cpp_prettyident (const Symbol *s);
    const(char)* prettyident(const Symbol *s) { return &s.Sident[0]; }
}

version (HTOD)
{
    const(char)* cpp_prettyident (const Symbol *s);
    const(char)* prettyident(const Symbol *s) { return &s.Sident[0]; }
}

version (MARS)
    const(char)* prettyident(const Symbol *s) { return &s.Sident[0]; }


/**********************************
 * Function parameters:
 *      Pident          identifier of parameter
 *      Ptype           type of argument
 *      Pelem           default value for argument
 *      Psym            symbol corresponding to Pident when using the
 *                      parameter list as a symbol table
 * For template-parameter-list:
 *      Pident          identifier of parameter
 *      Ptype           if NULL, this is a type-parameter
 *                      else the type for a parameter-declaration value argument
 *      Pelem           default value for value argument
 *      Pdeftype        default value for type-parameter
 *      Pptpl           template-parameter-list for template-template-parameter
 *      Psym            default value for template-template-parameter
 * For template-arg-list: (actual arguments)
 *      Pident          NULL
 *      Ptype           type-name
 *      Pelem           expression (either Ptype or Pelem is NULL)
 *      Psym            SCtemplate for template-template-argument
 */

alias pflags_t = uint;
enum
{
    PFexplicit = 1,       // this template argument was explicit, i.e. in < >
}

/************************
 * Params:
 *      f = function symbol
 * Returns:
 *      exception method for f
 */
@trusted
EHmethod ehmethod(Symbol *f)
{
    return f.Sfunc.Fflags3 & Feh_none ? EHmethod.EH_NONE : config.ehmethod;
}


struct param_t
{
nothrow:
    debug ushort      id;
    enum IDparam = 0x7050;

    char* Pident;               // identifier
    type* Ptype;                // type of parameter (NULL if not known yet)
    elem* Pelem;                // default value
    token_t* PelemToken;        // tokens making up default elem
    type* Pdeftype;             // Ptype==NULL: default type for type-argument
    param_t* Pptpl;             // template-parameter-list for template-template-parameter
    Symbol* Psym;
    param_t* Pnext;             // next in list
    pflags_t Pflags;

    param_t* createTal(param_t* p) // create template-argument-list blank from
                                // template-parameter-list
    { return param_t_createTal(&this, p); }

    param_t* search(char* id)   // look for Pident matching id
    { return param_t_search(&this, id); }

    int searchn(char* id);      // look for Pident matching id, return index

    uint length()               // number of parameters in list
    { return param_t_length(&this); }

    void print()                // print this param_t
    { param_t_print(&this); }

    void print_list()           // print this list of param_t's
    { param_t_print_list(&this); }
}

void param_t_print(const param_t* p);
void param_t_print_list(param_t* p);
uint param_t_length(param_t* p);
param_t *param_t_createTal(param_t* p, param_t *ptali);
param_t *param_t_search(param_t* p, char *id);
int param_t_searchn(param_t* p, char *id);


void param_debug(const param_t *p)
{
    debug assert(p.id == p.IDparam);
}

/**************************************
 * Element types.
 * These should be combined with storage classes.
 */

alias FL = int;
enum
{
    // Change this, update debug.c too
    FLunde,
    FLconst,        // numerical constant
    FLoper,         // operator node
    FLfunc,         // function symbol
    FLdata,         // ref to data segment variable
    FLreg,          // ref to register variable
    FLpseudo,       // pseuodo register variable
    FLauto,         // ref to automatic variable
    FLfast,         // ref to variable passed as register
    FLpara,         // ref to function parameter variable
    FLextern,       // ref to external variable
    FLcode,         // offset to code
    FLblock,        // offset to block
    FLudata,        // ref to udata segment variable
    FLcs,           // ref to common subexpression number
    FLswitch,       // ref to offset of switch data block
    FLfltreg,       // ref to floating reg on stack, int contains offset
    FLoffset,       // offset (a variation on constant, needed so we
                    // can add offsets (different meaning for FLconst))
    FLdatseg,       // ref to data segment offset
    FLctor,         // constructed object
    FLdtor,         // destructed object
    FLregsave,      // ref to saved register on stack, int contains offset
    FLasm,          // (code) an ASM code

    FLndp,          // saved 8087 register

    // Segmented systems
    FLfardata,      // ref to far data segment
    FLcsdata,       // ref to code segment variable

    FLlocalsize,    // replaced with # of locals in the stack frame
    FLtlsdata,      // thread local storage
    FLbprel,        // ref to variable at fixed offset from frame pointer
    FLframehandler, // ref to C++ frame handler for NT EH
    FLblockoff,     // address of block
    FLallocatmp,    // temp for built-in alloca()
    FLstack,        // offset from ESP rather than EBP
    FLdsymbol,      // it's a Dsymbol

    // Global Offset Table
    FLgot,          // global offset table entry outside this object file
    FLgotoff,       // global offset table entry inside this object file

    FLfuncarg,      // argument to upcoming function call

    FLMAX
}

////////// Srcfiles

version (MARS)
{
}
else
{
// Collect information about a source file.
alias sfile_flags_t = uint;
enum
{
    SFonce    = 1,      // file is to be #include'd only once
    SFhx      = 2,      // file is in an HX file and has not been loaded
    SFtop     = 4,      // file is a top level source file
    SFloaded  = 8,      // read from PH file
}

private import parser : macro_t;

struct Sfile
{
    debug ushort      id;
    enum IDsfile = (('f' << 8) | 's');

    char     *SFname;           // name of file
    sfile_flags_t  SFflags;
    list_t    SFfillist;        // file pointers of Sfile's that this Sfile is
                                //     dependent on (i.e. they were #include'd).
                                //     Does not include nested #include's
    macro_t  *SFmacdefs;        // threaded list of macros #defined by this file
    macro_t **SFpmacdefs;       // end of macdefs list
    Symbol   *SFsymdefs;        // threaded list of global symbols declared by this file
    symlist_t SFcomdefs;        // comdefs defined in PH
    symlist_t SFtemp_ft;        // template_ftlist
    symlist_t SFtemp_class;     // template_class_list
    Symbol   *SFtagsymdefs;     // list of tag names (C only)
    char     *SFinc_once_id;    // macro include guard identifier
    uint SFhashval;             // hash of file name
}

void sfile_debug(const Sfile* sf)
{
    debug assert(sf.id == Sfile.IDsfile);
}

// Source files are referred to by a pointer into pfiles[]. This is so that
// when PH files are hydrated, only pfiles[] needs updating. Of course, this
// means that pfiles[] cannot be reallocated to larger numbers, its size is
// fixed at SRCFILES_MAX.

version (SPP)
{
    enum SRCFILES_MAX = (2*512*4);      // no precompiled headers for SPP
}
else
{
    enum SRCFILES_MAX = (2*512);
}

struct Srcfiles
{
//  Sfile *arr;         // array of Sfiles
    Sfile **pfiles;     // parallel array of pointers into arr[]
    uint dim;       // dimension of array
    uint idx;       // # used in array
}

Sfile* sfile(uint fi)
{
    import dmd.backend.global : srcfiles;
    return srcfiles.pfiles[fi];
}

char* srcfiles_name(uint fi) { return sfile(fi).SFname; }
}

/**************************************************
 * This is to support compiling expressions within the context of a function.
 */

struct EEcontext
{
    uint EElinnum;              // line number to insert expression
    char *EEexpr;               // expression
    char *EEtypedef;            // typedef identifier
    byte EEpending;             // !=0 means we haven't compiled it yet
    byte EEimminent;            // we've installed it in the source text
    byte EEcompile;             // we're compiling for the EE expression
    byte EEin;                  // we are parsing an EE expression
    elem *EEelem;               // compiled version of EEexpr
    Symbol *EEfunc;             // function expression is in
    code *EEcode;               // generated code
}

extern __gshared EEcontext eecontext;


// Different goals for el_optimize()
alias goal_t = uint;
enum
{
    GOALnone        = 0,       // evaluate for side effects only
    GOALvalue       = 1,       // evaluate for value
    GOALflags       = 2,       // evaluate for flags
    GOALagain       = 4,
    GOALstruct      = 8,
    GOALhandle      = 0x10,    // don't replace handle'd objects
    GOALignore_exceptions = 0x20, // ignore floating point exceptions
}

/* Globals returned by declar() */
struct Declar
{
    Classsym *class_sym;
    Nspacesym *namespace_sym;
    int oper;
    bool constructor;
    bool destructor;
    bool _invariant;
    param_t *ptal;
    bool explicitSpecialization;
    int hasExcSpec;             // has exception specification
}

extern __gshared Declar gdeclar;

/**********************************
 * Data definitions
 *      DTibytes        1..7 bytes
 *      DTabytes        offset of bytes of data
 *                      a { a data bytes }
 *      DTnbytes        bytes of data
 *                      a { a data bytes }
 *                      a = offset
 *      DTazeros        # of 0 bytes
 *                      a
 *      DTsymsize       same as DTazeros, but the type of the symbol gives
 *                      the size
 *      DTcommon        # of 0 bytes (in a common block)
 *                      a
 *      DTxoff          offset from symbol
 *                      w a
 *                      w = symbol number (pointer for CPP)
 *                      a = offset
 *      DTcoff          offset into code segment
 */

struct dt_t
{
    dt_t *DTnext;                       // next in list
    char dt;                            // type (DTxxxx)
    ubyte Dty;                          // pointer type
    ubyte DTn;                          // DTibytes: number of bytes
    ubyte DTalign;                      // DTabytes: alignment (as power of 2) of pointed-to data
    union
    {
        struct                          // DTibytes
        {
            enum DTibytesMax = (char*).sizeof + uint.sizeof + int.sizeof + targ_size_t.sizeof;
            byte[DTibytesMax] DTdata;   // data
        }
        targ_size_t DTazeros;           // DTazeros,DTcommon,DTsymsize
        struct                          // DTabytes
        {
            byte *DTpbytes;             // pointer to the bytes
            uint DTnbytes;              // # of bytes
            int DTseg;                  // segment it went into
            targ_size_t DTabytes;       // offset of abytes for DTabytes
        }
        struct                          // DTxoff
        {
            Symbol *DTsym;              // symbol pointer
            targ_size_t DToffset;       // offset from symbol
        }
    }
}

enum
{
    DT_abytes = 0,
    DT_azeros = 1,
    DT_xoff   = 2,
    DT_nbytes = 3,
    DT_common = 4,
    DT_coff   = 5,
    DT_ibytes = 6,
}

// An efficient way to clear aligned memory
//#define MEMCLEAR(p,sz)                  \
//    if ((sz) == 10 * sizeof(size_t))    \
//    {                                   \
//        ((size_t *)(p))[0] = 0;         \
//        ((size_t *)(p))[1] = 0;         \
//        ((size_t *)(p))[2] = 0;         \
//        ((size_t *)(p))[3] = 0;         \
//        ((size_t *)(p))[4] = 0;         \
//        ((size_t *)(p))[5] = 0;         \
//        ((size_t *)(p))[6] = 0;         \
//        ((size_t *)(p))[7] = 0;         \
//        ((size_t *)(p))[8] = 0;         \
//        ((size_t *)(p))[9] = 0;         \
//    }                                   \
//    else if ((sz) == 14 * sizeof(size_t))       \
//    {                                   \
//        ((size_t *)(p))[0] = 0;         \
//        ((size_t *)(p))[1] = 0;         \
//        ((size_t *)(p))[2] = 0;         \
//        ((size_t *)(p))[3] = 0;         \
//        ((size_t *)(p))[4] = 0;         \
//        ((size_t *)(p))[5] = 0;         \
//        ((size_t *)(p))[6] = 0;         \
//        ((size_t *)(p))[7] = 0;         \
//        ((size_t *)(p))[8] = 0;         \
//        ((size_t *)(p))[9] = 0;         \
//        ((size_t *)(p))[10] = 0;        \
//        ((size_t *)(p))[11] = 0;        \
//        ((size_t *)(p))[12] = 0;        \
//        ((size_t *)(p))[13] = 0;        \
//    }                                   \
//    else                                \
//    {                                   \
//        /*printf("%s(%d) sz = %d\n",__FILE__,__LINE__,(sz));fflush(stdout);*(char*)0=0;*/  \
//        for (size_t i = 0; i < sz / sizeof(size_t); ++i)        \
//            ((size_t *)(p))[i] = 0;                             \
//    }
