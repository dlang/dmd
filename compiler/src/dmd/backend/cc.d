/**
 * Common definitions
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/cc.d, backend/_cc.d)
 */

module dmd.backend.cc;

// Online documentation: https://dlang.org/phobos/dmd_backend_cc.html

import dmd.backend.barray;
import dmd.backend.cdef;        // host and target compiler definition
import dmd.backend.x86.code_x86;
import dmd.backend.dlist;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.symtab;
import dmd.backend.type;

@nogc:
nothrow:
@safe:

uint mskl(uint i) { return 1 << i; }     // convert int to mask

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

enum IDMAX = 900;              // identifier max (excluding terminating 0)
enum IDOHD = 4+1+int.sizeof*3; // max amount of overhead to ID added by

struct token_t;

alias Funcsym = Symbol;

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
    uint Scharnum;          // 0 means no info available

    const(char)* Sfilename;

    const(char*) name() const { return Sfilename; }

    static Srcpos create(const(char)* filename, uint linnum, uint charnum)
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

    void print(const(char)* func) const { Srcpos_print(this, func); }
}

import dmd.backend.dout : Srcpos_print;

/**********************************
 * Current 'state' of the compiler.
 * Used to gather together most global variables.
 * This struct is saved/restored during function body parsing.
 */

struct Pstate
{
    ubyte STinsizeof;           // !=0 if in a sizeof expression. Useful to
                                // prevent <array of> being converted to
                                // <pointer to>.

    Funcsym* STfuncsym_p;       // if inside a function, then this is the
                                // function Symbol.
}

@trusted
void funcsym_p(Funcsym* fp) { pstate.STfuncsym_p = fp; }

@trusted
Funcsym* funcsym_p() { return pstate.STfuncsym_p; }

public import dmd.backend.var : pstate, cstate;

/****************************
 * Global variables.
 */

struct Cstate
{
    symtab_t* CSpsymtab;        // pointer to current Symbol table
}

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
//char symbol_isintab(Symbol* s) { return sytab[s.Sclass] & SCSS; }

/******************************************
 * Basic blocks:
 *      Basic blocks are a linked list of all the basic blocks
 *      in a function. startblock heads the list.
 */

alias ClassDeclaration_ = void*;
alias Declaration_ = void*;
alias Module_ = void*;

/*************************************
 * While constructing a block list, BlockState maintains
 * the global state needed to construct that list.
 */
struct BlockState
{
    block* startblock;          // first block in the block list
    block* curblock;            // the current (i.e. last) block in the list
    Funcsym* funcsym;           // the function the blocks form the function body of
    Symbol* context;            // eh (exception handling) frame context variable
    int scope_index;            // current scope index
    int next_index;             // value for next scope index
    BFL flags;                  // value to OR into Bflags
    block* tryblock;            // current enclosing try block
    ClassDeclaration_ classdec;
    Declaration_ member;        // member we're compiling for
    Module_ _module;            // module we're in
}

enum BFL : ushort
{
    visited       = 1,      // set if block is visited
    mark          = 2,      // set if block is visited
    jmpoptdone    = 4,      // set when no more jump optimizations
                            //  are possible for this block
    nostackopt    = 8,      // set when stack elimination should not be done
    nomerg        = 0x10,   // do not merge with other blocks
    prolog        = 0x20,   // generate function prolog
    epilog        = 0x40,   // generate function epilog
    refparam      = 0x80,   // referenced parameter
    reflocal      = 0x100,  // referenced local
    outsideprolog = 0x200,  // outside function prolog/epilog
    label         = 0x400,  // block preceded by label
    volatile      = 0x800,  // block is volatile
    nounroll      = 0x1000, // do not unroll loop

    // for Windows NTEXCEPTIONS
    ehcode        = 0x2000, // BC._filter: need to load exception code
    unwind        = 0x4000, // do local_unwind following block (unused)
}

struct block
{
nothrow:
    union
    {
        elem* Belem;            // pointer to elem tree
        list_t  Blist;          // list of expressions
    }

    block* Bnext;               // pointer to next block in list
    list_t Bsucc;               // linked list of pointers to successors
                                //     of this block
    list_t Bpred;               // and the predecessor list
    int Bindex;                 // into created object stack
    int Bendindex;              // index at end of block
    block* Btry;                // BC.try_,BC._try: enclosing try block, if any
                                // BC???: if in try-block, points to BC.try_ or BC._try
                                // note that can't have a BC.try_ and BC._try in
                                // the same function.
    union
    {
        long[] Bswitch;                // BC.switch_: case expression values

        struct
        {
            regm_t usIasmregs;         // Registers modified
            ubyte bIasmrefparam;       // References parameters?
        }

        struct
        {
            Symbol* catchvar;           // __throw() fills in this
        }                               // BC.try_

        struct
        {
            Symbol* Bcatchtype;       // one type for each catch block
            Barray!uint* actionTable; // EH_DWARF: indices into typeTable
        }                             // BC.jcatch

        struct
        {
            Symbol* jcatchvar;      // __d_throw() fills in this
            int Bscope_index;           // index into scope table
            int Blast_index;            // enclosing index into scope table
        }                               // BC._try

        struct
        {
            Symbol* flag;               // EH_DWARF: set to 'flag' symbol that encloses finally
            block* b_ret;               // EH_DWARF: associated BC._ret block
        }                               // finally

        // add member mimicking the largest of the other elements of this union, so it can be copied
        struct _BS { Symbol* jcvar; int Bscope_idx, Blast_idx; }
        _BS BS;
    }
    Srcpos      Bsrcpos;        // line number (0 if not known)
    BC          bc;             // exit condition

    ubyte       Balign;         // alignment

    BFL         Bflags;         // flags (BFLxxxx)
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
            block*      Bgotolist;      // BC.try_, BC.catch_: backward list of try scopes
            block*      Bgotothread;    // BC.goto_: threaded list of goto's to
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

            // BC.iftrue can have different vectors for the 2nd successor:
            vec_t       Bout2;
            vec_t       Bgen2;
            vec_t       Bkill2;
        }

        // CODGEN
        struct
        {
            // For BC.switch_, BC.jmptab
            targ_size_t Btablesize;     // size of generated table
            targ_size_t Btableoffset;   // offset to start of table
            targ_size_t Btablebase;     // offset to instruction pointer base

            targ_size_t Boffset;        // code offset of start of this block
            targ_size_t Bsize;          // code size of this block
            con_t       Bregcon;        // register state at block exit
            targ_size_t Btryoff;        // BC.try_: offset of try block data
        }
    }

    @trusted
    void appendSucc(block* b)        { list_append(&this.Bsucc, b); }

    @trusted
    void prependSucc(block* b)       { list_prepend(&this.Bsucc, b); }

    int numSucc()                    { return list_nitems(this.Bsucc); }

    @trusted
    block* nthSucc(int n)            { return cast(block*)list_ptr(list_nth(Bsucc, n)); }

    @trusted
    void setNthSucc(int n, block* b) { list_nth(Bsucc, n).ptr = b; }
}

@trusted
inout(block)* list_block(inout list_t lst) { return cast(inout(block)*)list_ptr(lst); }

/** Basic block control flow operators. **/

enum BC : ubyte
{
    none      = 0,
    goto_     = 1,    // goto Bsucc block
    iftrue    = 2,    // if (Belem) goto Bsucc[0] else Bsucc[1]
    ret       = 3,    // return (no return value)
    retexp    = 4,    // return with return value
    exit      = 5,    // never reaches end of block (like exit() was called)
    asm_      = 6,    // inline assembler block (Belem is NULL, Bcode
                      // contains code generated).
                      // These blocks have one or more successors in Bsucc,
                      // never 0
    switch_   = 7,    // switch statement
                        // Bswitch points to switch data
                        // Default is Bsucc
                        // Cases follow in linked list
    ifthen    = 8,    // a BC.switch_ is converted to if-then
                        // statements
    jmptab    = 9,    // a BC.switch_ is converted to a jump
                        // table (switch value is index into
                        // the table)
    try_      = 10,   // C++ try block
                        // first block in a try-block. The first block in
                        // Bsucc is the next one to go to, subsequent
                        // blocks are the catch blocks
    catch_    = 11,   // C++ catch block
    jump      = 12,   // Belem specifies (near) address to jump to
    _try      = 13,   // SEH: first block of try-except or try-finally
                        // D: try-catch or try-finally
    _filter   = 14,   // SEH exception-filter (always exactly one block)
    _finally  = 15,   // first block of SEH termination-handler,
                        // or D finally block
    _ret      = 16,   // last block of SEH termination-handler or D _finally block
    _except   = 17,   // first block of SEH exception-handler
    jcatch    = 18,   // D catch block
    _lpad     = 19,   // EH_DWARF: landing pad for BC._except
}

/********************************
 * Range for blocks.
 */
struct BlockRange
{
  pure nothrow @nogc:

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
    Fmain            = 0x800,   // function is D main
    Fnested          = 0x1000,  // D nested function with 'this'
    Fmember          = 0x2000,  // D member function with 'this'
    Fnotailrecursion = 0x4000,  // no tail recursion optimizations
    Ffakeeh          = 0x8000,  // allocate space for NT EH context sym anyway
    Fnothrow         = 0x10000, // function does not throw (even if not marked 'nothrow')
    Feh_none         = 0x20000, // ehmethod==EH_NONE for this function only
    F3hiddenPtr      = 0x40000, // function has hidden pointer to return value
    F3safe           = 0x80000, // function is @safe
}

struct func_t
{
    symlist_t Fsymtree;         // local Symbol table
    block* Fstartblock;         // list of blocks comprising function
    symtab_t Flocsym;           // local Symbol table
    Srcpos Fstartline;          // starting line # of function
    Srcpos Fendline;            // line # of closing brace of function
    Symbol* F__func__;          // symbol for __func__[] string
    func_flags_t Fflags;
    func_flags3_t Fflags3;
    ubyte Foper;                // operator number (OPxxxx) if Foperator

    Symbol* Fparsescope;        // use this scope to parse friend functions
                                // which are defined within a class, so the
                                // class is in scope, but are not members
                                // of the class

    Classsym* Fclass;           // if member of a class, this is the class
                                // (I think this is redundant with Sscope)
    Funcsym* Foversym;          // overloaded function at same scope
    symlist_t Fclassfriends;    // Symbol list of classes of which this
                                // function is a friend
    block* Fbaseblock;          // block where base initializers get attached
    block* Fbaseendblock;       // block where member destructors get attached
    elem* Fbaseinit;            // list of member initializers (meminit_t)
                                // this field has meaning only for
                                // functions which are constructors
    token_t* Fbody;             // if deferred parse, this is the list
                                // of tokens that make up the function
                                // body
                                // also used if SCfunctempl, SCftexpspec
    uint Fsequence;             // sequence number at point of definition
    Symbol* Ftempl;         // if Finstance this is the template that generated it
    Funcsym* Falias;            // SCfuncalias: function Symbol referenced
                                // by using-declaration
    symlist_t Fthunks;          // list of thunks off of this function
    param_t* Farglist;          // SCfunctempl: the template-parameter-list
    param_t* Fptal;             // Finstance: this is the template-argument-list
                                // SCftexpspec: for explicit specialization, this
                                // is the template-argument-list
    list_t Ffwdrefinstances;    // SCfunctempl: list of forward referenced instances
    list_t Fexcspec;            // List of types in the exception-specification
                                // (NULL if none or empty)
    Funcsym* Fexplicitspec;     // SCfunctempl, SCftexpspec: threaded list
                                // of SCftexpspec explicit specializations
    Funcsym* Fsurrogatesym;     // Fsurrogate: surrogate cast function

    char* Fredirect;            // redirect function name to this name in object

    // Array of catch types for EH_DWARF Types Table generation
    Barray!(Symbol*) typesTable;

    union
    {
        uint LSDAoffset;        // ELFOBJ: offset in LSDA segment of the LSDA data for this function
        Symbol* LSDAsym;        // MACHOBJ: GCC_except_table%d
    }
}

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
    Classsym*         BCparent;         // immediate parent of this base class
                                        //     in Smptrbase
    baseclass_t*      BCpbase;          // parent base, NULL if did not come from a parent
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
    Symbol* Sroot;              // root of binary tree Symbol table
    uint Salignsize;            // size of struct for alignment purposes
    ubyte Sstructalign;         // struct member alignment in effect
    struct_flags_t Sflags;
    tym_t ptrtype;              // type of pointer to refer to classes by
    baseclass_t* Sbase;         // list of direct base classes
    Symbol* Svptr;              // Symbol of vptr
    Symbol* Stempsym;           // if this struct is an instantiation
                                // of a template class, this is the
                                // template class Symbol

    // For 64 bit Elf function ABI
    type* Sarg1type;
    type* Sarg2type;

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

    param_t* Sarglist;          // if this struct is an instantiation
                                // of a template class, this is the
                                // actual arg list used
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
    SFLnounderscore = 0x8000_0000, // don't prepend an _ to identifiers in object file

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
    SFLimported     = 0x200000,    // symbol is in another DSO (D only, SFLdyninit unused)

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
    debug ushort      id;
    enum IDsymbol = 0x5678;

    nothrow:

    Symbol* Sl, Sr;             // left, right child
    Symbol* Snext;              // next in threaded list
    Symbol* Sisym;              // import version of this symbol
    dt_t* Sdt;                  // variables: initializer
    int Salignment;             // variables: alignment, 0 or -1 means default alignment

    int Salignsize()            // variables: return alignment
    { return Symbol_Salignsize(this); }

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

    Symbol* Sscope;             // enclosing scope (could be struct tag,
                                // enclosing inline function for statics,
                                // or namespace)

    const(char)* prettyIdent;   // the symbol identifier as the user sees it

//#if TARGET_OSX
    targ_size_t Slocalgotoffset;
//#endif

    SC Sclass;                  // storage class (SCxxxx)
    FL Sfl;                     // flavor (FL.xxxx)
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

    Srcpos lposscopestart;        // life time of var
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
    { return Symbol_needThis(this); }

    bool Sisdead(bool anyiasm)  // if variable is not referenced
    { return Symbol_Sisdead(this, anyiasm); }
}

void symbol_debug(const Symbol* s)
{
    debug assert(s.id == s.IDsymbol);
}

public import dmd.backend.symbol : Symbol_Salignsize, Symbol_Sisdead, Symbol_needThis, Symbol_isAffected;

bool isclassmember(const Symbol* s) { return s.Sscope && s.Sscope.Sclass == SC.struct_; }

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
const(char)* prettyident(const Symbol* s) { return &s.Sident[0]; }


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
EHmethod ehmethod(Symbol* f)
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

    param_t* search(char* id) return // look for Pident matching id
    { return param_t_search(&this, id); }

    uint length()               // number of parameters in list
    { return param_t_length(&this); }

    void print()                // print this param_t
    { param_t_print(&this); }

    void print_list()           // print this list of param_t's
    { param_t_print_list(&this); }
}

import dmd.backend.dtype : param_t_print, param_t_print_list, param_t_length, param_t_createTal,
    param_t_search, param_t_searchn;

void param_debug(const param_t* p)
{
    debug assert(p.id == p.IDparam);
}

/**************************************
 * Element types.
 * These should be combined with storage classes.
 */

enum FL : ubyte
{
    unde,
    const_,       // numerical constant
    oper,         // operator node
    func,         // function symbol
    data,         // ref to data segment variable
    reg,          // ref to register variable
    pseudo,       // pseuodo register variable
    auto_,        // ref to automatic variable
    fast,         // ref to variable passed as register
    para,         // ref to function parameter variable
    extern_,      // ref to external variable
    code,         // offset to code
    block,        // offset to block
    udata,        // ref to udata segment variable
    cs,           // ref to common subexpression number
    switch_,      // ref to offset of switch data block
    fltreg,       // ref to floating reg on stack, int contains offset
    offset,       // offset (a variation on constant, needed so we
                  // can add offsets (different meaning for FL.const_))
    datseg,       // ref to data segment offset
    ctor,         // constructed object
    dtor,         // destructed object
    regsave,      // ref to saved register on stack, int contains offset
    asm_,         // (code) an ASM code

    ndp,          // saved 8087 register

    // Segmented systems
    fardata,      // ref to far data segment
    csdata,       // ref to code segment variable

    localsize,    // replaced with # of locals in the stack frame
    tlsdata,      // thread local storage
    bprel,        // ref to variable at fixed offset from frame pointer
    framehandler, // ref to C++ frame handler for NT EH
    blockoff,     // address of block
    allocatmp,    // temp for built-in alloca()
    stack,        // offset from ESP rather than EBP
    dsymbol,      // it's a Dsymbol

    // Global Offset Table
    got,          // global offset table entry outside this object file
    gotoff,       // global offset table entry inside this object file

    funcarg,      // argument to upcoming function call
}

////////// Srcfiles


/**************************************************
 * This is to support compiling expressions within the context of a function.
 */

struct EEcontext
{
    uint EElinnum;              // line number to insert expression
    char* EEexpr;               // expression
    char* EEtypedef;            // typedef identifier
    byte EEpending;             // !=0 means we haven't compiled it yet
    byte EEimminent;            // we've installed it in the source text
    byte EEcompile;             // we're compiling for the EE expression
    byte EEin;                  // we are parsing an EE expression
    elem* EEelem;               // compiled version of EEexpr
    Symbol* EEfunc;             // function expression is in
    code* EEcode;               // generated code
}

public import dmd.backend.ee : eecontext;

// Different goals for el_optimize()
enum Goal : uint
{
    none        = 0,       // evaluate for side effects only
    value       = 1,       // evaluate for value
    flags       = 2,       // evaluate for flags
    again       = 4,
    struct_     = 8,
    handle      = 0x10,    // don't replace handle'd objects
    ignoreExceptions = 0x20, // ignore floating point exceptions
}

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
    dt_t* DTnext;                       // next in list
    DT dt;                              // Tagged union tag, see above
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
            byte* DTpbytes;             // pointer to the bytes
            size_t DTnbytes;            // # of bytes
            int DTseg;                  // segment it went into
            targ_size_t DTabytes;       // offset of abytes for DTabytes
        }
        struct                          // DTxoff
        {
            Symbol* DTsym;              // symbol pointer
            targ_size_t DToffset;       // offset from symbol
        }
    }
}

enum DT : ubyte
{
    abytes = 0,
    azeros = 1,
    xoff   = 2,
    nbytes = 3,
    common = 4,
    coff   = 5,
    ibytes = 6,
}
