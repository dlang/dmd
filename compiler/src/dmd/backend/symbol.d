/**
 * Symbols for the back end
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/symbol.d
 */

module dmd.backend.symbol;

enum HYDRATE = false;
enum DEHYDRATE = false;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cdef;
import dmd.backend.cc;
import dmd.backend.cgcv;
import dmd.backend.dlist;
import dmd.backend.dt;
import dmd.backend.dvec;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.mem;
import dmd.backend.oper;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;


nothrow:
@safe:

import dmd.backend.code_x86;

void struct_free(struct_t *st) { }

@trusted @nogc
func_t* func_calloc()
{
    func_t* f = cast(func_t *) calloc(1, func_t.sizeof);
    if (!f)
        err_nomem();
    return f;
}

@trusted
void func_free(func_t* f) { free(f); }

/*******************************
 * Type out symbol information.
 */
@trusted
void symbol_print(const Symbol *s)
{
debug
{
    if (!s) return;
    printf("symbol %p '%s'\n ",s,s.Sident.ptr);
    printf(" Sclass = %s ", class_str(s.Sclass));
    printf(" Ssymnum = %d",cast(int)s.Ssymnum);
    printf(" Sfl = "); WRFL(cast(FL) s.Sfl);
    printf(" Sseg = %d\n",s.Sseg);
//  printf(" Ssize   = x%02x\n",s.Ssize);
    printf(" Soffset = x%04llx",cast(ulong)s.Soffset);
    printf(" Sweight = %d",s.Sweight);
    printf(" Sflags = x%04x",cast(uint)s.Sflags);
    printf(" Sxtrnnum = %d\n",s.Sxtrnnum);
    printf("  Stype   = %p",s.Stype);
    printf(" Sl      = %p",s.Sl);
    printf(" Sr      = %p\n",s.Sr);
    if (s.Sscope)
        printf(" Sscope = '%s'\n",s.Sscope.Sident.ptr);
    if (s.Stype)
        type_print(s.Stype);
    if (s.Sclass == SC.member || s.Sclass == SC.field)
    {
        printf("  Smemoff =%5lld", cast(long)s.Smemoff);
        printf("  Sbit    =%3d",s.Sbit);
        printf("  Swidth  =%3d\n",s.Swidth);
    }
}
}


/*********************************
 * Terminate use of symbol table.
 */

private __gshared Symbol *keep;

@trusted
void symbol_term()
{
    symbol_free(keep);
}

/****************************************
 * Keep symbol around until symbol_term().
 */

static if (TERMCODE)
{

void symbol_keep(Symbol *s)
{
    symbol_debug(s);
    s.Sr = keep;       // use Sr so symbol_free() doesn't nest
    keep = s;
}

}

/****************************************
 * Return alignment of symbol.
 */
@trusted
int Symbol_Salignsize(ref Symbol s)
{
    if (s.Salignment > 0)
        return s.Salignment;
    int alignsize = type_alignsize(s.Stype);

    /* Reduce alignment faults when SIMD vectors
     * are reinterpreted cast to other types with less alignment.
     */
    if (config.fpxmmregs && alignsize < 16 &&
        s.Sclass == SC.auto_ &&
        type_size(s.Stype) == 16)
    {
        alignsize = 16;
    }

    return alignsize;
}

/****************************************
 * Aver if Symbol is not only merely dead, but really most sincerely dead.
 * Params:
 *      anyInlineAsm = true if there's any inline assembler code
 * Returns:
 *      true if symbol is dead.
 */

@trusted
bool Symbol_Sisdead(const ref Symbol s, bool anyInlineAsm)
{
    enum vol = false;
    return s.Sflags & SFLdead ||
           /* SFLdead means the optimizer found no references to it.
            * The rest deals with variables that the compiler never needed
            * to read from memory because they were cached in registers,
            * and so no memory needs to be allocated for them.
            * Code that does write those variables to memory gets NOPed out
            * during address assignment.
            */
           (!anyInlineAsm && !(s.Sflags & SFLread) && s.Sflags & SFLunambig &&

            // mTYvolatile means this variable has been reference by a nested function
            (vol || !(s.Stype.Tty & mTYvolatile)) &&

            (config.flags4 & CFG4optimized || !config.fulltypes));
}

/****************************************
 * Determine if symbol needs a 'this' pointer.
 */

@trusted
int Symbol_needThis(const ref Symbol s)
{
    //printf("needThis() '%s'\n", Sident.ptr);

    debug assert(isclassmember(&s));

    if (s.Sclass == SC.member || s.Sclass == SC.field)
        return 1;
    if (tyfunc(s.Stype.Tty) && !(s.Sfunc.Fflags & Fstatic))
        return 1;
    return 0;
}

/************************************
 * Determine if `s` may be affected if an assignment is done through
 * a pointer.
 * Params:
 *      s = symbol to check
 * Returns:
 *      true if it may be modified by assignment through a pointer
 */

bool Symbol_isAffected(const ref Symbol s)
{
    //printf("s: %s %d\n", s.Sident.ptr, !(s.Sflags & SFLunambig) && !(s.ty() & (mTYconst | mTYimmutable)));
    //symbol_print(s);

    /* If nobody took its address and it's not statically allocated,
     * then it is not accessible via pointer and so is not affected.
     */
    if (s.Sflags & SFLunambig)
        return false;

    /* If it's immutable, it can't be affected.
     *
     * Disable this check because:
     * 1. Symbol_isAffected is not used by copyprop() and should be.
     * 2. Non-@safe functions can temporarilly cast away immutable.
     * 3. Need to add an @safe flag to funcsym_p to enable this.
     * 4. Const can be mutated by a separate view.
     * Address this in a separate PR.
     */
    static if (0)
    if (s.ty() & (mTYconst | mTYimmutable))
    {
        /* Disabled for the moment because even @safe functions
         * may have inlined unsafe code from other functions
         */
        if (funcsym_p.Sfunc.Fflags3 & F3safe &&
            s.ty() & mTYimmutable)
        {
            return false;
        }
    }
    return true;
}


/***********************************
 * Get user name of symbol.
 */

@trusted
const(char)* symbol_ident(const Symbol *s)
{
    return s.Sident.ptr;
}

/****************************************
 * Create a new symbol.
 */

@trusted @nogc
extern (C)
Symbol * symbol_calloc(const(char)[] id)
{
    //printf("sizeof(symbol)=%d, sizeof(s.Sident)=%d, len=%d\n", symbol.sizeof, s.Sident.sizeof, cast(int)id.length);
    Symbol* s = cast(Symbol *) mem_fmalloc(Symbol.sizeof - Symbol.Sident.length + id.length + 1 + 5);
    memset(s,0,Symbol.sizeof - s.Sident.length);
    memcpy(s.Sident.ptr,id.ptr,id.length);
    s.Sident.ptr[id.length] = 0;
    s.Ssymnum = SYMIDX.max;
    if (debugy)
        printf("symbol_calloc('%s') = %p\n",s.Sident.ptr,s);
    debug s.id = Symbol.IDsymbol;
    return s;
}

/****************************************
 * Create a Symbol
 * Params:
 *      name = name to give the Symbol
 *      type = type for the Symbol
 * Returns:
 *      created Symbol
 */

@trusted @nogc
extern (C)
Symbol * symbol_name(const(char)[] name, SC sclass, type *t)
{
    type_debug(t);
    Symbol *s = symbol_calloc(name);
    s.Sclass = sclass;
    s.Stype = t;
    s.Stype.Tcount++;

    if (tyfunc(t.Tty))
        symbol_func(s);
    return s;
}

/****************************************
 * Create a symbol that is an alias to another function symbol.
 */

@trusted
Funcsym *symbol_funcalias(Funcsym *sf)
{
    symbol_debug(sf);
    assert(tyfunc(sf.Stype.Tty));
    if (sf.Sclass == SC.funcalias)
        sf = sf.Sfunc.Falias;
    auto s = cast(Funcsym *)symbol_name(sf.Sident.ptr[0 .. strlen(sf.Sident.ptr)],SC.funcalias,sf.Stype);
    s.Sfunc.Falias = sf;

    return s;
}

/****************************************
 * Create a symbol, give it a name, storage class and type.
 */

@trusted @nogc
Symbol * symbol_generate(SC sclass,type *t)
{
    __gshared int tmpnum;
    char[4 + tmpnum.sizeof * 3 + 1] name;

    //printf("symbol_generate(_TMP%d)\n", tmpnum);
    const length = snprintf(name.ptr,name.length,"_TMP%d",tmpnum++);
    Symbol *s = symbol_name(name.ptr[0 .. length],sclass,t);
    //symbol_print(s);

    s.Sflags |= SFLnodebug | SFLartifical;

    return s;
}

/****************************************
 * Generate an auto symbol, and add it to the symbol table.
 */

Symbol * symbol_genauto(type *t)
{   Symbol *s;

    s = symbol_generate(SC.auto_,t);
    s.Sflags |= SFLfree;
    symbol_add(s);
    return s;
}

/******************************************
 * Generate symbol into which we can copy the contents of expression e.
 */

Symbol *symbol_genauto(elem *e)
{
    return symbol_genauto(type_fake(e.Ety));
}

/******************************************
 * Generate symbol into which we can copy the contents of expression e.
 */

Symbol *symbol_genauto(tym_t ty)
{
    return symbol_genauto(type_fake(ty));
}

/****************************************
 * Add in the variants for a function symbol.
 */

@trusted @nogc
void symbol_func(Symbol *s)
{
    //printf("symbol_func(%s, x%x)\n", s.Sident.ptr, fregsaved);
    symbol_debug(s);
    s.Sfl = FLfunc;
    // Interrupt functions modify all registers
    // BUG: do interrupt functions really save BP?
    // Note that fregsaved may not be set yet
    s.Sregsaved = (s.Stype && tybasic(s.Stype.Tty) == TYifunc) ? cast(regm_t) mBP : fregsaved;
    s.Sseg = UNKNOWN;          // don't know what segment it is in
    if (!s.Sfunc)
        s.Sfunc = func_calloc();
}

/***************************************
 * Add a field to a struct s.
 * Params:
 *      s      = the struct symbol
 *      name   = field name
 *      t      = the type of the field
 *      offset = offset of the field
 */

@trusted
void symbol_struct_addField(Symbol *s, const(char)* name, type *t, uint offset)
{
    Symbol *s2 = symbol_name(name[0 .. strlen(name)], SC.member, t);
    s2.Smemoff = offset;
    list_append(&s.Sstruct.Sfldlst, s2);
}

/***************************************
 * Add a bit field to a struct s.
 * Params:
 *      s      = the struct symbol
 *      name   = field name
 *      t      = the type of the field
 *      offset = offset of the field
 *      fieldWidth = width of bit field
 *      bitOffset  = bit number of start of field
 */

@trusted
void symbol_struct_addBitField(Symbol *s, const(char)* name, type *t, uint offset, uint fieldWidth, uint bitOffset)
{
    //printf("symbol_struct_addBitField() s: %s\n", s.Sident.ptr);
    Symbol *s2 = symbol_name(name[0 .. strlen(name)], SC.field, t);
    s2.Smemoff = offset;
    s2.Swidth = cast(ubyte)fieldWidth;
    s2.Sbit = cast(ubyte)bitOffset;
    list_append(&s.Sstruct.Sfldlst, s2);
    symbol_struct_hasBitFields(s);
}

/***************************************
 * Mark struct s as having bit fields
 * Params:
 *      s      = the struct symbol
 */
@trusted
void symbol_struct_hasBitFields(Symbol *s)
{
    s.Sstruct.Sflags |= STRbitfields;
}

/***************************************
 * Add a base class to a struct s.
 * Input:
 *      s       the struct/class symbol
 *      t       the type of the base class
 *      offset  offset of the base class in the struct/class
 */

@trusted
void symbol_struct_addBaseClass(Symbol *s, type *t, uint offset)
{
    assert(t && t.Tty == TYstruct);
    auto bc = cast(baseclass_t*)mem_fmalloc(baseclass_t.sizeof);
    bc.BCbase = t.Ttag;
    bc.BCoffset = offset;
    bc.BCnext = s.Sstruct.Sbase;
    s.Sstruct.Sbase = bc;
}

/********************************
 * Check integrity of symbol data structure.
 */

debug
{

void symbol_check(const Symbol *s)
{
    //printf("symbol_check('%s',%p)\n",s.Sident.ptr,s);
    symbol_debug(s);
    if (s.Stype) type_debug(s.Stype);
    assert(cast(uint)s.Sclass < cast(uint)SCMAX);
}

void symbol_tree_check(const(Symbol)* s)
{
    while (s)
    {   symbol_check(s);
        symbol_tree_check(s.Sl);
        s = s.Sr;
    }
}

}

/*************************************
 * Search for symbol in multiple symbol tables,
 * starting with most recently nested one.
 * Input:
 *      p .    identifier string
 * Returns:
 *      pointer to symbol
 *      null if couldn't find it
 */

static if (0)
{
Symbol * lookupsym(const(char)* p)
{
    return scope_search(p,SCTglobal | SCTlocal);
}
}

/*********************************
 * Delete symbol from symbol table, taking care to delete
 * all children of a symbol.
 * Make sure there are no more forward references (labels, tags).
 * Input:
 *      pointer to a symbol
 */

@trusted
void meminit_free(meminit_t *m)         /* helper for symbol_free()     */
{
    list_free(&m.MIelemlist,cast(list_free_fp)&el_free);
    mem_free(m);
}

@trusted
void symbol_free(Symbol *s)
{
    while (s)                           /* if symbol exists             */
    {   Symbol *sr;

debug
{
        if (debugy)
            printf("symbol_free('%s',%p)\n",s.Sident.ptr,s);
        symbol_debug(s);
        assert(/*s.Sclass != SC.unde &&*/ cast(int) s.Sclass < cast(int) SCMAX);
}
        {   type *t = s.Stype;

            if (t)
                type_debug(t);
            if (t && tyfunc(t.Tty) && s.Sfunc)
            {
                func_t *f = s.Sfunc;

                debug assert(f);
                blocklist_free(&f.Fstartblock);
                freesymtab(f.Flocsym[].ptr,0,f.Flocsym.length);

                f.Flocsym.dtor();
              if (CPP)
              {
                if (f.Fflags & Fnotparent)
                {   debug if (debugy) printf("not parent, returning\n");
                    return;
                }

                /* We could be freeing the symbol before its class is   */
                /* freed, so remove it from the class's field list      */
                if (f.Fclass)
                {   list_t tl;

                    symbol_debug(f.Fclass);
                    tl = list_inlist(f.Fclass.Sstruct.Sfldlst,s);
                    if (tl)
                        list_setsymbol(tl, null);
                }

                if (f.Foversym && f.Foversym.Sfunc)
                {   f.Foversym.Sfunc.Fflags &= ~Fnotparent;
                    f.Foversym.Sfunc.Fclass = null;
                    symbol_free(f.Foversym);
                }

                if (f.Fexplicitspec)
                    symbol_free(f.Fexplicitspec);

                /* If operator function, remove from list of such functions */
                if (f.Fflags & Foperator)
                {   assert(f.Foper && f.Foper < OPMAX);
                    //if (list_inlist(cpp_operfuncs[f.Foper],s))
                    //  list_subtract(&cpp_operfuncs[f.Foper],s);
                }

                list_free(&f.Fclassfriends,FPNULL);
                list_free(&f.Ffwdrefinstances,FPNULL);
                param_free(&f.Farglist);
                param_free(&f.Fptal);
                list_free(&f.Fexcspec,cast(list_free_fp)&type_free);


                el_free(f.Fbaseinit);
                if (f.Fthunk && !(f.Fflags & Finstance))
                    mem_free(f.Fthunk);
                list_free(&f.Fthunks,cast(list_free_fp)&symbol_free);
              }
                list_free(&f.Fsymtree,cast(list_free_fp)&symbol_free);
                f.typesTable.dtor();
                func_free(f);
            }
            switch (s.Sclass)
            {
                case SC.struct_:
                  if (!CPP)
                  {
                    debug if (debugy)
                        printf("freeing members %p\n",s.Sstruct.Sfldlst);

                    list_free(&s.Sstruct.Sfldlst,FPNULL);
                    symbol_free(s.Sstruct.Sroot);
                    struct_free(s.Sstruct);
                  }
static if (0)       /* Don't complain anymore about these, ANSI C says  */
{
                    /* it's ok                                          */
                    if (t && t.Tflags & TFsizeunknown)
                        synerr(EM_unknown_tag,s.Sident.ptr);
}
                    break;
                case SC.enum_:
                    /* The actual member symbols are either in a local  */
                    /* table or on the member list of a class, so we    */
                    /* don't free them here.                            */
                    assert(s.Senum);
                    list_free(&s.Senum.SEenumlist,FPNULL);
                    mem_free(s.Senum);
                    s.Senum = null;
                    break;

                case SC.parameter:
                case SC.regpar:
                case SC.fastpar:
                case SC.shadowreg:
                case SC.register:
                case SC.auto_:
                    vec_free(s.Srange);
static if (0)
{
                    goto case SC.const_;
                case SC.const_:
                    if (s.Sflags & (SFLvalue | SFLdtorexp))
                        el_free(s.Svalue);
}
                    break;
                default:
                    break;
            }
            if (s.Sflags & (SFLvalue | SFLdtorexp))
                el_free(s.Svalue);
            if (s.Sdt)
                dt_free(s.Sdt);
            type_free(t);
            symbol_free(s.Sl);
            sr = s.Sr;
debug
{
            s.id = 0;
}
            mem_ffree(s);
        }
        s = sr;
    }
}

/********************************
 * Undefine a symbol.
 * Assume error msg was already printed.
 */

static if (0)
{
private void symbol_undef(Symbol *s)
{
  s.Sclass = SC.unde;
  s.Ssymnum = SYMIDX.max;
  type_free(s.Stype);                  /* free type data               */
  s.Stype = null;
}
}

/*****************************
 * Add symbol to current symbol array.
 */

@trusted
SYMIDX symbol_add(Symbol *s)
{
    return symbol_add(*cstate.CSpsymtab, s);
}

@trusted
SYMIDX symbol_add(ref symtab_t symtab, Symbol* s)
{
    //printf("symbol_add('%s')\n", s.Sident.ptr);
    debug
    {
        if (!s || !s.Sident[0])
        {   printf("bad symbol\n");
            assert(0);
        }
    }
    symbol_debug(s);
    if (pstate.STinsizeof)
    {   symbol_keep(s);
        return SYMIDX.max;
    }
    const sitop = symtab.length;
    symtab.setLength(sitop + 1);
    symtab[sitop] = s;

    debug if (debugy)
        printf("symbol_add(%p '%s') = %d\n",s,s.Sident.ptr, cast(int) symtab.length);

    debug if (s.Ssymnum != SYMIDX.max)
        printf("symbol %s already added\n", s.Sident.ptr);
    assert(s.Ssymnum == SYMIDX.max);
    s.Ssymnum = sitop;

    return sitop;
}

/********************************************
 * Insert s into symtab at position n.
 * Returns:
 *      position in table
 */
@trusted
SYMIDX symbol_insert(ref symtab_t symtab, Symbol* s, SYMIDX n)
{
    const sinew = symbol_add(s);        // added at end, have to move it
    for (SYMIDX i = sinew; i > n; --i)
    {
        symtab[i] = symtab[i - 1];
        symtab[i].Ssymnum += 1;
    }
    globsym[n] = s;
    s.Ssymnum = n;
    return n;
}

/****************************
 * Free up the symbols stab[n1 .. n2]
 */

@trusted
void freesymtab(Symbol **stab,SYMIDX n1,SYMIDX n2)
{
    if (!stab)
        return;

    debug if (debugy)
        printf("freesymtab(from %d to %d)\n", cast(int) n1, cast(int) n2);

    assert(stab != globsym[].ptr || (n1 <= n2 && n2 <= globsym.length));
    foreach (ref s; stab[n1 .. n2])
    {
        if (s && s.Sflags & SFLfree)
        {

            debug
            {
                if (debugy)
                    printf("Freeing %p '%s'\n",s,s.Sident.ptr);
                symbol_debug(s);
            }
            s.Sl = s.Sr = null;
            s.Ssymnum = SYMIDX.max;
            symbol_free(s);
            s = null;
        }
    }
}

/****************************
 * Create a copy of a symbol.
 */

@trusted
Symbol * symbol_copy(Symbol *s)
{   Symbol *scopy;
    type *t;

    symbol_debug(s);
    /*printf("symbol_copy(%s)\n",s.Sident.ptr);*/
    scopy = symbol_calloc(s.Sident.ptr[0 .. strlen(s.Sident.ptr)]);
    memcpy(scopy,s,Symbol.sizeof - s.Sident.sizeof);
    scopy.Sl = scopy.Sr = scopy.Snext = null;
    scopy.Ssymnum = SYMIDX.max;
    if (scopy.Sdt)
    {
        auto dtb = DtBuilder(0);
        dtb.nzeros(cast(uint)type_size(scopy.Stype));
        scopy.Sdt = dtb.finish();
    }
    if (scopy.Sflags & (SFLvalue | SFLdtorexp))
        scopy.Svalue = el_copytree(s.Svalue);
    t = scopy.Stype;
    if (t)
    {   t.Tcount++;            /* one more parent of the type  */
        type_debug(t);
    }
    return scopy;
}

/*******************************************
 * Hydrate a symbol tree.
 */

static if (HYDRATE)
{
@trusted
void symbol_tree_hydrate(Symbol **ps)
{   Symbol *s;

    while (isdehydrated(*ps))           /* if symbol is dehydrated      */
    {
        s = symbol_hydrate(ps);
        symbol_debug(s);
        if (s.Scover)
            symbol_hydrate(&s.Scover);
        symbol_tree_hydrate(&s.Sl);
        ps = &s.Sr;
    }

}
}

/*******************************************
 * Dehydrate a symbol tree.
 */

static if (DEHYDRATE)
{
@trusted
void symbol_tree_dehydrate(Symbol **ps)
{   Symbol *s;

    while ((s = *ps) != null && !isdehydrated(s)) /* if symbol exists   */
    {
        symbol_debug(s);
        symbol_dehydrate(ps);
version (DEBUG_XSYMGEN)
{
        if (xsym_gen && ph_in_head(s))
            return;
}
        symbol_dehydrate(&s.Scover);
        symbol_tree_dehydrate(&s.Sl);
        ps = &s.Sr;
    }
}
}

/*******************************************
 * Hydrate a symbol.
 */

static if (HYDRATE)
{
@trusted
Symbol *symbol_hydrate(Symbol **ps)
{   Symbol *s;

    s = *ps;
    if (isdehydrated(s))                /* if symbol is dehydrated      */
    {   type *t;
        struct_t *st;

        s = cast(Symbol *) ph_hydrate(cast(void**)ps);

        debug debugy && printf("symbol_hydrate('%s')\n",s.Sident.ptr);

        symbol_debug(s);
        if (!isdehydrated(s.Stype))    // if this symbol is already dehydrated
            return s;                   // no need to do it again
        if (pstate.SThflag != FLAG_INPLACE && s.Sfl != FLreg)
            s.Sxtrnnum = 0;            // not written to .OBJ file yet
        type_hydrate(&s.Stype);
        //printf("symbol_hydrate(%p, '%s', t = %p)\n",s,s.Sident.ptr,s.Stype);
        t = s.Stype;
        if (t)
            type_debug(t);

        if (t && tyfunc(t.Tty) && ph_hydrate(cast(void**)&s.Sfunc))
        {
            func_t *f = s.Sfunc;
            SYMIDX si;

            debug assert(f);

            list_hydrate(&f.Fsymtree,cast(list_free_fp)&symbol_tree_hydrate);
            blocklist_hydrate(&f.Fstartblock);

            ph_hydrate(cast(void**)&f.Flocsym.tab);
            for (si = 0; si < f.Flocsym.length; si++)
                symbol_hydrate(&f.Flocsym[].ptr[si]);

            srcpos_hydrate(&f.Fstartline);
            srcpos_hydrate(&f.Fendline);

            symbol_hydrate(&f.F__func__);

            if (CPP)
            {
                symbol_hydrate(&f.Fparsescope);
                Classsym_hydrate(&f.Fclass);
                symbol_hydrate(&f.Foversym);
                symbol_hydrate(&f.Fexplicitspec);
                symbol_hydrate(&f.Fsurrogatesym);

                list_hydrate(&f.Fclassfriends,cast(list_free_fp)&symbol_hydrate);
                el_hydrate(&f.Fbaseinit);
                token_hydrate(&f.Fbody);
                symbol_hydrate(&f.Falias);
                list_hydrate(&f.Fthunks,cast(list_free_fp)&symbol_hydrate);
                if (f.Fflags & Finstance)
                    symbol_hydrate(&f.Ftempl);
                else
                    thunk_hydrate(&f.Fthunk);
                param_hydrate(&f.Farglist);
                param_hydrate(&f.Fptal);
                list_hydrate(&f.Ffwdrefinstances,cast(list_free_fp)&symbol_hydrate);
                list_hydrate(&f.Fexcspec,cast(list_free_fp)&type_hydrate);
            }
        }
        if (CPP)
            symbol_hydrate(&s.Sscope);
        switch (s.Sclass)
        {
            case SC.struct_:
              if (CPP)
              {
                st = cast(struct_t *) ph_hydrate(cast(void**)&s.Sstruct);
                assert(st);
                symbol_tree_hydrate(&st.Sroot);
                ph_hydrate(cast(void**)&st.Spvirtder);
                list_hydrate(&st.Sfldlst,cast(list_free_fp)&symbol_hydrate);
                list_hydrate(&st.Svirtual,cast(list_free_fp)&mptr_hydrate);
                list_hydrate(&st.Sopoverload,cast(list_free_fp)&symbol_hydrate);
                list_hydrate(&st.Scastoverload,cast(list_free_fp)&symbol_hydrate);
                list_hydrate(&st.Sclassfriends,cast(list_free_fp)&symbol_hydrate);
                list_hydrate(&st.Sfriendclass,cast(list_free_fp)&symbol_hydrate);
                list_hydrate(&st.Sfriendfuncs,cast(list_free_fp)&symbol_hydrate);
                assert(!st.Sinlinefuncs);

                baseclass_hydrate(&st.Sbase);
                baseclass_hydrate(&st.Svirtbase);
                baseclass_hydrate(&st.Smptrbase);
                baseclass_hydrate(&st.Sprimary);
                baseclass_hydrate(&st.Svbptrbase);

                ph_hydrate(cast(void**)&st.Svecctor);
                ph_hydrate(cast(void**)&st.Sctor);
                ph_hydrate(cast(void**)&st.Sdtor);
                ph_hydrate(cast(void**)&st.Sprimdtor);
                ph_hydrate(cast(void**)&st.Spriminv);
                ph_hydrate(cast(void**)&st.Sscaldeldtor);
                ph_hydrate(cast(void**)&st.Sinvariant);
                ph_hydrate(cast(void**)&st.Svptr);
                ph_hydrate(cast(void**)&st.Svtbl);
                ph_hydrate(cast(void**)&st.Sopeq);
                ph_hydrate(cast(void**)&st.Sopeq2);
                ph_hydrate(cast(void**)&st.Scpct);
                ph_hydrate(cast(void**)&st.Sveccpct);
                ph_hydrate(cast(void**)&st.Salias);
                ph_hydrate(cast(void**)&st.Stempsym);
                param_hydrate(&st.Sarglist);
                param_hydrate(&st.Spr_arglist);
                ph_hydrate(cast(void**)&st.Svbptr);
                ph_hydrate(cast(void**)&st.Svbptr_parent);
                ph_hydrate(cast(void**)&st.Svbtbl);
              }
              else
              {
                ph_hydrate(cast(void**)&s.Sstruct);
                symbol_tree_hydrate(&s.Sstruct.Sroot);
                list_hydrate(&s.Sstruct.Sfldlst,cast(list_free_fp)&symbol_hydrate);
              }
                break;

            case SC.enum_:
                assert(s.Senum);
                ph_hydrate(cast(void**)&s.Senum);
                if (CPP)
                {   ph_hydrate(cast(void**)&s.Senum.SEalias);
                    list_hydrate(&s.Senum.SEenumlist,cast(list_free_fp)&symbol_hydrate);
                }
                break;

            case SC.template_:
            {   template_t *tm;

                tm = cast(template_t *) ph_hydrate(cast(void**)&s.Stemplate);
                list_hydrate(&tm.TMinstances,cast(list_free_fp)&symbol_hydrate);
                list_hydrate(&tm.TMfriends,cast(list_free_fp)&symbol_hydrate);
                param_hydrate(&tm.TMptpl);
                param_hydrate(&tm.TMptal);
                token_hydrate(&tm.TMbody);
                list_hydrate(&tm.TMmemberfuncs,cast(list_free_fp)&tmf_hydrate);
                list_hydrate(&tm.TMexplicit,cast(list_free_fp)&tme_hydrate);
                list_hydrate(&tm.TMnestedexplicit,cast(list_free_fp)&tmne_hydrate);
                list_hydrate(&tm.TMnestedfriends,cast(list_free_fp)&tmnf_hydrate);
                ph_hydrate(cast(void**)&tm.TMnext);
                symbol_hydrate(&tm.TMpartial);
                symbol_hydrate(&tm.TMprimary);
                break;
            }

            case SC.namespace:
                symbol_tree_hydrate(&s.Snameroot);
                list_hydrate(&s.Susing,cast(list_free_fp)&symbol_hydrate);
                break;

            case SC.memalias:
            case SC.funcalias:
            case SC.adl:
                list_hydrate(&s.Spath,cast(list_free_fp)&symbol_hydrate);
                goto case SC.alias_;

            case SC.alias_:
                ph_hydrate(cast(void**)&s.Smemalias);
                break;

            default:
                if (s.Sflags & (SFLvalue | SFLdtorexp))
                    el_hydrate(&s.Svalue);
                break;
        }
        {   dt_t **pdt;
            dt_t *dt;

            for (pdt = &s.Sdt; isdehydrated(*pdt); pdt = &dt.DTnext)
            {
                dt = cast(dt_t *) ph_hydrate(cast(void**)pdt);
                switch (dt.dt)
                {   case DT_abytes:
                    case DT_nbytes:
                        ph_hydrate(cast(void**)&dt.DTpbytes);
                        break;
                    case DT_xoff:
                        symbol_hydrate(&dt.DTsym);
                        break;

                    default:
                        break;
                }
            }
        }
        if (s.Scover)
            symbol_hydrate(&s.Scover);
    }
    return s;
}
}

/*******************************************
 * Dehydrate a symbol.
 */

static if (DEHYDRATE)
{
@trusted
void symbol_dehydrate(Symbol **ps)
{
    Symbol *s;

    if ((s = *ps) != null && !isdehydrated(s)) /* if symbol exists      */
    {   type *t;
        struct_t *st;

        debug
        if (debugy)
            printf("symbol_dehydrate('%s')\n",s.Sident.ptr);

        ph_dehydrate(ps);
version (DEBUG_XSYMGEN)
{
        if (xsym_gen && ph_in_head(s))
            return;
}
        symbol_debug(s);
        t = s.Stype;
        if (isdehydrated(t))
            return;
        type_dehydrate(&s.Stype);

        if (tyfunc(t.Tty) && !isdehydrated(s.Sfunc))
        {
            func_t *f = s.Sfunc;
            SYMIDX si;

            debug assert(f);
            ph_dehydrate(&s.Sfunc);

            list_dehydrate(&f.Fsymtree,cast(list_free_fp)&symbol_tree_dehydrate);
            blocklist_dehydrate(&f.Fstartblock);
            assert(!isdehydrated(&f.Flocsym.tab));

version (DEBUG_XSYMGEN)
{
            if (!xsym_gen || !ph_in_head(f.Flocsym[].ptr))
                for (si = 0; si < f.Flocsym.length; si++)
                    symbol_dehydrate(&f.Flocsym.tab[si]);
}
else
{
            for (si = 0; si < f.Flocsym.length; si++)
                symbol_dehydrate(&f.Flocsym.tab[si]);
}
            ph_dehydrate(&f.Flocsym.tab);

            srcpos_dehydrate(&f.Fstartline);
            srcpos_dehydrate(&f.Fendline);
            symbol_dehydrate(&f.F__func__);
            if (CPP)
            {
            symbol_dehydrate(&f.Fparsescope);
            ph_dehydrate(&f.Fclass);
            symbol_dehydrate(&f.Foversym);
            symbol_dehydrate(&f.Fexplicitspec);
            symbol_dehydrate(&f.Fsurrogatesym);

            list_dehydrate(&f.Fclassfriends,FPNULL);
            el_dehydrate(&f.Fbaseinit);
version (DEBUG_XSYMGEN)
{
            if (xsym_gen && s.Sclass == SC.functempl)
                ph_dehydrate(&f.Fbody);
            else
                token_dehydrate(&f.Fbody);
}
else
            token_dehydrate(&f.Fbody);

            symbol_dehydrate(&f.Falias);
            list_dehydrate(&f.Fthunks,cast(list_free_fp)&symbol_dehydrate);
            if (f.Fflags & Finstance)
                symbol_dehydrate(&f.Ftempl);
            else
                thunk_dehydrate(&f.Fthunk);
//#if !TX86 && DEBUG_XSYMGEN
//            if (xsym_gen && s.Sclass == SCfunctempl)
//                ph_dehydrate(&f.Farglist);
//            else
//#endif
            param_dehydrate(&f.Farglist);
            param_dehydrate(&f.Fptal);
            list_dehydrate(&f.Ffwdrefinstances,cast(list_free_fp)&symbol_dehydrate);
            list_dehydrate(&f.Fexcspec,cast(list_free_fp)&type_dehydrate);
            }
        }
        if (CPP)
            ph_dehydrate(&s.Sscope);
        switch (s.Sclass)
        {
            case SC.struct_:
              if (CPP)
              {
                st = s.Sstruct;
                if (isdehydrated(st))
                    break;
                ph_dehydrate(&s.Sstruct);
                assert(st);
                symbol_tree_dehydrate(&st.Sroot);
                ph_dehydrate(&st.Spvirtder);
                list_dehydrate(&st.Sfldlst,cast(list_free_fp)&symbol_dehydrate);
                list_dehydrate(&st.Svirtual,cast(list_free_fp)&mptr_dehydrate);
                list_dehydrate(&st.Sopoverload,cast(list_free_fp)&symbol_dehydrate);
                list_dehydrate(&st.Scastoverload,cast(list_free_fp)&symbol_dehydrate);
                list_dehydrate(&st.Sclassfriends,cast(list_free_fp)&symbol_dehydrate);
                list_dehydrate(&st.Sfriendclass,cast(list_free_fp)&ph_dehydrate);
                list_dehydrate(&st.Sfriendfuncs,cast(list_free_fp)&ph_dehydrate);
                assert(!st.Sinlinefuncs);

                baseclass_dehydrate(&st.Sbase);
                baseclass_dehydrate(&st.Svirtbase);
                baseclass_dehydrate(&st.Smptrbase);
                baseclass_dehydrate(&st.Sprimary);
                baseclass_dehydrate(&st.Svbptrbase);

                ph_dehydrate(&st.Svecctor);
                ph_dehydrate(&st.Sctor);
                ph_dehydrate(&st.Sdtor);
                ph_dehydrate(&st.Sprimdtor);
                ph_dehydrate(&st.Spriminv);
                ph_dehydrate(&st.Sscaldeldtor);
                ph_dehydrate(&st.Sinvariant);
                ph_dehydrate(&st.Svptr);
                ph_dehydrate(&st.Svtbl);
                ph_dehydrate(&st.Sopeq);
                ph_dehydrate(&st.Sopeq2);
                ph_dehydrate(&st.Scpct);
                ph_dehydrate(&st.Sveccpct);
                ph_dehydrate(&st.Salias);
                ph_dehydrate(&st.Stempsym);
                param_dehydrate(&st.Sarglist);
                param_dehydrate(&st.Spr_arglist);
                ph_dehydrate(&st.Svbptr);
                ph_dehydrate(&st.Svbptr_parent);
                ph_dehydrate(&st.Svbtbl);
              }
              else
              {
                symbol_tree_dehydrate(&s.Sstruct.Sroot);
                list_dehydrate(&s.Sstruct.Sfldlst,cast(list_free_fp)&symbol_dehydrate);
                ph_dehydrate(&s.Sstruct);
              }
                break;

            case SC.enum_:
                assert(s.Senum);
                if (!isdehydrated(s.Senum))
                {
                    if (CPP)
                    {   ph_dehydrate(&s.Senum.SEalias);
                        list_dehydrate(&s.Senumlist,cast(list_free_fp)&ph_dehydrate);
                    }
                    ph_dehydrate(&s.Senum);
                }
                break;

            case SC.template_:
            {   template_t *tm;

                tm = s.Stemplate;
                if (!isdehydrated(tm))
                {
                    ph_dehydrate(&s.Stemplate);
                    list_dehydrate(&tm.TMinstances,cast(list_free_fp)&symbol_dehydrate);
                    list_dehydrate(&tm.TMfriends,cast(list_free_fp)&symbol_dehydrate);
                    list_dehydrate(&tm.TMnestedfriends,cast(list_free_fp)&tmnf_dehydrate);
                    param_dehydrate(&tm.TMptpl);
                    param_dehydrate(&tm.TMptal);
                    token_dehydrate(&tm.TMbody);
                    list_dehydrate(&tm.TMmemberfuncs,cast(list_free_fp)&tmf_dehydrate);
                    list_dehydrate(&tm.TMexplicit,cast(list_free_fp)&tme_dehydrate);
                    list_dehydrate(&tm.TMnestedexplicit,cast(list_free_fp)&tmne_dehydrate);
                    ph_dehydrate(&tm.TMnext);
                    symbol_dehydrate(&tm.TMpartial);
                    symbol_dehydrate(&tm.TMprimary);
                }
                break;
            }

            case SC.namespace_:
                symbol_tree_dehydrate(&s.Snameroot);
                list_dehydrate(&s.Susing,cast(list_free_fp)&symbol_dehydrate);
                break;

            case SC.memalias:
            case SC.funcalias:
            case SC.adl:
                list_dehydrate(&s.Spath,cast(list_free_fp)&symbol_dehydrate);
            case SC.alias_:
                ph_dehydrate(&s.Smemalias);
                break;

            default:
                if (s.Sflags & (SFLvalue | SFLdtorexp))
                    el_dehydrate(&s.Svalue);
                break;
        }
        {   dt_t **pdt;
            dt_t *dt;

            for (pdt = &s.Sdt;
                 (dt = *pdt) != null && !isdehydrated(dt);
                 pdt = &dt.DTnext)
            {
                ph_dehydrate(pdt);
                switch (dt.dt)
                {   case DT_abytes:
                    case DT_nbytes:
                        ph_dehydrate(&dt.DTpbytes);
                        break;
                    case DT_xoff:
                        symbol_dehydrate(&dt.DTsym);
                        break;
                }
            }
        }
        if (s.Scover)
            symbol_dehydrate(&s.Scover);
    }
}
}

/***************************
 * Dehydrate threaded list of symbols.
 */

static if (DEHYDRATE)
{
@trusted
void symbol_symdefs_dehydrate(Symbol **ps)
{
    Symbol *s;

    for (; *ps; ps = &s.Snext)
    {
        s = *ps;
        symbol_debug(s);
        //printf("symbol_symdefs_dehydrate(%p, '%s')\n",s,s.Sident.ptr);
        symbol_dehydrate(ps);
    }
}
}


static if (0)
{

/*************************************
 * Put symbol table s into parent symbol table.
 */

void symboltable_hydrate(Symbol *s,Symbol **parent)
{
    while (s)
    {   Symbol* sl,sr;
        char *p;

        symbol_debug(s);

        sl = s.Sl;
        sr = s.Sr;
        p = s.Sident.ptr;

        //printf("symboltable_hydrate('%s')\n",p);

        /* Put symbol s into symbol table       */
        {   Symbol **ps;
            Symbol *rover;
            int c = *p;

            ps = parent;
            while ((rover = *ps) != null)
            {   int cmp;

                if ((cmp = c - rover.Sident[0]) == 0)
                {   cmp = strcmp(p,rover.Sident.ptr); /* compare identifier strings */
                    if (cmp == 0)
                    {
                        if (CPP && tyfunc(s.Stype.Tty) && tyfunc(rover.Stype.Tty))
                        {   Symbol **ps;
                            Symbol *sn;

                            do
                            {
                                // Tack onto end of overloaded function list
                                for (ps = &rover; *ps; ps = &(*ps).Sfunc.Foversym)
                                {   if (cpp_funccmp(s, *ps))
                                        goto L2;
                                }
                                s.Sl = s.Sr = null;
                                *ps = s;
                            L2:
                                sn = s.Sfunc.Foversym;
                                s.Sfunc.Foversym = null;
                                s = sn;
                            } while (s);
                        }
                        else
                        {
                            if (!typematch(s.Stype,rover.Stype,0))
                            {
                                // cpp_predefine() will define this again
                                if (type_struct(rover.Stype) &&
                                    rover.Sstruct.Sflags & STRpredef)
                                {   s.Sl = s.Sr = null;
                                    symbol_keep(s);
                                }
                                else
                                    synerr(EM_multiple_def,p);  // already defined
                            }
                        }
                        goto L1;
                    }
                }
                ps = (cmp < 0) ?        /* if we go down left side      */
                    &rover.Sl :
                    &rover.Sr;
            }
            {
                s.Sl = s.Sr = null;
                *ps = s;
            }
        }
    L1:
        symboltable_hydrate(sl,parent);
        s = sr;
    }
}

}


/************************************
 * Hydrate/dehydrate an mptr_t.
 */

static if (HYDRATE)
{
@trusted
private void mptr_hydrate(mptr_t **pm)
{   mptr_t *m;

    m = cast(mptr_t *) ph_hydrate(cast(void**)pm);
    symbol_hydrate(&m.MPf);
    symbol_hydrate(&m.MPparent);
}
}

static if (DEHYDRATE)
{
@trusted
private void mptr_dehydrate(mptr_t **pm)
{   mptr_t *m;

    m = *pm;
    if (m && !isdehydrated(m))
    {
        ph_dehydrate(pm);
version (DEBUG_XSYMGEN)
{
        if (xsym_gen && ph_in_head(m.MPf))
            ph_dehydrate(&m.MPf);
        else
            symbol_dehydrate(&m.MPf);
}
else
        symbol_dehydrate(&m.MPf);

        symbol_dehydrate(&m.MPparent);
    }
}
}

/************************************
 * Hydrate/dehydrate a baseclass_t.
 */

static if (HYDRATE)
{
@trusted
private void baseclass_hydrate(baseclass_t **pb)
{   baseclass_t *b;

    assert(pb);
    while (isdehydrated(*pb))
    {
        b = cast(baseclass_t *) ph_hydrate(cast(void**)pb);

        ph_hydrate(cast(void**)&b.BCbase);
        ph_hydrate(cast(void**)&b.BCpbase);
        list_hydrate(&b.BCpublics,cast(list_free_fp)&symbol_hydrate);
        list_hydrate(&b.BCmptrlist,cast(list_free_fp)&mptr_hydrate);
        symbol_hydrate(&b.BCvtbl);
        Classsym_hydrate(&b.BCparent);

        pb = &b.BCnext;
    }
}
}

/**********************************
 * Dehydrate a baseclass_t.
 */

static if (DEHYDRATE)
{
@trusted
private void baseclass_dehydrate(baseclass_t **pb)
{   baseclass_t *b;

    while ((b = *pb) != null && !isdehydrated(b))
    {
        ph_dehydrate(pb);

version (DEBUG_XSYMGEN)
{
        if (xsym_gen && ph_in_head(b))
            return;
}

        ph_dehydrate(&b.BCbase);
        ph_dehydrate(&b.BCpbase);
        list_dehydrate(&b.BCpublics,cast(list_free_fp)&symbol_dehydrate);
        list_dehydrate(&b.BCmptrlist,cast(list_free_fp)&mptr_dehydrate);
        symbol_dehydrate(&b.BCvtbl);
        Classsym_dehydrate(&b.BCparent);

        pb = &b.BCnext;
    }
}
}

/***************************
 * Look down baseclass list to find sbase.
 * Returns:
 *      null    not found
 *      pointer to baseclass
 */

baseclass_t *baseclass_find(baseclass_t *bm,Classsym *sbase)
{
    symbol_debug(sbase);
    for (; bm; bm = bm.BCnext)
        if (bm.BCbase == sbase)
            break;
    return bm;
}

@trusted
baseclass_t *baseclass_find_nest(baseclass_t *bm,Classsym *sbase)
{
    symbol_debug(sbase);
    for (; bm; bm = bm.BCnext)
    {
        if (bm.BCbase == sbase ||
            baseclass_find_nest(bm.BCbase.Sstruct.Sbase, sbase))
            break;
    }
    return bm;
}

/******************************
 * Calculate number of baseclasses in list.
 */

int baseclass_nitems(baseclass_t *b)
{   int i;

    for (i = 0; b; b = b.BCnext)
        i++;
    return i;
}

/*************************************
 * Reset Symbol so that it's now an "extern" to the next obj file being created.
 */
void symbol_reset(Symbol *s)
{
    s.Soffset = 0;
    s.Sxtrnnum = 0;
    s.Stypidx = 0;
    s.Sflags &= ~(STRoutdef | SFLweak);
    s.Sdw_ref_idx = 0;
    if (s.Sclass == SC.global || s.Sclass == SC.comdat ||
        s.Sfl == FLudata || s.Sclass == SC.static_)
    {   s.Sclass = SC.extern_;
        s.Sfl = FLextern;
    }
}

/****************************************
 * Determine pointer type needed to access a Symbol,
 * essentially what type an OPrelconst should get
 * for that Symbol.
 * Params:
 *      s = pointer to Symbol
 * Returns:
 *      pointer type to access it
 */
tym_t symbol_pointerType(const Symbol* s)
{
    return s.Stype.Tty & mTYimmutable ? TYimmutPtr : TYnptr;
}
