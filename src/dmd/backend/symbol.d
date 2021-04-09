/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/symbol.d
 */

module dmd.backend.symbol;

version (SCPP)
{
    version = COMPILE;
    version = SCPP_HTOD;
}
version (HTOD)
{
    version = COMPILE;
    version = SCPP_HTOD;
}
version (MARS)
{
    version = COMPILE;
    enum HYDRATE = false;
    enum DEHYDRATE = false;
}

version (COMPILE)
{
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

version (SCPP_HTOD)
{
    import cpp;
    import dtoken;
    import scopeh;
    import msgs2;
    import parser;
    import precomp;

    extern (C++) void baseclass_free(baseclass_t *b);
}


extern (C++):

nothrow:
@safe:

alias MEM_PH_MALLOC = mem_malloc;
alias MEM_PH_CALLOC = mem_calloc;
alias MEM_PH_FREE = mem_free;
alias MEM_PH_FREEFP = mem_freefp;
alias MEM_PH_STRDUP = mem_strdup;
alias MEM_PH_REALLOC = mem_realloc;
alias MEM_PARF_MALLOC = mem_malloc;
alias MEM_PARF_CALLOC = mem_calloc;
alias MEM_PARF_REALLOC = mem_realloc;
alias MEM_PARF_FREE = mem_free;
alias MEM_PARF_STRDUP = mem_strdup;

version (SCPP_HTOD)
    enum mBP = 0x20;
else
    import dmd.backend.code_x86;

void struct_free(struct_t *st) { }

@trusted
func_t* func_calloc() { return cast(func_t *) calloc(1, func_t.sizeof); }

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
version (COMPILE)
{
    if (!s) return;
    printf("symbol %p '%s'\n ",s,s.Sident.ptr);
    printf(" Sclass = "); WRclass(cast(SC) s.Sclass);
    printf(" Ssymnum = %d",cast(int)s.Ssymnum);
    printf(" Sfl = "); WRFL(cast(FL) s.Sfl);
    printf(" Sseg = %d\n",s.Sseg);
//  printf(" Ssize   = x%02x\n",s.Ssize);
    printf(" Soffset = x%04llx",cast(ulong)s.Soffset);
    printf(" Sweight = %d",s.Sweight);
    printf(" Sflags = x%04x",cast(uint)s.Sflags);
    printf(" Sxtrnnum = %d\n",s.Sxtrnnum);
    printf("  Stype   = %p",s.Stype);
version (SCPP_HTOD)
{
    printf(" Ssequence = %x", s.Ssequence);
    printf(" Scover  = %p", s.Scover);
}
    printf(" Sl      = %p",s.Sl);
    printf(" Sr      = %p\n",s.Sr);
    if (s.Sscope)
        printf(" Sscope = '%s'\n",s.Sscope.Sident.ptr);
    if (s.Stype)
        type_print(s.Stype);
    if (s.Sclass == SCmember || s.Sclass == SCfield)
    {
        printf("  Smemoff =%5lld", cast(long)s.Smemoff);
        printf("  Sbit    =%3d",s.Sbit);
        printf("  Swidth  =%3d\n",s.Swidth);
    }
version (SCPP_HTOD)
{
    if (s.Sclass == SCstruct)
    {
        printf("  Svbptr = %p, Svptr = %p\n",s.Sstruct.Svbptr,s.Sstruct.Svptr);
    }
}
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
int Symbol_Salignsize(Symbol* s)
{
    if (s.Salignment > 0)
        return s.Salignment;
    int alignsize = type_alignsize(s.Stype);

    /* Reduce alignment faults when SIMD vectors
     * are reinterpreted cast to other types with less alignment.
     */
    if (config.fpxmmregs && alignsize < 16 &&
        s.Sclass == SCauto &&
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
bool Symbol_Sisdead(const Symbol* s, bool anyInlineAsm)
{
    version (MARS)
        enum vol = false;
    else
        enum vol = true;
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
int Symbol_needThis(const Symbol* s)
{
    //printf("needThis() '%s'\n", Sident.ptr);

    debug assert(isclassmember(s));

    if (s.Sclass == SCmember || s.Sclass == SCfield)
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
    if (0 &&
        s.ty() & (mTYconst | mTYimmutable))
    {
        return false;
    }
    return true;
}


/***********************************
 * Get user name of symbol.
 */

@trusted
const(char)* symbol_ident(const Symbol *s)
{
version (SCPP_HTOD)
{
    __gshared char* noname = cast(char*)"__unnamed".ptr;
    switch (s.Sclass)
    {   case SCstruct:
            if (s.Sstruct.Salias)
                return s.Sstruct.Salias.Sident.ptr;
            else if (s.Sstruct.Sflags & STRnotagname)
                return noname;
            break;
        case SCenum:
            if (CPP)
            {   if (s.Senum.SEalias)
                    return s.Senum.SEalias.Sident.ptr;
                else if (s.Senum.SEflags & SENnotagname)
                    return noname;
            }
            break;

        case SCnamespace:
            if (s.Sident[0] == '?' && s.Sident.ptr[1] == '%')
                return cast(char*)"unique".ptr;        // an unnamed namespace
            break;

        default:
            break;
    }
}
    return s.Sident.ptr;
}

/****************************************
 * Create a new symbol.
 */

@trusted
Symbol * symbol_calloc(const(char)* id)
{
    return symbol_calloc(id, cast(uint)strlen(id));
}

@trusted
Symbol * symbol_calloc(const(char)* id, uint len)
{   Symbol *s;

    //printf("sizeof(symbol)=%d, sizeof(s.Sident)=%d, len=%d\n",sizeof(symbol),sizeof(s.Sident),(int)len);
    s = cast(Symbol *) mem_fmalloc(Symbol.sizeof - s.Sident.length + len + 1 + 5);
    memset(s,0,Symbol.sizeof - s.Sident.length);
version (SCPP_HTOD)
{
    s.Ssequence = pstate.STsequence;
    pstate.STsequence += 1;
    //if (s.Ssequence == 0x21) *cast(char*)0=0;
}
debug
{
    if (debugy)
        printf("symbol_calloc('%s') = %p\n",id,s);
    s.id = Symbol.IDsymbol;
}
    memcpy(s.Sident.ptr,id,len + 1);
    s.Ssymnum = SYMIDX.max;
    return s;
}

/****************************************
 * Create a symbol, given a name and type.
 */

@trusted
Symbol * symbol_name(const(char)* name,int sclass,type *t)
{
    return symbol_name(name, cast(uint)strlen(name), sclass, t);
}

Symbol * symbol_name(const(char)* name, uint len, int sclass, type *t)
{
    type_debug(t);
    Symbol *s = symbol_calloc(name, len);
    s.Sclass = cast(char) sclass;
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
    Funcsym *s;

    symbol_debug(sf);
    assert(tyfunc(sf.Stype.Tty));
    if (sf.Sclass == SCfuncalias)
        sf = sf.Sfunc.Falias;
    s = cast(Funcsym *)symbol_name(sf.Sident.ptr,SCfuncalias,sf.Stype);
    s.Sfunc.Falias = sf;

version (SCPP_HTOD)
    s.Scover = sf.Scover;

    return s;
}

/****************************************
 * Create a symbol, give it a name, storage class and type.
 */

@trusted
Symbol * symbol_generate(int sclass,type *t)
{
    __gshared int tmpnum;
    char[4 + tmpnum.sizeof * 3 + 1] name;

    //printf("symbol_generate(_TMP%d)\n", tmpnum);
    sprintf(name.ptr,"_TMP%d",tmpnum++);
    Symbol *s = symbol_name(name.ptr,sclass,t);
    //symbol_print(s);

version (MARS)
    s.Sflags |= SFLnodebug | SFLartifical;

    return s;
}

/****************************************
 * Generate an auto symbol, and add it to the symbol table.
 */

Symbol * symbol_genauto(type *t)
{   Symbol *s;

    s = symbol_generate(SCauto,t);
version (SCPP_HTOD)
{
    //printf("symbol_genauto(t) '%s'\n", s.Sident.ptr);
    if (pstate.STdefertemps)
    {   symbol_keep(s);
        s.Ssymnum = SYMIDX.max;
    }
    else
    {   s.Sflags |= SFLfree;
        if (init_staticctor)
        {   // variable goes into _STI_xxxx
            s.Ssymnum = SYMIDX.max;            // deferred allocation
//printf("test2\n");
//if (s.Sident[4] == '2') *(char*)0=0;
        }
        else
        {
            symbol_add(s);
        }
    }
}
else
{
    s.Sflags |= SFLfree;
    symbol_add(s);
}
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

@trusted
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
 * Input:
 *      s       the struct symbol
 *      name    field name
 *      t       the type of the field
 *      offset  offset of the field
 */

@trusted
void symbol_struct_addField(Symbol *s, const(char)* name, type *t, uint offset)
{
    Symbol *s2 = symbol_name(name, SCmember, t);
    s2.Smemoff = offset;
    list_append(&s.Sstruct.Sfldlst, s2);
}

/********************************
 * Define symbol in specified symbol table.
 * Returns:
 *      pointer to symbol
 */

version (SCPP_HTOD)
{
Symbol * defsy(const(char)* p,Symbol **parent)
{
   Symbol *s = symbol_calloc(p);
   symbol_addtotree(parent,s);
   return s;
}
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
version (SCPP_HTOD)
{
    if (s.Sscope)
        symbol_check(s.Sscope);
    if (s.Scover)
        symbol_check(s.Scover);
}
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

/********************************
 * Insert symbol in specified symbol table.
 */

version (SCPP_HTOD)
{

void symbol_addtotree(Symbol **parent,Symbol *s)
{  Symbol *rover;
   byte cmp;
   size_t len;
   const(char)* p;
   char c;

   //printf("symbol_addtotree('%s',%p)\n",s.Sident.ptr,*parent);
debug
{
   symbol_tree_check(*parent);
   assert(!s.Sl && !s.Sr);
}
   symbol_debug(s);
   p = s.Sident.ptr;
   c = *p;
   len = strlen(p);
   p++;
   rover = *parent;
   while (rover != null)                // while we haven't run out of tree
   {    symbol_debug(rover);
        if ((cmp = cast(byte)(c - rover.Sident[0])) == 0)
        {   cmp = cast(byte)memcmp(p,rover.Sident.ptr + 1,len); // compare identifier strings
            if (cmp == 0)               // found it if strings match
            {
                if (CPP)
                {   Symbol *s2;

                    switch (rover.Sclass)
                    {   case SCstruct:
                            s2 = rover;
                            goto case_struct;

                        case_struct:
                            if (s2.Sstruct.Sctor &&
                                !(s2.Sstruct.Sctor.Sfunc.Fflags & Fgen))
                                cpperr(EM_ctor_disallowed,p);   // no ctor allowed for class rover
                            s2.Sstruct.Sflags |= STRnoctor;
                            goto case_cover;

                        case_cover:
                            // Replace rover with the new symbol s, and
                            // have s 'cover' the tag symbol s2.
                            // BUG: memory leak on rover if s2!=rover
                            assert(!s2.Scover);
                            s.Sl = rover.Sl;
                            s.Sr = rover.Sr;
                            s.Scover = s2;
                            *parent = s;
                            rover.Sl = rover.Sr = null;
                            return;

                        case SCenum:
                            s2 = rover;
                            goto case_cover;

                        case SCtemplate:
                            s2 = rover;
                            s2.Stemplate.TMflags |= STRnoctor;
                            goto case_cover;

                        case SCalias:
                            s2 = rover.Smemalias;
                            if (s2.Sclass == SCstruct)
                                goto case_struct;
                            if (s2.Sclass == SCenum)
                                goto case_cover;
                            break;

                        default:
                            break;
                    }
                }
                synerr(EM_multiple_def,p - 1);  // symbol is already defined
                //symbol_undef(s);              // undefine the symbol
                return;
            }
        }
        parent = (cmp < 0) ?            /* if we go down left side      */
            &(rover.Sl) :              /* then get left child          */
            &(rover.Sr);               /* else get right child         */
        rover = *parent;                /* get child                    */
   }
   /* not in table, so insert into table        */
   *parent = s;                         /* link new symbol into tree    */
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

/*************************************
 * Search for symbol in symbol table.
 * Input:
 *      p .    identifier string
 *      rover . where to start looking
 * Returns:
 *      pointer to symbol (null if not found)
 */

version (SCPP_HTOD)
{

Symbol * findsy(const(char)* p,Symbol *rover)
{
/+
#if TX86 && __DMC__
    volatile int len;
    __asm
    {
#if !_WIN32
        push    DS
        pop     ES
#endif
        mov     EDI,p
        xor     AL,AL

        mov     BL,[EDI]
        mov     ECX,-1

        repne   scasb

        not     ECX
        mov     EDX,p

        dec     ECX
        inc     EDX

        mov     len,ECX
        mov     AL,BL

        mov     EBX,rover
        mov     ESI,EDX

        test    EBX,EBX
        je      L6

        cmp     AL,symbol.Sident[EBX]
        js      L2

        lea     EDI,symbol.Sident+1[EBX]
        je      L5

        mov     EBX,symbol.Sr[EBX]
        jmp     L3

L1:             mov     ECX,len
L2:             mov     EBX,symbol.Sl[EBX]

L3:             test    EBX,EBX
                je      L6

L4:             cmp     AL,symbol.Sident[EBX]
                js      L2

                lea     EDI,symbol.Sident+1[EBX]
                je      L5

                mov     EBX,symbol.Sr[EBX]
                jmp     L3

L5:             rep     cmpsb

                mov     ESI,EDX
                js      L1

                je      L6

                mov     EBX,symbol.Sr[EBX]
                mov     ECX,len

                test    EBX,EBX
                jne     L4

L6:     mov     EAX,EBX
    }
#else
+/
    size_t len;
    byte cmp;                           /* set to value of strcmp       */
    char c = *p;

    len = strlen(p);
    p++;                                // will pick up 0 on memcmp
    while (rover != null)               // while we haven't run out of tree
    {   symbol_debug(rover);
        if ((cmp = cast(byte)(c - rover.Sident[0])) == 0)
        {   cmp = cast(byte)memcmp(p,rover.Sident.ptr + 1,len); /* compare identifier strings */
            if (cmp == 0)
                return rover;           /* found it if strings match    */
        }
        rover = (cmp < 0) ? rover.Sl : rover.Sr;
    }
    return rover;                       // failed to find it
//#endif
}

}

/***********************************
 * Create a new symbol table.
 */

version (SCPP_HTOD)
{

void createglobalsymtab()
{
    assert(!scope_end);
    if (CPP)
        scope_push(null,cast(scope_fp)&findsy, SCTcglobal);
    else
        scope_push(null,cast(scope_fp)&findsy, SCTglobaltag);
    scope_push(null,cast(scope_fp)&findsy, SCTglobal);
}


void createlocalsymtab()
{
    assert(scope_end);
    if (!CPP)
        scope_push(null,cast(scope_fp)&findsy, SCTtag);
    scope_push(null,cast(scope_fp)&findsy, SCTlocal);
}


/***********************************
 * Delete current symbol table and back up one.
 */

void deletesymtab()
{   Symbol *root;

    root = cast(Symbol *)scope_pop();
    if (root)
    {
        if (funcsym_p)
            list_prepend(&funcsym_p.Sfunc.Fsymtree,root);
        else
            symbol_free(root);  // free symbol table
    }

    if (!CPP)
    {
        root = cast(Symbol *)scope_pop();
        if (root)
        {
            if (funcsym_p)
                list_prepend(&funcsym_p.Sfunc.Fsymtree,root);
            else
                symbol_free(root);      // free symbol table
        }
    }
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
    MEM_PARF_FREE(m);
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
        assert(/*s.Sclass != SCunde &&*/ cast(int) s.Sclass < cast(int) SCMAX);
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

version (SCPP_HTOD)
                token_free(f.Fbody);

                el_free(f.Fbaseinit);
                if (f.Fthunk && !(f.Fflags & Finstance))
                    MEM_PH_FREE(f.Fthunk);
                list_free(&f.Fthunks,cast(list_free_fp)&symbol_free);
              }
                list_free(&f.Fsymtree,cast(list_free_fp)&symbol_free);
                version (MARS)
                    f.typesTable.dtor();
                func_free(f);
            }
            switch (s.Sclass)
            {
version (SCPP_HTOD)
{
                case SClabel:
                    if (!s.Slabel)
                        synerr(EM_unknown_label,s.Sident.ptr);
                    break;
}
                case SCstruct:
version (SCPP_HTOD)
{
                  if (CPP)
                  {
                    struct_t *st = s.Sstruct;
                    assert(st);
                    list_free(&st.Sclassfriends,FPNULL);
                    list_free(&st.Sfriendclass,FPNULL);
                    list_free(&st.Sfriendfuncs,FPNULL);
                    list_free(&st.Scastoverload,FPNULL);
                    list_free(&st.Sopoverload,FPNULL);
                    list_free(&st.Svirtual,&MEM_PH_FREEFP);
                    list_free(&st.Sfldlst,FPNULL);
                    symbol_free(st.Sroot);
                    baseclass_t* b,bn;

                    for (b = st.Sbase; b; b = bn)
                    {   bn = b.BCnext;
                        list_free(&b.BCpublics,FPNULL);
                        baseclass_free(b);
                    }
                    for (b = st.Svirtbase; b; b = bn)
                    {   bn = b.BCnext;
                        baseclass_free(b);
                    }
                    for (b = st.Smptrbase; b; b = bn)
                    {   bn = b.BCnext;
                        list_free(&b.BCmptrlist,&MEM_PH_FREEFP);
                        baseclass_free(b);
                    }
                    for (b = st.Svbptrbase; b; b = bn)
                    {   bn = b.BCnext;
                        baseclass_free(b);
                    }
                    param_free(&st.Sarglist);
                    param_free(&st.Spr_arglist);
                    struct_free(st);
                  }
}
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
                case SCenum:
                    /* The actual member symbols are either in a local  */
                    /* table or on the member list of a class, so we    */
                    /* don't free them here.                            */
                    assert(s.Senum);
                    list_free(&s.Senum.SEenumlist,FPNULL);
                    MEM_PH_FREE(s.Senum);
                    s.Senum = null;
                    break;

version (SCPP_HTOD)
{
                case SCtemplate:
                {   template_t *tm = s.Stemplate;

                    list_free(&tm.TMinstances,FPNULL);
                    list_free(&tm.TMmemberfuncs,cast(list_free_fp)&tmf_free);
                    list_free(&tm.TMexplicit,cast(list_free_fp)&tme_free);
                    list_free(&tm.TMnestedexplicit,cast(list_free_fp)&tmne_free);
                    list_free(&tm.TMnestedfriends,cast(list_free_fp)&tmnf_free);
                    param_free(&tm.TMptpl);
                    param_free(&tm.TMptal);
                    token_free(tm.TMbody);
                    symbol_free(tm.TMpartial);
                    list_free(&tm.TMfriends,FPNULL);
                    MEM_PH_FREE(tm);
                    break;
                }
                case SCnamespace:
                    symbol_free(s.Snameroot);
                    list_free(&s.Susing,FPNULL);
                    break;

                case SCmemalias:
                case SCfuncalias:
                case SCadl:
                    list_free(&s.Spath,FPNULL);
                    break;
}
                case SCparameter:
                case SCregpar:
                case SCfastpar:
                case SCshadowreg:
                case SCregister:
                case SCauto:
                    vec_free(s.Srange);
static if (0)
{
                    goto case SCconst;
                case SCconst:
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
version (SCPP_HTOD)
{
            if (s.Scover)
                symbol_free(s.Scover);
}
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
  s.Sclass = SCunde;
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
    scopy = symbol_calloc(s.Sident.ptr);
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

/*******************************
 * Search list for a symbol with an identifier that matches.
 * Returns:
 *      pointer to matching symbol
 *      null if not found
 */

version (SCPP_HTOD)
{

Symbol * symbol_searchlist(symlist_t sl,const(char)* vident)
{
    debug
    int count = 0;

    //printf("searchlist(%s)\n",vident);
    foreach (sln; ListRange(sl))
    {
        Symbol* s = list_symbol(sln);
        symbol_debug(s);
        /*printf("\tcomparing with %s\n",s.Sident.ptr);*/
        if (strcmp(vident,s.Sident.ptr) == 0)
            return s;

        debug assert(++count < 300);          /* prevent infinite loops       */
    }
    return null;
}

/***************************************
 * Search for symbol in sequence of symbol tables.
 * Input:
 *      glbl    !=0 if global symbol table only
 */

Symbol *symbol_search(const(char)* id)
{
    Scope *sc;
    if (CPP)
    {   uint sct;

        sct = pstate.STclasssym ? SCTclass : 0;
        sct |= SCTmfunc | SCTlocal | SCTwith | SCTglobal | SCTnspace | SCTtemparg | SCTtempsym;
        return scope_searchx(id,sct,&sc);
    }
    else
        return scope_searchx(id,SCTglobal | SCTlocal,&sc);
}

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
            case SCstruct:
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

            case SCenum:
                assert(s.Senum);
                ph_hydrate(cast(void**)&s.Senum);
                if (CPP)
                {   ph_hydrate(cast(void**)&s.Senum.SEalias);
                    list_hydrate(&s.Senum.SEenumlist,cast(list_free_fp)&symbol_hydrate);
                }
                break;

            case SCtemplate:
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

            case SCnamespace:
                symbol_tree_hydrate(&s.Snameroot);
                list_hydrate(&s.Susing,cast(list_free_fp)&symbol_hydrate);
                break;

            case SCmemalias:
            case SCfuncalias:
            case SCadl:
                list_hydrate(&s.Spath,cast(list_free_fp)&symbol_hydrate);
                goto case SCalias;

            case SCalias:
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
            if (xsym_gen && s.Sclass == SCfunctempl)
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
            case SCstruct:
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

            case SCenum:
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

            case SCtemplate:
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

            case SCnamespace:
                symbol_tree_dehydrate(&s.Snameroot);
                list_dehydrate(&s.Susing,cast(list_free_fp)&symbol_dehydrate);
                break;

            case SCmemalias:
            case SCfuncalias:
            case SCadl:
                list_dehydrate(&s.Spath,cast(list_free_fp)&symbol_dehydrate);
            case SCalias:
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


/***************************
 * Hydrate threaded list of symbols.
 * Input:
 *      *psx    start of threaded list
 *      *parent root of symbol table to add symbol into
 *      flag    !=0 means add onto existing stuff
 *              0 means hydrate in place
 */

version (SCPP_HTOD)
{

@trusted
void symbol_symdefs_hydrate(Symbol **psx,Symbol **parent,int flag)
{   Symbol *s;

    //printf("symbol_symdefs_hydrate(flag = %d)\n",flag);
debug
{
    int count = 0;

    if (flag) symbol_tree_check(*parent);
}
    for (; *psx; psx = &s.Snext)
    {
        //printf("%p ",*psx);
debug
        count++;

        s = dohydrate ? symbol_hydrate(psx) : *psx;

        //if (s.Sclass == SCstruct)
        //printf("symbol_symdefs_hydrate(%p, '%s')\n",s,s.Sident.ptr);
        symbol_debug(s);
static if (0)
{
        if (tyfunc(s.Stype.Tty))
        {   Outbuffer buf;
            char *p1;

            p1 = param_tostring(&buf,s.Stype);
            printf("'%s%s'\n",cpp_prettyident(s),p1);
        }
}
        type_debug(s.Stype);
        if (flag)
        {   char *p;
            Symbol **ps;
            Symbol *rover;
            char c;
            size_t len;

            p = s.Sident.ptr;
            c = *p;

            // Put symbol s into symbol table

static if (MMFIO)
{
            if (s.Sl || s.Sr)         // avoid writing to page if possible
                s.Sl = s.Sr = null;
}
else
                s.Sl = s.Sr = null;

            len = strlen(p);
            p++;
            ps = parent;
            while ((rover = *ps) != null)
            {   byte cmp;

                if ((cmp = cast(byte)(c - rover.Sident[0])) == 0)
                {   cmp = cast(byte)memcmp(p,rover.Sident.ptr + 1,len); // compare identifier strings
                    if (cmp == 0)
                    {
                        if (CPP && tyfunc(s.Stype.Tty) && tyfunc(rover.Stype.Tty))
                        {   Symbol **psym;
                            Symbol *sn;
                            Symbol *so;

                            so = s;
                            do
                            {
                                // Tack onto end of overloaded function list
                                for (psym = &rover; *psym; psym = &(*psym).Sfunc.Foversym)
                                {   if (cpp_funccmp(so, *psym))
                                    {   //printf("function '%s' already in list\n",so.Sident.ptr);
                                        goto L2;
                                    }
                                }
                                //printf("appending '%s' to rover\n",so.Sident.ptr);
                                *psym = so;
                            L2:
                                sn = so.Sfunc.Foversym;
                                so.Sfunc.Foversym = null;
                                so = sn;
                            } while (so);
                            //printf("overloading...\n");
                        }
                        else if (s.Sclass == SCstruct)
                        {
                            if (CPP && rover.Scover)
                            {   ps = &rover.Scover;
                                rover = *ps;
                            }
                            else
                            if (rover.Sclass == SCstruct)
                            {
                                if (!(s.Stype.Tflags & TFforward))
                                {   // Replace rover with s in symbol table
                                    //printf("Replacing '%s'\n",s.Sident.ptr);
                                    *ps = s;
                                    s.Sl = rover.Sl;
                                    s.Sr = rover.Sr;
                                    rover.Sl = rover.Sr = null;
                                    rover.Stype.Ttag = cast(Classsym *)s;
                                    symbol_keep(rover);
                                }
                                else
                                    s.Stype.Ttag = cast(Classsym *)rover;
                            }
                        }
                        goto L1;
                    }
                }
                ps = (cmp < 0) ?        /* if we go down left side      */
                    &rover.Sl :
                    &rover.Sr;
            }
            *ps = s;
            if (s.Sclass == SCcomdef)
            {   s.Sclass = SCglobal;
                outcommon(s,type_size(s.Stype));
            }
        }
  L1:
    } // for
debug
{
    if (flag) symbol_tree_check(*parent);
    printf("%d symbols hydrated\n",count);
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


/*****************************
 * Go through symbol table preparing it to be written to a precompiled
 * header. That means removing references to things in the .OBJ file.
 */

version (SCPP_HTOD)
{

@trusted
void symboltable_clean(Symbol *s)
{
    while (s)
    {
        struct_t *st;

        //printf("clean('%s')\n",s.Sident.ptr);
        if (config.fulltypes != CVTDB && s.Sxtrnnum && s.Sfl != FLreg)
            s.Sxtrnnum = 0;    // eliminate debug info type index
        switch (s.Sclass)
        {
            case SCstruct:
                s.Stypidx = 0;
                st = s.Sstruct;
                assert(st);
                symboltable_clean(st.Sroot);
                //list_apply(&st.Sfldlst,cast(list_free_fp)&symboltable_clean);
                break;

            case SCtypedef:
            case SCenum:
                s.Stypidx = 0;
                break;

            case SCtemplate:
            {   template_t *tm = s.Stemplate;

                list_apply(&tm.TMinstances,cast(list_free_fp)&symboltable_clean);
                break;
            }

            case SCnamespace:
                symboltable_clean(s.Snameroot);
                break;

            default:
                if (s.Sxtrnnum && s.Sfl != FLreg)
                    s.Sxtrnnum = 0;    // eliminate external symbol index
                if (tyfunc(s.Stype.Tty))
                {
                    func_t *f = s.Sfunc;
                    SYMIDX si;

                    debug assert(f);

                    list_apply(&f.Fsymtree,cast(list_free_fp)&symboltable_clean);
                    for (si = 0; si < f.Flocsym.length; si++)
                        symboltable_clean(f.Flocsym[si]);
                    if (f.Foversym)
                        symboltable_clean(f.Foversym);
                    if (f.Fexplicitspec)
                        symboltable_clean(f.Fexplicitspec);
                }
                break;
        }
        if (s.Sl)
            symboltable_clean(s.Sl);
        if (s.Scover)
            symboltable_clean(s.Scover);
        s = s.Sr;
    }
}

}

version (SCPP_HTOD)
{

/*
 * Balance our symbol tree in place. This is nice for precompiled headers, since they
 * will typically be written out once, but read in many times. We balance the tree in
 * place by traversing the tree inorder and writing the pointers out to an ordered
 * list. Once we have a list of symbol pointers, we can create a tree by recursively
 * dividing the list, using the midpoint of each division as the new root for that
 * subtree.
 */

struct Balance
{
    uint nsyms;
    Symbol **array;
    uint index;
}

private __gshared Balance balance;

private void count_symbols(Symbol *s)
{
    while (s)
    {
        balance.nsyms++;
        switch (s.Sclass)
        {
            case SCnamespace:
                symboltable_balance(&s.Snameroot);
                break;

            case SCstruct:
                symboltable_balance(&s.Sstruct.Sroot);
                break;

            default:
                break;
        }
        count_symbols(s.Sl);
        s = s.Sr;
    }
}

private void place_in_array(Symbol *s)
{
    while (s)
    {
        place_in_array(s.Sl);
        balance.array[balance.index++] = s;
        s = s.Sr;
    }
}

/*
 * Create a tree in place by subdividing between lo and hi inclusive, using i
 * as the root for the tree. When the lo-hi interval is one, we've either
 * reached a leaf or an empty node. We subdivide below i by halving the interval
 * between i and lo, and using i-1 as our new hi point. A similar subdivision
 * is created above i.
 */
private Symbol * create_tree(int i, int lo, int hi)
{
    Symbol *s = balance.array[i];

    if (i < lo || i > hi)               /* empty node ? */
        return null;

    assert(cast(uint) i < balance.nsyms);
    if (i == lo && i == hi) {           /* leaf node ? */
        s.Sl = null;
        s.Sr = null;
        return s;
    }

    s.Sl = create_tree((i + lo) / 2, lo, i - 1);
    s.Sr = create_tree((i + hi + 1) / 2, i + 1, hi);

    return s;
}

enum METRICS = false;

void symboltable_balance(Symbol **ps)
{
    Balance balancesave;
static if (METRICS)
{
    clock_t ticks;

    printf("symbol table before balance:\n");
    symbol_table_metrics();
    ticks = clock();
}
    balancesave = balance;              // so we can nest
    balance.nsyms = 0;
    count_symbols(*ps);
    //printf("Number of global symbols = %d\n",balance.nsyms);

    // Use malloc instead of mem because of pagesize limits
    balance.array = cast(Symbol **) malloc(balance.nsyms * (Symbol *).sizeof);
    if (!balance.array)
        goto Lret;                      // no error, just don't balance

    balance.index = 0;
    place_in_array(*ps);

    *ps = create_tree(balance.nsyms / 2, 0, balance.nsyms - 1);

    free(balance.array);
static if (METRICS)
{
    printf("time to balance: %ld\n", clock() - ticks);
    printf("symbol table after balance:\n");
    symbol_table_metrics();
}
Lret:
    balance = balancesave;
}

}

/*****************************************
 * Symbol table search routine for members of structs, given that
 * we don't know which struct it is in.
 * Give error message if it appears more than once.
 * Returns:
 *      null            member not found
 *      symbol*         symbol matching member
 */

version (SCPP_HTOD)
{

struct Paramblock       // to minimize stack usage in helper function
{   const(char)* id;     // identifier we are looking for
    Symbol *sm;         // where to put result
    Symbol *s;
}

private void membersearchx(Paramblock *p,Symbol *s)
{
    while (s)
    {
        symbol_debug(s);

        switch (s.Sclass)
        {
            case SCstruct:
                foreach (sl; ListRange(s.Sstruct.Sfldlst))
                {
                    Symbol* sm = list_symbol(sl);
                    symbol_debug(sm);
                    if ((sm.Sclass == SCmember || sm.Sclass == SCfield) &&
                        strcmp(p.id,sm.Sident.ptr) == 0)
                    {
                        if (p.sm && p.sm.Smemoff != sm.Smemoff)
                            synerr(EM_ambig_member,p.id,s.Sident.ptr,p.s.Sident.ptr);       // ambiguous reference to id
                        p.s = s;
                        p.sm = sm;
                        break;
                    }
                }
                break;

            default:
                break;
        }

        if (s.Sl)
            membersearchx(p,s.Sl);
        s = s.Sr;
    }
}

Symbol *symbol_membersearch(const(char)* id)
{
    list_t sl;
    Paramblock pb;
    Scope *sc;

    pb.id = id;
    pb.sm = null;
    for (sc = scope_end; sc; sc = sc.next)
    {
        if (sc.sctype & (CPP ? (SCTglobal | SCTlocal) : (SCTglobaltag | SCTtag)))
            membersearchx(cast(Paramblock *)&pb,cast(Symbol *)sc.root);
    }
    return pb.sm;
}

/*******************************************
 * Generate debug info for global struct tag symbols.
 */

private void symbol_gendebuginfox(Symbol *s)
{
    for (; s; s = s.Sr)
    {
        if (s.Sl)
            symbol_gendebuginfox(s.Sl);
        if (s.Scover)
            symbol_gendebuginfox(s.Scover);
        switch (s.Sclass)
        {
            case SCenum:
                if (CPP && s.Senum.SEflags & SENnotagname)
                    break;
                goto Lout;
            case SCstruct:
                if (s.Sstruct.Sflags & STRanonymous)
                    break;
                goto Lout;
            case SCtypedef:
            Lout:
                if (!s.Stypidx)
                    cv_outsym(s);
                break;

            default:
                break;
        }
    }
}

void symbol_gendebuginfo()
{   Scope *sc;

    for (sc = scope_end; sc; sc = sc.next)
    {
        if (sc.sctype & (SCTglobaltag | SCTglobal))
            symbol_gendebuginfox(cast(Symbol *)sc.root);
    }
}

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
    if (s.Sclass == SCglobal || s.Sclass == SCcomdat ||
        s.Sfl == FLudata || s.Sclass == SCstatic)
    {   s.Sclass = SCextern;
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

}
