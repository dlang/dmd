
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stddef.h>
#include <time.h>
#include <assert.h>

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "declaration.h"
#include "statement.h"
#include "enum.h"
#include "aggregate.h"
#include "init.h"
#include "attrib.h"
#include "lexer.h"
#include "dsymbol.h"
#include "id.h"
#include "ctfe.h"
#include "rmem.h"

// Back end
#include "cc.h"
#include "global.h"
#include "oper.h"
#include "code.h"
#include "type.h"
#include "dt.h"
#include "cgcv.h"
#include "outbuf.h"
#include "irstate.h"

void slist_add(Symbol *s);
void slist_reset();

Classsym *fake_classsym(Identifier *id);
Symbols *Symbols_create();

/********************************* SymbolDeclaration ****************************/

Symbol *SymbolDeclaration::toSymbol()
{
    return dsym->toInitializer();
}

/*************************************
 * Helper
 */

Symbol *Dsymbol::toSymbolX(const char *prefix, int sclass, type *t, const char *suffix)
{
    //printf("Dsymbol::toSymbolX('%s')\n", prefix);
    const char *n = mangle();
    assert(n);
    size_t nlen = strlen(n);
    size_t prefixlen = strlen(prefix);

    size_t idlen = 2 + nlen + sizeof(size_t) * 3 + prefixlen + strlen(suffix) + 1;

    char idbuf[20];
    char *id = idbuf;
    if (idlen > sizeof(idbuf))
    {   id = (char *)malloc(idlen);
        assert(id);
    }

    int nwritten = sprintf(id,"_D%s%llu%s%s", n, (unsigned long long)prefixlen, prefix, suffix);
    assert((unsigned)nwritten < idlen);         // nwritten does not include the terminating 0 char

    Symbol *s = symbol_name(id, sclass, t);

    if (id != idbuf)
        free(id);

    //printf("-Dsymbol::toSymbolX() %s\n", id);
    return s;
}

/*************************************
 */

Symbol *Dsymbol::toSymbol()
{
    printf("Dsymbol::toSymbol() '%s', kind = '%s'\n", toChars(), kind());
#ifdef DEBUG
    halt();
#endif
    assert(0);          // BUG: implement
    return NULL;
}

/*********************************
 * Generate import symbol from symbol.
 */

Symbol *Dsymbol::toImport()
{
    if (!isym)
    {
        if (!csym)
            csym = toSymbol();
        isym = toImport(csym);
    }
    return isym;
}

/*************************************
 */

Symbol *Dsymbol::toImport(Symbol *sym)
{
    char *id;
    char *n;
    Symbol *s;
    type *t;

    //printf("Dsymbol::toImport('%s')\n", sym->Sident);
    n = sym->Sident;
    id = (char *) alloca(6 + strlen(n) + 1 + sizeof(type_paramsize(sym->Stype))*3 + 1);
    if (sym->Stype->Tmangle == mTYman_std && tyfunc(sym->Stype->Tty))
    {
        if (config.exe == EX_WIN64)
            sprintf(id,"__imp_%s",n);
        else
            sprintf(id,"_imp__%s@%lu",n,(unsigned long)type_paramsize(sym->Stype));
    }
    else if (sym->Stype->Tmangle == mTYman_d)
    {
        sprintf(id,(config.exe == EX_WIN64) ? "__imp_%s" : "_imp_%s",n);
    }
    else
    {
        sprintf(id,(config.exe == EX_WIN64) ? "__imp__%s" : "_imp__%s",n);
    }
    t = type_alloc(TYnptr | mTYconst);
    t->Tnext = sym->Stype;
    t->Tnext->Tcount++;
    t->Tmangle = mTYman_c;
    t->Tcount++;
    s = symbol_calloc(id);
    s->Stype = t;
    s->Sclass = SCextern;
    s->Sfl = FLextern;
    slist_add(s);
    return s;
}

/*************************************
 */

Symbol *VarDeclaration::toSymbol()
{
    //printf("VarDeclaration::toSymbol(%s)\n", toChars());
    //if (needThis()) *(char*)0=0;
    assert(!needThis());
    if (!csym)
    {
        TYPE *t;
        const char *id;

        if (isDataseg())
            id = mangle();
        else
            id = ident->toChars();
        Symbol *s = symbol_calloc(id);
        s->Salignment = alignment;
        if (storage_class & STCtemp)
            s->Sflags |= SFLartifical;

        if (storage_class & (STCout | STCref))
        {
            // should be TYref, but problems in back end
            t = type_pointer(type->toCtype());
        }
        else if (storage_class & STClazy)
        {
            if (config.exe == EX_WIN64 && isParameter())
                t = type_fake(TYnptr);
            else
                t = type_fake(TYdelegate);          // Tdelegate as C type
            t->Tcount++;
        }
        else if (isParameter())
        {
            if (config.exe == EX_WIN64 && type->size(Loc()) > REGSIZE)
            {
                // should be TYref, but problems in back end
                t = type_pointer(type->toCtype());
            }
            else
            {
                t = type->toCParamtype();
                t->Tcount++;
            }
        }
        else
        {
            t = type->toCtype();
            t->Tcount++;
        }

        if (isDataseg())
        {
            if (isThreadlocal())
            {   /* Thread local storage
                 */
                TYPE *ts = t;
                ts->Tcount++;   // make sure a different t is allocated
                type_setty(&t, t->Tty | mTYthread);
                ts->Tcount--;

                if (global.params.vtls)
                {
                    char *p = loc.toChars();
                    fprintf(global.stdmsg, "%s: %s is thread local\n", p ? p : "", toChars());
                    if (p)
                        mem.free(p);
                }
            }
            s->Sclass = SCextern;
            s->Sfl = FLextern;
            slist_add(s);
            /* if it's global or static, then it needs to have a qualified but unmangled name.
             * This gives some explanation of the separation in treating name mangling.
             * It applies to PDB format, but should apply to CV as PDB derives from CV.
             *    http://msdn.microsoft.com/en-us/library/ff553493(VS.85).aspx
             */
            s->prettyIdent = toPrettyChars();
        }
        else
        {
            s->Sclass = SCauto;
            s->Sfl = FLauto;

            if (nestedrefs.dim)
            {
                /* Symbol is accessed by a nested function. Make sure
                 * it is not put in a register, and that the optimizer
                 * assumes it is modified across function calls and pointer
                 * dereferences.
                 */
                //printf("\tnested ref, not register\n");
                type_setcv(&t, t->Tty | mTYvolatile);
            }
        }

        if (ident == Id::va_argsave)
            /* __va_argsave is set outside of the realm of the optimizer,
             * so we tell the optimizer to leave it alone
             */
            type_setcv(&t, t->Tty | mTYvolatile);

        mangle_t m = 0;
        switch (linkage)
        {
            case LINKwindows:
                m = mTYman_std;
                break;

            case LINKpascal:
                m = mTYman_pas;
                break;

            case LINKc:
            case LINKobjc:
                m = mTYman_c;
                break;

            case LINKd:
                m = mTYman_d;
                break;

            case LINKcpp:
            {
                m = mTYman_cpp;

                s->Sflags |= SFLpublic;
                Dsymbol *parent = toParent();
                ClassDeclaration *cd = parent->isClassDeclaration();
                if (cd)
                {
                    ::type *tc = cd->type->toCtype();
                    s->Sscope = tc->Tnext->Ttag;
                }
                StructDeclaration *sd = parent->isStructDeclaration();
                if (sd)
                {
                    ::type *ts = sd->type->toCtype();
                    s->Sscope = ts->Ttag;
                }
                break;
            }
            default:
                printf("linkage = %d\n", linkage);
                assert(0);
        }
        type_setmangle(&t, m);
        s->Stype = t;

        csym = s;
    }
    return csym;
}

/*************************************
 */

Symbol *ClassInfoDeclaration::toSymbol()
{
    return cd->toSymbol();
}

/*************************************
 */

Symbol *TypeInfoDeclaration::toSymbol()
{
    //printf("TypeInfoDeclaration::toSymbol(%s), linkage = %d\n", toChars(), linkage);
    return VarDeclaration::toSymbol();
}

/*************************************
 */

Symbol *TypeInfoClassDeclaration::toSymbol()
{
    //printf("TypeInfoClassDeclaration::toSymbol(%s), linkage = %d\n", toChars(), linkage);
    assert(tinfo->ty == Tclass);
    TypeClass *tc = (TypeClass *)tinfo;
    return tc->sym->toSymbol();
}

/*************************************
 */

Symbol *FuncAliasDeclaration::toSymbol()
{
    return funcalias->toSymbol();
}

/*************************************
 */

Symbol *FuncDeclaration::toSymbol()
{
    if (!csym)
    {   Symbol *s;
        TYPE *t;
        const char *id;

        id = mangleExact();

        //printf("FuncDeclaration::toSymbol(%s %s)\n", kind(), toChars());
        //printf("\tid = '%s'\n", id);
        //printf("\ttype = %s\n", type->toChars());
        s = symbol_calloc(id);
        slist_add(s);

        {
            s->prettyIdent = toPrettyChars();
            s->Sclass = SCglobal;
            symbol_func(s);
            func_t *f = s->Sfunc;
            if (isVirtual() && vtblIndex != -1)
                f->Fflags |= Fvirtual;
            else if (isMember2() && isStatic())
                f->Fflags |= Fstatic;
            f->Fstartline.Slinnum = loc.linnum;
            f->Fstartline.Sfilename = (char *)loc.filename;
            if (endloc.linnum)
            {   f->Fendline.Slinnum = endloc.linnum;
                f->Fendline.Sfilename = (char *)endloc.filename;
            }
            else
            {   f->Fendline.Slinnum = loc.linnum;
                f->Fendline.Sfilename = (char *)loc.filename;
            }
            t = type->toCtype();
        }

        mangle_t msave = t->Tmangle;
        if (isMain())
        {
            t->Tty = TYnfunc;
            t->Tmangle = mTYman_c;
        }
        else
        {
            switch (linkage)
            {
                case LINKwindows:
                    t->Tmangle = mTYman_std;
                    break;

                case LINKpascal:
                    t->Tty = TYnpfunc;
                    t->Tmangle = mTYman_pas;
                    break;

                case LINKc:
                    t->Tmangle = mTYman_c;
                    break;

                case LINKd:
                    t->Tmangle = mTYman_d;
                    break;

                case LINKobjc:
                    // using C mangling only for global functions
                    t->Tmangle = isMember2() ? mTYman_d : mTYman_c;
                    break;

                case LINKcpp:
                {   t->Tmangle = mTYman_cpp;
                    if (isThis() && !global.params.is64bit && global.params.isWindows)
                    {
                        if (((TypeFunction *)type)->varargs == 1)
                            t->Tty = TYnfunc;
                        else
                            t->Tty = TYmfunc;
                    }
                    s->Sflags |= SFLpublic;
                    Dsymbol *parent = toParent();
                    ClassDeclaration *cd = parent->isClassDeclaration();
                    if (cd)
                    {
                        ::type *tc = cd->type->toCtype();
                        s->Sscope = tc->Tnext->Ttag;
                    }
                    StructDeclaration *sd = parent->isStructDeclaration();
                    if (sd)
                    {
                        ::type *ts = sd->type->toCtype();
                        s->Sscope = ts->Ttag;
                    }
                    if (isCtorDeclaration())
                        s->Sfunc->Fflags |= Fctor;
                    if (isDtorDeclaration())
                        s->Sfunc->Fflags |= Fdtor;
                    break;
                }
                default:
                    printf("linkage = %d\n", linkage);
                    assert(0);
            }
        }
        if (msave)
            assert(msave == t->Tmangle);
        //printf("Tty = %x, mangle = x%x\n", t->Tty, t->Tmangle);
        t->Tcount++;
        s->Stype = t;
        //s->Sfielddef = this;

        csym = s;
    }
    return csym;
}

/*************************************
 */

Symbol *FuncDeclaration::toThunkSymbol(int offset)
{
    toSymbol();

    Symbol *sthunk = symbol_generate(SCstatic, csym->Stype);
    sthunk->Sflags |= SFLimplem;
    cod3_thunk(sthunk, csym, 0, TYnptr, -offset, -1, 0);
    return sthunk;
}


/**************************************
 * Fake a struct symbol.
 */

Classsym *fake_classsym(Identifier *id)
{
    TYPE *t = type_struct_class(id->toChars(),8,0,
        NULL,NULL,
        false, false, true);

    t->Ttag->Sstruct->Sflags = STRglobal;
    t->Tflags |= TFsizeunknown | TFforward;
    assert(t->Tmangle == 0);
    t->Tmangle = mTYman_d;
    return t->Ttag;
}

/*************************************
 * Create the "ClassInfo" symbol
 */

static Classsym *scc;

Symbol *ClassDeclaration::toSymbol()
{
    if (!csym)
    {
        Symbol *s;

        if (!scc)
            scc = fake_classsym(Id::ClassInfo);

        s = toSymbolX("__Class", SCextern, scc->Stype, "Z");
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        csym = s;
        slist_add(s);
    }
    return csym;
}

/*************************************
 * Create the "InterfaceInfo" symbol
 */

Symbol *InterfaceDeclaration::toSymbol()
{
    if (!csym)
    {
        Symbol *s;

        if (!scc)
            scc = fake_classsym(Id::ClassInfo);

        s = toSymbolX("__Interface", SCextern, scc->Stype, "Z");
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        csym = s;
        slist_add(s);
    }
    return csym;
}

/*************************************
 * Create the "ModuleInfo" symbol
 */

Symbol *Module::toSymbol()
{
    if (!csym)
    {
        if (!scc)
            scc = fake_classsym(Id::ClassInfo);

        Symbol *s = toSymbolX("__ModuleInfo", SCextern, scc->Stype, "Z");
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        csym = s;
        slist_add(s);
    }
    return csym;
}

/*************************************
 * This is accessible via the ClassData, but since it is frequently
 * needed directly (like for rtti comparisons), make it directly accessible.
 */

Symbol *ClassDeclaration::toVtblSymbol()
{
    if (!vtblsym)
    {
        Symbol *s;
        TYPE *t;

        if (!csym)
            toSymbol();

        t = type_allocn(TYnptr | mTYconst, tsvoid);
        t->Tmangle = mTYman_d;
        s = toSymbolX("__vtbl", SCextern, t, "Z");
        s->Sflags |= SFLnodebug;
        s->Sfl = FLextern;
        vtblsym = s;
        slist_add(s);
    }
    return vtblsym;
}

/**********************************
 * Create the static initializer for the struct/class.
 */

Symbol *AggregateDeclaration::toInitializer()
{
    if (!sinit)
    {
        Classsym *stag = fake_classsym(Id::ClassInfo);
        Symbol *s = toSymbolX("__init", SCextern, stag->Stype, "Z");
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        StructDeclaration *sd = isStructDeclaration();
        if (sd)
            s->Salignment = sd->alignment;
        slist_add(s);
        sinit = s;
    }
    return sinit;
}

Symbol *TypedefDeclaration::toInitializer()
{
    if (!sinit)
    {
        Classsym *stag = fake_classsym(Id::ClassInfo);
        Symbol *s = toSymbolX("__init", SCextern, stag->Stype, "Z");
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        slist_add(s);
        sinit = s;
    }
    return sinit;
}

Symbol *EnumDeclaration::toInitializer()
{
    if (!sinit)
    {
        Classsym *stag = fake_classsym(Id::ClassInfo);
        Identifier *ident_save = ident;
        if (!ident)
            ident = Lexer::uniqueId("__enum");
        Symbol *s = toSymbolX("__init", SCextern, stag->Stype, "Z");
        ident = ident_save;
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        slist_add(s);
        sinit = s;
    }
    return sinit;
}


/******************************************
 */

Symbol *Module::toModuleAssert()
{
    if (!massert)
    {
        type *t = type_function(TYjfunc, NULL, 0, false, tsvoid);
        t->Tmangle = mTYman_d;

        massert = toSymbolX("__assert", SCextern, t, "FiZv");
        massert->Sfl = FLextern;
        massert->Sflags |= SFLnodebug;
        slist_add(massert);
    }
    return massert;
}

Symbol *Module::toModuleUnittest()
{
    if (!munittest)
    {
        type *t = type_function(TYjfunc, NULL, 0, false, tsvoid);
        t->Tmangle = mTYman_d;

        munittest = toSymbolX("__unittest_fail", SCextern, t, "FiZv");
        munittest->Sfl = FLextern;
        munittest->Sflags |= SFLnodebug;
        slist_add(munittest);
    }
    return munittest;
}

/******************************************
 */

Symbol *Module::toModuleArray()
{
    if (!marray)
    {
        type *t = type_function(TYjfunc, NULL, 0, false, tsvoid);
        t->Tmangle = mTYman_d;

        marray = toSymbolX("__array", SCextern, t, "Z");
        marray->Sfl = FLextern;
        marray->Sflags |= SFLnodebug;
        slist_add(marray);
    }
    return marray;
}

/********************************************
 * Determine the right symbol to look up
 * an associative array element.
 * Input:
 *      flags   0       don't add value signature
 *              1       add value signature
 */

Symbol *TypeAArray::aaGetSymbol(const char *func, int flags)
{
#ifdef DEBUG
        assert((flags & ~1) == 0);
#endif

        // Dumb linear symbol table - should use associative array!
        static Symbols *sarray = NULL;

        //printf("aaGetSymbol(func = '%s', flags = %d, key = %p)\n", func, flags, key);
        char *id = (char *)alloca(3 + strlen(func) + 1);
        sprintf(id, "_aa%s", func);
        if (!sarray)
            sarray = Symbols_create();

        // See if symbol is already in sarray
        for (size_t i = 0; i < sarray->dim; i++)
        {   Symbol *s = (*sarray)[i];
            if (strcmp(id, s->Sident) == 0)
            {
#ifdef DEBUG
                assert(s);
#endif
                return s;                       // use existing Symbol
            }
        }

        // Create new Symbol

        Symbol *s = symbol_calloc(id);
        slist_add(s);
        s->Sclass = SCextern;
        s->Ssymnum = -1;
        symbol_func(s);

        type *t = type_function(TYnfunc, NULL, 0, false, next->toCtype());
        t->Tmangle = mTYman_c;
        s->Stype = t;

        sarray->push(s);                        // remember it
        return s;
}

/*****************************************************/
/*                   CTFE stuff                      */
/*****************************************************/

Symbol* StructLiteralExp::toSymbol()
{
    if (sym) return sym;
    TYPE *t = type_alloc(TYint);
    t->Tcount++;
    Symbol *s = symbol_calloc("internal");
    s->Sclass = SCstatic;
    s->Sfl = FLextern;
    s->Sflags |= SFLnodebug;
    s->Stype = t;
    sym = s;
    dt_t *d = NULL;
    toDt(&d);
    s->Sdt = d;
    slist_add(s);
    outdata(s);
    return sym;
}

Symbol* ClassReferenceExp::toSymbol()
{
    if (value->sym) return value->sym;
    TYPE *t = type_alloc(TYint);
    t->Tcount++;
    Symbol *s = symbol_calloc("internal");
    s->Sclass = SCstatic;
    s->Sfl = FLextern;
    s->Sflags |= SFLnodebug;
    s->Stype = t;
    value->sym = s;
    dt_t *d = NULL;
    toInstanceDt(&d);
    s->Sdt = d;
    slist_add(s);
    outdata(s);
    return value->sym;
}
