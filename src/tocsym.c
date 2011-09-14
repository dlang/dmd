
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
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

#if __sun&&__SVR4
#include <alloca.h>
#endif

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

/********************************* SymbolDeclaration ****************************/

SymbolDeclaration::SymbolDeclaration(Loc loc, Symbol *s, StructDeclaration *dsym)
    : Declaration(new Identifier(s->Sident, TOKidentifier))
{
    this->loc = loc;
    sym = s;
    this->dsym = dsym;
    storage_class |= STCconst;
}

Symbol *SymbolDeclaration::toSymbol()
{
    return sym;
}

/*************************************
 * Helper
 */

Symbol *Dsymbol::toSymbolX(const char *prefix, int sclass, type *t, const char *suffix)
{
    Symbol *s;
    char *id;
    const char *n;
    size_t nlen;

    //printf("Dsymbol::toSymbolX('%s')\n", prefix);
    n = mangle();
    assert(n);
    nlen = strlen(n);
#if 0
    if (nlen > 2 && n[0] == '_' && n[1] == 'D')
    {
        nlen -= 2;
        n += 2;
    }
#endif
    id = (char *) alloca(2 + nlen + sizeof(size_t) * 3 + strlen(prefix) + strlen(suffix) + 1);
    sprintf(id,"_D%s%zu%s%s", n, strlen(prefix), prefix, suffix);
#if 0
    if (global.params.isWindows &&
        (type_mangle(t) == mTYman_c || type_mangle(t) == mTYman_std))
        id++;                   // Windows C mangling will put the '_' back in
#endif
    s = symbol_name(id, sclass, t);
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
        sprintf(id,"_imp__%s@%lu",n,(unsigned long)type_paramsize(sym->Stype));
    }
    else if (sym->Stype->Tmangle == mTYman_d)
        sprintf(id,"_imp_%s",n);
    else
        sprintf(id,"_imp__%s",n);
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
    {   Symbol *s;
        TYPE *t;
        const char *id;

        if (isDataseg())
            id = mangle();
        else
            id = ident->toChars();
        s = symbol_calloc(id);

        if (storage_class & (STCout | STCref))
        {
            if (global.params.symdebug && storage_class & STCparameter)
            {
                t = type_alloc(TYnptr);         // should be TYref, but problems in back end
                t->Tnext = type->toCtype();
                t->Tnext->Tcount++;
            }
            else
                t = type_fake(TYnptr);
        }
        else if (storage_class & STClazy)
            t = type_fake(TYdelegate);          // Tdelegate as C type
        else if (isParameter())
            t = type->toCParamtype();
        else
            t = type->toCtype();
        t->Tcount++;

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
                    fprintf(stdmsg, "%s: %s is thread local\n", p ? p : "", toChars());
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
                m = mTYman_c;
                break;

            case LINKd:
                m = mTYman_d;
                break;

            case LINKcpp:
                m = mTYman_cpp;
                break;

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

Symbol *ModuleInfoDeclaration::toSymbol()
{
    return mod->toSymbol();
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

#if 0
        id = ident->toChars();
#else
        id = mangle();
#endif
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
            if (isVirtual())
                f->Fflags |= Fvirtual;
            else if (isMember2())
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

                case LINKcpp:
                {   t->Tmangle = mTYman_cpp;
#if TARGET_WINDOS
                    if (isThis())
                        t->Tty = TYmfunc;
#endif
                    s->Sflags |= SFLpublic;
                    Dsymbol *parent = toParent();
                    ClassDeclaration *cd = parent->isClassDeclaration();
                    if (cd)
                    {
                        ::type *tc = cd->type->toCtype();
                        s->Sscope = tc->Tnext->Ttag;
                    }
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
    Symbol *sthunk;

    toSymbol();

#if 0
    char *id;
    char *n;
    type *t;

    n = sym->Sident;
    id = (char *) alloca(8 + 5 + strlen(n) + 1);
    sprintf(id,"_thunk%d__%s", offset, n);
    s = symbol_calloc(id);
    slist_add(s);
    s->Stype = csym->Stype;
    s->Stype->Tcount++;
#endif
    sthunk = symbol_generate(SCstatic, csym->Stype);
    sthunk->Sflags |= SFLimplem;
    cod3_thunk(sthunk, csym, 0, TYnptr, -offset, -1, 0);
    return sthunk;
}


/****************************************
 * Create a static symbol we can hang DT initializers onto.
 */

Symbol *static_sym()
{
    Symbol *s;
    type *t;

    t = type_alloc(TYint);
    t->Tcount++;
    s = symbol_calloc("internal");
    s->Sclass = SCstatic;
    s->Sfl = FLextern;
    s->Sflags |= SFLnodebug;
    s->Stype = t;
#if ELFOBJ || MACHOBJ
    s->Sseg = DATA;
#endif
    slist_add(s);
    return s;
}

/**************************************
 * Fake a struct symbol.
 */

Classsym *fake_classsym(Identifier *id)
{   TYPE *t;
    Classsym *scc;

    scc = (Classsym *)symbol_calloc(id->toChars());
    scc->Sclass = SCstruct;
    scc->Sstruct = struct_calloc();
    scc->Sstruct->Sstructalign = 8;
    //scc->Sstruct->ptrtype = TYnptr;
    scc->Sstruct->Sflags = STRglobal;

    t = type_alloc(TYstruct);
    t->Tflags |= TFsizeunknown | TFforward;
    t->Ttag = scc;              // structure tag name
    assert(t->Tmangle == 0);
    t->Tmangle = mTYman_d;
    t->Tcount++;
    scc->Stype = t;
    slist_add(scc);
    return scc;
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

        t = type_alloc(TYnptr | mTYconst);
        t->Tnext = tsvoid;
        t->Tnext->Tcount++;
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
    Symbol *s;
    Classsym *stag;

    if (!sinit)
    {
        stag = fake_classsym(Id::ClassInfo);
        s = toSymbolX("__init", SCextern, stag->Stype, "Z");
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        slist_add(s);
        sinit = s;
    }
    return sinit;
}

Symbol *TypedefDeclaration::toInitializer()
{
    Symbol *s;
    Classsym *stag;

    if (!sinit)
    {
        stag = fake_classsym(Id::ClassInfo);
        s = toSymbolX("__init", SCextern, stag->Stype, "Z");
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        slist_add(s);
        sinit = s;
    }
    return sinit;
}

Symbol *EnumDeclaration::toInitializer()
{
    Symbol *s;
    Classsym *stag;

    if (!sinit)
    {
        stag = fake_classsym(Id::ClassInfo);
        Identifier *ident_save = ident;
        if (!ident)
            ident = Lexer::uniqueId("__enum");
        s = toSymbolX("__init", SCextern, stag->Stype, "Z");
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
        type *t;

        t = type_alloc(TYjfunc);
        t->Tflags |= TFprototype | TFfixed;
        t->Tmangle = mTYman_d;
        t->Tnext = tsvoid;
        tsvoid->Tcount++;

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
        type *t;

        t = type_alloc(TYjfunc);
        t->Tflags |= TFprototype | TFfixed;
        t->Tmangle = mTYman_d;
        t->Tnext = tsvoid;
        tsvoid->Tcount++;

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
        type *t;

        t = type_alloc(TYjfunc);
        t->Tflags |= TFprototype | TFfixed;
        t->Tmangle = mTYman_d;
        t->Tnext = tsvoid;
        tsvoid->Tcount++;

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
#if __DMC__
    __in
    {
        assert(func);
        assert((flags & ~1) == 0);
    }
    __out (result)
    {
        assert(result);
    }
    __body
#endif
    {
        // Dumb linear symbol table - should use associative array!
        static Symbols *sarray = NULL;

        //printf("aaGetSymbol(func = '%s', flags = %d, key = %p)\n", func, flags, key);
#if 0
        OutBuffer buf;
        key->toKeyBuffer(&buf);

        sz = next->size();              // it's just data, so we only care about the size
        sz = (sz + 3) & ~3;             // reduce proliferation of library routines
        char *id = (char *)alloca(3 + strlen(func) + buf.offset + sizeof(sz) * 3 + 1);
        buf.writeByte(0);
        if (flags & 1)
            sprintf(id, "_aa%s%s%d", func, buf.data, sz);
        else
            sprintf(id, "_aa%s%s", func, buf.data);
#else
        char *id = (char *)alloca(3 + strlen(func) + 1);
        sprintf(id, "_aa%s", func);
#endif
        if (!sarray)
            sarray = new Symbols();

        // See if symbol is already in sarray
        for (size_t i = 0; i < sarray->dim; i++)
        {   Symbol *s = (*sarray)[i];
            if (strcmp(id, s->Sident) == 0)
                return s;                       // use existing Symbol
        }

        // Create new Symbol

        Symbol *s = symbol_calloc(id);
        slist_add(s);
        s->Sclass = SCextern;
        s->Ssymnum = -1;
        symbol_func(s);

        type *t = type_alloc(TYnfunc);
        t->Tflags = TFprototype | TFfixed;
        t->Tmangle = mTYman_c;
        t->Tparamtypes = NULL;
        t->Tnext = next->toCtype();
        t->Tnext->Tcount++;
        t->Tcount++;
        s->Stype = t;

        sarray->push(s);                        // remember it
        return s;
    }

