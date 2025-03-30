/**
 * Symbols for the back end
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/symbol.d
 */

module dmd.backend.symbol;

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

import dmd.backend.x86.code_x86;

void struct_free(struct_t* st) { }

@trusted @nogc
func_t* func_calloc()
{
    func_t* f = cast(func_t*) calloc(1, func_t.sizeof);
    if (!f)
        err_nomem();
    return f;
}

@trusted
void func_free(func_t* f) { free(f); }

/*******************************
 * Type out symbol information.
 */
void symbol_print(const ref Symbol s)
{
debug
{
    printf("symbol '%s'\n ", s.Sident.ptr);
    printf(" Sclass = %s ", class_str(s.Sclass));
    printf(" Ssymnum = %d",cast(int)s.Ssymnum);
    printf(" Sfl = %s", fl_str(cast(FL) s.Sfl));
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

private __gshared Symbol* keep;

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

void symbol_keep(Symbol* s)
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
const(char)* symbol_ident(return ref const Symbol s)
{
    return &s.Sident[0];
}

/****************************************
 * Create a new symbol.
 */

@trusted @nogc
Symbol* symbol_calloc(const(char)[] id)
{
    //printf("sizeof(symbol)=%d, sizeof(s.Sident)=%d, len=%d\n", symbol.sizeof, s.Sident.sizeof, cast(int)id.length);
    Symbol* s = cast(Symbol*) mem_fmalloc(Symbol.sizeof - Symbol.Sident.length + id.length + 1 + 5);
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

@nogc
Symbol* symbol_name(const(char)[] name, SC sclass, type* t)
{
    type_debug(t);
    Symbol* s = symbol_calloc(name);
    s.Sclass = sclass;
    s.Stype = t;
    s.Stype.Tcount++;

    if (tyfunc(t.Tty))
        symbol_func(*s);
    return s;
}

/****************************************
 * Create a symbol that is an alias to another function symbol.
 */

@trusted
Funcsym* symbol_funcalias(Funcsym* sf)
{
    symbol_debug(sf);
    assert(tyfunc(sf.Stype.Tty));
    if (sf.Sclass == SC.funcalias)
        sf = sf.Sfunc.Falias;
    auto s = cast(Funcsym*)symbol_name(sf.Sident.ptr[0 .. strlen(sf.Sident.ptr)],SC.funcalias,sf.Stype);
    s.Sfunc.Falias = sf;

    return s;
}

/****************************************
 * Create a symbol, give it a name, storage class and type.
 */

@trusted @nogc
Symbol* symbol_generate(SC sclass,type* t)
{
    __gshared int tmpnum;
    char[4 + tmpnum.sizeof * 3 + 1] name = void;

    //printf("symbol_generate(_TMP%d)\n", tmpnum);
    const length = snprintf(name.ptr,name.length,"_TMP%d",tmpnum++);
    Symbol* s = symbol_name(name.ptr[0 .. length],sclass,t);
    //symbol_print(s);

    s.Sflags |= SFLnodebug | SFLartifical;

    return s;
}

/****************************************
 * Generate an auto symbol, and add it to the symbol table.
 */

Symbol* symbol_genauto(type* t)
{
    auto s = symbol_generate(SC.auto_,t);
    s.Sflags |= SFLfree;
    symbol_add(s);
    return s;
}

/******************************************
 * Generate symbol into which we can copy the contents of expression e.
 */

Symbol* symbol_genauto(elem* e)
{
    return symbol_genauto(type_fake(e.Ety));
}

/******************************************
 * Generate symbol into which we can copy the contents of expression e.
 */

Symbol* symbol_genauto(tym_t ty)
{
    return symbol_genauto(type_fake(ty));
}

/****************************************
 * Add in the variants for a function symbol.
 */

@trusted @nogc
void symbol_func(ref Symbol s)
{
    //printf("symbol_func(%s, x%x)\n", s.Sident.ptr, fregsaved);
    symbol_debug(&s);
    s.Sfl = FL.func;
    // Interrupt functions modify all registers
    // BUG: do interrupt functions really save BP?
    // Note that fregsaved may not be set yet
    s.Sregsaved = s.Stype && tybasic(s.Stype.Tty) == TYifunc ? cast(regm_t) mBP : fregsaved;
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
void symbol_struct_addField(ref Symbol s, const(char)* name, type* t, uint offset)
{
    Symbol* s2 = symbol_name(name[0 .. strlen(name)], SC.member, t);
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
void symbol_struct_addBitField(ref Symbol s, const(char)* name, type* t, uint offset, uint fieldWidth, uint bitOffset)
{
    //printf("symbol_struct_addBitField() s: %s\n", s.Sident.ptr);
    Symbol* s2 = symbol_name(name[0 .. strlen(name)], SC.field, t);
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
void symbol_struct_hasBitFields(ref Symbol s)
{
    s.Sstruct.Sflags |= STRbitfields;
}

/***************************************
 * Add a base class to a struct s.
 * Params:
 *      s      = the struct/class symbol
 *      t      = the type of the base class
 *      offset = offset of the base class in the struct/class
 */

@trusted
void symbol_struct_addBaseClass(ref Symbol s, type* t, uint offset)
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

void symbol_check(ref const Symbol s) @trusted
{
    //printf("symbol_check('%s',%p)\n",s.Sident.ptr,s);
    debug symbol_debug(&s);
    if (s.Stype) type_debug(s.Stype);
    assert(cast(uint)s.Sclass < cast(uint)SCMAX);
}

void symbol_tree_check(const(Symbol)* s)
{
    while (s)
    {   symbol_check(*s);
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
Symbol* lookupsym(const(char)* p)
{
    return scope_search(p,SCTglobal | SCTlocal);
}
}

@trusted
void symbol_free(Symbol* s)
{
    while (s)                           /* if symbol exists             */
    {   Symbol* sr;

debug
{
        if (debugy)
            printf("symbol_free('%s',%p)\n",s.Sident.ptr,s);
        symbol_debug(s);
        assert(/*s.Sclass != SC.unde &&*/ cast(int) s.Sclass < cast(int) SCMAX);
}
        {   type* t = s.Stype;

            if (t)
                type_debug(t);
            if (t && tyfunc(t.Tty) && s.Sfunc)
            {
                func_t* f = s.Sfunc;

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
private void symbol_undef(ref Symbol s)
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
SYMIDX symbol_add(Symbol* s)
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
void freesymtab(Symbol** stab,SYMIDX n1,SYMIDX n2)
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
 * Create a copy of a Symbol.
 */

@trusted
Symbol* symbol_copy(ref Symbol s)
{   Symbol* scopy;
    type* t;

    symbol_debug(&s);
    /*printf("symbol_copy(%s)\n",s.Sident.ptr);*/
    scopy = symbol_calloc(s.Sident.ptr[0 .. strlen(s.Sident.ptr)]);
    memcpy(scopy, &s, Symbol.sizeof - s.Sident.sizeof);
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

/***************************
 * Look down baseclass list to find sbase.
 * Returns:
 *      null    not found
 *      pointer to baseclass
 */

baseclass_t* baseclass_find(baseclass_t* bm,Classsym* sbase)
{
    symbol_debug(sbase);
    for (; bm; bm = bm.BCnext)
        if (bm.BCbase == sbase)
            break;
    return bm;
}

@trusted
baseclass_t* baseclass_find_nest(baseclass_t* bm,Classsym* sbase)
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

int baseclass_nitems(baseclass_t* b)
{   int i;

    for (i = 0; b; b = b.BCnext)
        i++;
    return i;
}

/*************************************
 * Reset Symbol so that it's now an "extern" to the next obj file being created.
 */
void symbol_reset(ref Symbol s)
{
    s.Soffset = 0;
    s.Sxtrnnum = 0;
    s.Stypidx = 0;
    s.Sflags &= ~(STRoutdef | SFLweak);
    s.Sdw_ref_idx = 0;
    if (s.Sclass == SC.global || s.Sclass == SC.comdat ||
        s.Sfl == FL.udata || s.Sclass == SC.static_)
    {   s.Sclass = SC.extern_;
        s.Sfl = FL.extern_;
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
tym_t symbol_pointerType(ref const Symbol s)
{
    return s.Stype.Tty & mTYimmutable ? TYimmutPtr : TYnptr;
}
