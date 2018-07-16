/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/code.d, backend/_code.d)
 */

module dmd.backend.code;

// Online documentation: https://dlang.org/phobos/dmd_backend_code.html

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code_x86;
import dmd.backend.el : elem;
import dmd.backend.outbuf;
import dmd.backend.type;

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

extern __gshared
{
    regm_t msavereg,mfuncreg,allregs;

    int BPRM;
    regm_t FLOATREGS;
    regm_t FLOATREGS2;
    regm_t DOUBLEREGS;
    //const char datafl[],stackfl[],segfl[],flinsymtab[];
    char needframe,gotref;
    targ_size_t localsize,
        funcoffset,
        framehandleroffset;
    segidx_t cseg;
    int STACKALIGN;
    LocalSection Para;
    LocalSection Fast;
    LocalSection Auto;
    LocalSection EEStack;
    LocalSection Alloca;
}

/* cgxmm.c */
bool isXMMstore(uint op);

/* cgcod.c */
extern __gshared int pass;
enum
{
    PASSinitial,     // initial pass through code generator
    PASSreg,         // register assignment pass
    PASSfinal,       // final pass
}

extern __gshared int dfoidx;
//extern __gshared CSE *csextab;
extern __gshared bool floatreg;
extern __gshared targ_size_t prolog_allocoffset;
extern __gshared targ_size_t startoffset;
extern __gshared targ_size_t retoffset;
extern __gshared targ_size_t retsize;
extern __gshared uint stackpush;
extern __gshared int stackchanged;
extern __gshared int refparam;
extern __gshared int reflocal;
extern __gshared bool anyiasm;
extern __gshared char calledafunc;
//extern __gshared void function(ref CodeBuilder,elem *,regm_t *)[OPMAX] cdxxx;
extern __gshared bool calledFinally;

void stackoffsets(int);
void codgen(Symbol *);
//#ifdef DEBUG
//unsigned findreg (regm_t regm , int line , const char *file );
//#define findreg(regm) findreg((regm),__LINE__,__FILE__)
//#else
//unsigned findreg (regm_t regm );
//#endif
//#define findregmsw(regm) findreg((regm) & mMSW)
//#define findreglsw(regm) findreg((regm) & (mLSW | mBP))
void freenode(elem *e);
int isregvar(elem *e, regm_t *pregm, uint *preg);
//#ifdef DEBUG
//void allocreg(CodeBuilder& cdb, regm_t *pretregs, unsigned *preg, tym_t tym, int line, const char *file);
//#define allocreg(a,b,c,d) allocreg((a),(b),(c),(d),__LINE__,__FILE__)
//#else
//void allocreg(ref CodeBuilder cdb, regm_t *pretregs, uint *preg, tym_t tym);
//#endif
regm_t lpadregs();
void useregs (regm_t regm);
void getregs(ref CodeBuilder cdb, regm_t r);
void getregsNoSave(regm_t r);
void getregs_imm(ref CodeBuilder cdb, regm_t r);
void cse_flush(ref CodeBuilder, int);
bool cse_simple(code *c, elem *e);
void gen_testcse(ref CodeBuilder cdb, uint sz, targ_uns i);
void gen_loadcse(ref CodeBuilder cdb, uint reg, targ_uns i);
bool cssave (elem *e , regm_t regm , uint opsflag );
bool evalinregister(elem *e);
regm_t getscratch();
void codelem(ref CodeBuilder cdb, elem *e, regm_t *pretregs, bool constflag);
void scodelem(ref CodeBuilder cdb, elem *e, regm_t *pretregs, regm_t keepmsk, bool constflag);
const(char)* regm_str(regm_t rm);
int numbitsset(regm_t);

/* cod1.c */
extern __gshared int clib_inited;

int isscaledindex(elem *);
int ssindex(int op,targ_uns product);
void buildEA(code *c,int base,int index,int scale,targ_size_t disp);
uint buildModregrm(int mod, int reg, int rm);
void andregcon (con_t *pregconsave);
void genEEcode();
void docommas(ref CodeBuilder cdb,elem **pe);
uint gensaverestore(regm_t, ref CodeBuilder cdbsave, ref CodeBuilder cdbrestore);
void genstackclean(ref CodeBuilder cdb,uint numpara,regm_t keepmsk);
void logexp(ref CodeBuilder cdb, elem *e, int jcond, uint fltarg, code *targ);
uint getaddrmode(regm_t idxregs);
void setaddrmode(code *c, regm_t idxregs);
void fltregs(ref CodeBuilder cdb, code *pcs, tym_t tym);
void tstresult(ref CodeBuilder cdb, regm_t regm, tym_t tym, uint saveflag);
void fixresult(ref CodeBuilder cdb, elem *e, regm_t retregs, regm_t *pretregs);
void callclib(ref CodeBuilder cdb, elem *e, uint clib, regm_t *pretregs, regm_t keepmask);
void pushParams(ref CodeBuilder cdb,elem *, uint, tym_t tyf);
void offsetinreg(ref CodeBuilder cdb, elem *e, regm_t *pretregs);

/* cod2.c */
int movOnly(elem *e);
regm_t idxregm(code *c);
void opdouble(ref CodeBuilder cdb, elem *e, regm_t *pretregs, uint clib);
void WRcodlst(code *c);
void getoffset(ref CodeBuilder cdb, elem *e, uint reg);

/* cod3.c */

int cod3_EA(code *c);
regm_t cod3_useBP();
void cod3_initregs();
void cod3_setdefault();
void cod3_set32();
void cod3_set64();
void cod3_align_bytes(int seg, size_t nbytes);
void cod3_align(int seg);
void cod3_buildmodulector(Outbuffer* buf, int codeOffset, int refOffset);
void cod3_stackadj(ref CodeBuilder cdb, int nbytes);
regm_t regmask(tym_t tym, tym_t tyf);
void cgreg_dst_regs(uint *dst_integer_reg, uint *dst_float_reg);
void cgreg_set_priorities(tym_t ty, ubyte **pseq, ubyte **pseqmsw);
void outblkexitcode(ref CodeBuilder cdb, block *bl, ref int anyspill, const char* sflsave, Symbol** retsym, const regm_t mfuncregsave );
void outjmptab(block *b);
void outswitab(block *b);
int jmpopcode(elem *e);
void cod3_ptrchk(ref CodeBuilder cdb,code *pcs,regm_t keepmsk);
void genregs(ref CodeBuilder cdb, uint op, uint dstreg, uint srcreg);
void gentstreg(ref CodeBuilder cdb, uint reg);
void genpush(ref CodeBuilder cdb, uint reg);
void genpop(ref CodeBuilder cdb, uint reg);
void gensavereg(ref CodeBuilder cdb, ref uint reg, targ_uns slot);
code *genmovreg(uint to, uint from);
void genmovreg(ref CodeBuilder cdb, uint to, uint from);
void genmulimm(ref CodeBuilder cdb,uint r1,uint r2,targ_int imm);
void genshift(ref CodeBuilder cdb);
void movregconst(ref CodeBuilder cdb,uint reg,targ_size_t value,regm_t flags);
void genjmp(ref CodeBuilder cdb, uint op, uint fltarg, block *targ);
void prolog(ref CodeBuilder cdb);
void epilog (block *b);
void gen_spill_reg(ref CodeBuilder cdb, Symbol *s, bool toreg);
void load_localgot(ref CodeBuilder cdb);
targ_size_t cod3_spoff();
void makeitextern (Symbol *s );
void fltused();
int branch(block *bl, int flag);
void cod3_adjSymOffsets();
void assignaddr(block *bl);
void assignaddrc(code *c);
targ_size_t cod3_bpoffset(Symbol *s);
void pinholeopt (code *c , block *bn );
void simplify_code(code *c);
void jmpaddr (code *c);
int code_match(code *c1,code *c2);
uint calcblksize (code *c);
uint calccodsize(code *c);
uint codout(int seg, code *c);
size_t addtofixlist(Symbol *s , targ_size_t soffset , int seg , targ_size_t val , int flags );
void searchfixlist(Symbol *s) {}
void outfixlist();
void code_hydrate(code **pc);
void code_dehydrate(code **pc);

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



