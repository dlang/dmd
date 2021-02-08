
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/tocsym.c
 */

#include <stdio.h>
#include <stddef.h>
#include <time.h>
#include <assert.h>

#if __sun
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
#include "dsymbol.h"
#include "id.h"
#include "ctfe.h"
#include "root/rmem.h"
#include "target.h"
#include "mangle.h"

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

typedef Array<struct Symbol *> Symbols;

Classsym *fake_classsym(Identifier *id);
type *Type_toCtype(Type *t);
void ClassReferenceExp_toInstanceDt(ClassReferenceExp *ce, DtBuilder& dtb);
void Expression_toDt(Expression *e, DtBuilder& dtb);
void cpp_type_info_ptr_toDt(ClassDeclaration *cd, DtBuilder& dtb);
Symbol *toInitializer(AggregateDeclaration *ad);

/*************************************
 * Helper
 */

Symbol *toSymbolX(Dsymbol *ds, const char *prefix, int sclass, type *t, const char *suffix)
{
    //printf("Dsymbol::toSymbolX('%s')\n", prefix);

    OutBuffer buf;
    mangleToBuffer(ds, &buf);
    const char *n = buf.peekChars();
    assert(n);
    size_t nlen = strlen(n);

    size_t prefixlen = strlen(prefix);

    size_t idlen = 2 + nlen + sizeof(size_t) * 3 + prefixlen + strlen(suffix) + 1;

    char idbuf[20];
    char *id = idbuf;
    if (idlen > sizeof(idbuf))
    {
        id = (char *)malloc(idlen);
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

static Classsym *scc;

/*************************************
 */

Symbol *toSymbol(Dsymbol *s)
{
    class ToSymbol : public Visitor
    {
    public:
        Symbol *result;

        ToSymbol()
        {
            result = NULL;
        }

        void visit(Dsymbol *s)
        {
            printf("Dsymbol::toSymbol() '%s', kind = '%s'\n", s->toChars(), s->kind());
            assert(0);          // BUG: implement
        }

        void visit(SymbolDeclaration *sd)
        {
            result = toInitializer(sd->dsym);
        }

        void visit(VarDeclaration *vd)
        {
            //printf("VarDeclaration::toSymbol(%s)\n", vd->toChars());
            assert(!vd->needThis());

            Symbol *s;
            if (vd->isDataseg())
            {
                OutBuffer buf;
                mangleToBuffer(vd, &buf);
                const char *id = buf.peekChars();
                s = symbol_calloc(id);
            }
            else
            {
                const char *id = vd->ident->toChars();
                s = symbol_calloc(id);
            }
            s->Salignment = vd->alignment;
            if (vd->storage_class & STCtemp)
                s->Sflags |= SFLartifical;

            TYPE *t;
            if (vd->storage_class & (STCout | STCref))
            {
                t = type_allocn(TYnref, Type_toCtype(vd->type));
                t->Tcount++;
            }
            else if (vd->storage_class & STClazy)
            {
                if (config.exe == EX_WIN64 && vd->isParameter())
                    t = type_fake(TYnptr);
                else
                    t = type_fake(TYdelegate);          // Tdelegate as C type
                t->Tcount++;
            }
            else if (vd->isParameter())
            {
                if (config.exe == EX_WIN64 && vd->type->size(Loc()) > REGSIZE)
                {
                    t = type_allocn(TYnref, Type_toCtype(vd->type));
                    t->Tcount++;
                }
                else
                {
                    t = Type_toCtype(vd->type);
                    t->Tcount++;
                }
            }
            else
            {
                t = Type_toCtype(vd->type);
                t->Tcount++;
            }

            if (vd->isDataseg())
            {
                if (vd->isThreadlocal() && !(vd->storage_class & STCtemp))
                {
                    /* Thread local storage
                     */
                    TYPE *ts = t;
                    ts->Tcount++;   // make sure a different t is allocated
                    type_setty(&t, t->Tty | mTYthread);
                    ts->Tcount--;

                    if (config.objfmt == OBJ_MACH && I64)
                        s->Salignment = 2;

                    if (global.params.vtls)
                    {
                        const char *p = vd->loc.toChars();
                        fprintf(global.stdmsg, "%s: %s is thread local\n", p ? p : "", vd->toChars());
                        if (p)
                            mem.xfree((void*)p);
                    }
                }
                s->Sclass = SCextern;
                s->Sfl = FLextern;
                /* if it's global or static, then it needs to have a qualified but unmangled name.
                 * This gives some explanation of the separation in treating name mangling.
                 * It applies to PDB format, but should apply to CV as PDB derives from CV.
                 *    http://msdn.microsoft.com/en-us/library/ff553493(VS.85).aspx
                 */
                s->prettyIdent = vd->toPrettyChars(true);
            }
            else
            {
                s->Sclass = SCauto;
                s->Sfl = FLauto;

                if (vd->nestedrefs.length)
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

            if (vd->storage_class & STCvolatile)
            {
                type_setcv(&t, t->Tty | mTYvolatile);
            }

            mangle_t m = 0;
            switch (vd->linkage)
            {
                case LINKwindows:
                    m = global.params.is64bit ? mTYman_c : mTYman_std;
                    break;

                case LINKobjc:
                case LINKc:
                    m = mTYman_c;
                    break;

                case LINKd:
                    m = mTYman_d;
                    break;
                case LINKcpp:
                    s->Sflags |= SFLpublic;
                    m = mTYman_cpp;
                    break;
                default:
                    printf("linkage = %d, vd = %s %s @ [%s]\n",
                        vd->linkage, vd->kind(), vd->toChars(), vd->loc.toChars());
                    assert(0);
            }

            type_setmangle(&t, m);
            s->Stype = t;

            result = s;
        }

        void visit(TypeInfoDeclaration *tid)
        {
            //printf("TypeInfoDeclaration::toSymbol(%s), linkage = %d\n", tid->toChars(), tid->linkage);
            assert(tid->tinfo->ty != Terror);
            visit((VarDeclaration *)tid);
        }

        void visit(TypeInfoClassDeclaration *ticd)
        {
            //printf("TypeInfoClassDeclaration::toSymbol(%s), linkage = %d\n", ticd->toChars(), ticd->linkage);
            assert(ticd->tinfo->ty == Tclass);
            TypeClass *tc = (TypeClass *)ticd->tinfo;
            tc->sym->accept(this);
        }

        void visit(FuncAliasDeclaration *fad)
        {
            fad->funcalias->accept(this);
        }

        void visit(FuncDeclaration *fd)
        {
            const char *id = mangleExact(fd);

            //printf("FuncDeclaration::toSymbol(%s %s)\n", fd->kind(), fd->toChars());
            //printf("\tid = '%s'\n", id);
            //printf("\ttype = %s\n", fd->type->toChars());
            Symbol *s = symbol_calloc(id);

            s->prettyIdent = fd->toPrettyChars(true);
            s->Sclass = SCglobal;
            symbol_func(s);
            func_t *f = s->Sfunc;
            if (fd->isVirtual() && fd->vtblIndex != -1)
                f->Fflags |= Fvirtual;
            else if (fd->isMember2() && fd->isStatic())
                f->Fflags |= Fstatic;
            f->Fstartline.Slinnum = fd->loc.linnum;
            f->Fstartline.Scharnum = fd->loc.charnum;
            f->Fstartline.Sfilename = (char *)fd->loc.filename;
            if (fd->endloc.linnum)
            {
                f->Fendline.Slinnum = fd->endloc.linnum;
                f->Fendline.Scharnum = fd->endloc.charnum;
                f->Fendline.Sfilename = (char *)fd->endloc.filename;
            }
            else
            {
                f->Fendline.Slinnum = fd->loc.linnum;
                f->Fendline.Scharnum = fd->loc.charnum;
                f->Fendline.Sfilename = (char *)fd->loc.filename;
            }
            TYPE *t = Type_toCtype(fd->type);

            mangle_t msave = t->Tmangle;
            if (fd->isMain())
            {
                t->Tty = TYnfunc;
                t->Tmangle = mTYman_c;
            }
            else
            {
                switch (fd->linkage)
                {
                    case LINKwindows:
                        t->Tmangle = global.params.is64bit ? mTYman_c : mTYman_std;
                        break;

                    case LINKc:
                    case LINKobjc:
                        t->Tmangle = mTYman_c;
                        break;

                    case LINKd:
                        t->Tmangle = mTYman_d;
                        break;
                    case LINKcpp:
                        s->Sflags |= SFLpublic;
                        if (fd->isThis() && !global.params.is64bit && global.params.isWindows)
                        {
                            if (((TypeFunction *)fd->type)->parameterList.varargs == VARARGvariadic)
                            {
                                t->Tty = TYnfunc;
                            }
                            else
                            {
                                t->Tty = TYmfunc;
                            }
                        }
                        t->Tmangle = mTYman_cpp;
                        break;
                    default:
                        printf("linkage = %d\n", fd->linkage);
                        assert(0);
                }
            }

            if (msave)
                assert(msave == t->Tmangle);
            //printf("Tty = %x, mangle = x%x\n", t->Tty, t->Tmangle);
            t->Tcount++;
            s->Stype = t;
            //s->Sfielddef = this;

            result = s;
        }

        /*************************************
         * Create the "ClassInfo" symbol
         */

        void visit(ClassDeclaration *cd)
        {
            if (!scc)
                scc = fake_classsym(Id::ClassInfo);

            Symbol *s = toSymbolX(cd, "__Class", SCextern, scc->Stype, "Z");
            s->Sfl = FLextern;
            s->Sflags |= SFLnodebug;
            result = s;
        }

        /*************************************
         * Create the "InterfaceInfo" symbol
         */

        void visit(InterfaceDeclaration *id)
        {
            if (!scc)
                scc = fake_classsym(Id::ClassInfo);

            Symbol *s = toSymbolX(id, "__Interface", SCextern, scc->Stype, "Z");
            s->Sfl = FLextern;
            s->Sflags |= SFLnodebug;
            result = s;
        }

        /*************************************
         * Create the "ModuleInfo" symbol
         */

        void visit(Module *m)
        {
            if (!scc)
                scc = fake_classsym(Id::ClassInfo);

            Symbol *s = toSymbolX(m, "__ModuleInfo", SCextern, scc->Stype, "Z");
            s->Sfl = FLextern;
            s->Sflags |= SFLnodebug;
            result = s;
        }
    };

    if (s->csym)
        return s->csym;

    ToSymbol v;
    s->accept(&v);
    s->csym = v.result;
    return v.result;
}

/*************************************
 */

static Symbol *toImport(Symbol *sym)
{
    //printf("Dsymbol::toImport('%s')\n", sym->Sident);
    char *n = sym->Sident;
    char *id = (char *) alloca(6 + strlen(n) + 1 + sizeof(type_paramsize(sym->Stype))*3 + 1);
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
        sprintf(id,(config.exe == EX_WIN64) ? "__imp_%s" : "_imp__%s",n);
    }
    type *t = type_alloc(TYnptr | mTYconst);
    t->Tnext = sym->Stype;
    t->Tnext->Tcount++;
    t->Tmangle = mTYman_c;
    t->Tcount++;
    Symbol *s = symbol_calloc(id);
    s->Stype = t;
    s->Sclass = SCextern;
    s->Sfl = FLextern;
    return s;
}

/*********************************
 * Generate import symbol from symbol.
 */

Symbol *toImport(Dsymbol *ds)
{
    if (!ds->isym)
    {
        if (!ds->csym)
            ds->csym = toSymbol(ds);
        ds->isym = toImport(ds->csym);
    }
    return ds->isym;
}

/*************************************
 * Thunks adjust the incoming 'this' pointer by 'offset'.
 */

Symbol *toThunkSymbol(FuncDeclaration *fd, int offset)
{
    Symbol *s = toSymbol(fd);
    if (!offset)
        return s;

    Symbol *sthunk = symbol_generate(SCstatic, fd->csym->Stype);
    sthunk->Sflags |= SFLimplem;
    cod3_thunk(sthunk, fd->csym, 0, TYnptr, -offset, -1, 0);
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
 * This is accessible via the ClassData, but since it is frequently
 * needed directly (like for rtti comparisons), make it directly accessible.
 */

Symbol *toVtblSymbol(ClassDeclaration *cd)
{
    if (!cd->vtblsym)
    {
        if (!cd->csym)
            toSymbol(cd);

        TYPE *t = type_allocn(TYnptr | mTYconst, tsvoid);
        t->Tmangle = mTYman_d;
        Symbol *s = toSymbolX(cd, "__vtbl", SCextern, t, "Z");
        s->Sflags |= SFLnodebug;
        s->Sfl = FLextern;
        cd->vtblsym = s;
    }
    return cd->vtblsym;
}

/**********************************
 * Create the static initializer for the struct/class.
 */

Symbol *toInitializer(AggregateDeclaration *ad)
{
    if (!ad->sinit)
    {
        Classsym *stag = fake_classsym(Id::ClassInfo);
        Symbol *s = toSymbolX(ad, "__init", SCextern, stag->Stype, "Z");
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        StructDeclaration *sd = ad->isStructDeclaration();
        if (sd)
            s->Salignment = sd->alignment;
        ad->sinit = s;
    }
    return ad->sinit;
}

Symbol *toInitializer(EnumDeclaration *ed)
{
    if (!ed->sinit)
    {
        Classsym *stag = fake_classsym(Id::ClassInfo);
        Identifier *ident_save = ed->ident;
        if (!ed->ident)
            ed->ident = Identifier::generateId("__enum");
        Symbol *s = toSymbolX(ed, "__init", SCextern, stag->Stype, "Z");
        ed->ident = ident_save;
        s->Sfl = FLextern;
        s->Sflags |= SFLnodebug;
        ed->sinit = s;
    }
    return ed->sinit;
}


/********************************************
 * Determine the right symbol to look up
 * an associative array element.
 * Input:
 *      flags   0       don't add value signature
 *              1       add value signature
 */

Symbol *aaGetSymbol(TypeAArray *taa, const char *func, int flags)
{
#ifdef DEBUG
        assert((flags & ~1) == 0);
#endif

        // Dumb linear symbol table - should use associative array!
        static Symbols sarray;

        //printf("aaGetSymbol(func = '%s', flags = %d, key = %p)\n", func, flags, key);
        char *id = (char *)alloca(3 + strlen(func) + 1);
        sprintf(id, "_aa%s", func);

        // See if symbol is already in sarray
        for (size_t i = 0; i < sarray.length; i++)
        {
            Symbol *s = sarray[i];
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
        s->Sclass = SCextern;
        s->Ssymnum = -1;
        symbol_func(s);

        type *t = type_function(TYnfunc, NULL, 0, false, Type_toCtype(taa->next));
        t->Tmangle = mTYman_c;
        s->Stype = t;

        sarray.push(s);                         // remember it
        return s;
}

/*****************************************************/
/*                   CTFE stuff                      */
/*****************************************************/

Symbol* toSymbol(StructLiteralExp *sle)
{
    if (sle->sym) return sle->sym;
    TYPE *t = type_alloc(TYint);
    t->Tcount++;
    Symbol *s = symbol_calloc("internal");
    s->Sclass = SCstatic;
    s->Sfl = FLextern;
    s->Sflags |= SFLnodebug;
    s->Stype = t;
    sle->sym = s;
    DtBuilder dtb;
    Expression_toDt(sle, dtb);
    s->Sdt = dtb.finish();
    outdata(s);
    return sle->sym;
}

Symbol* toSymbol(ClassReferenceExp *cre)
{
    if (cre->value->sym) return cre->value->sym;
    TYPE *t = type_alloc(TYint);
    t->Tcount++;
    Symbol *s = symbol_calloc("internal");
    s->Sclass = SCstatic;
    s->Sfl = FLextern;
    s->Sflags |= SFLnodebug;
    s->Stype = t;
    cre->value->sym = s;
    DtBuilder dtb;
    ClassReferenceExp_toInstanceDt(cre, dtb);
    s->Sdt = dtb.finish();
    outdata(s);
    return cre->value->sym;
}

/**************************************
 * For C++ class cd, generate an instance of __cpp_type_info_ptr
 * and populate it with a pointer to the C++ type info.
 * Params:
 *      cd = C++ class
 * Returns:
 *      symbol of instance of __cpp_type_info_ptr
 */
Symbol* toSymbolCpp(ClassDeclaration *cd)
{
    assert(cd->isCPPclass());

    /* For the symbol std::exception, the type info is _ZTISt9exception
     */
    if (!cd->cpp_type_info_ptr_sym)
    {
        static Symbol *scpp;
        if (!scpp)
            scpp = fake_classsym(Id::cpp_type_info_ptr);
        Symbol *s = toSymbolX(cd, "_cpp_type_info_ptr", SCcomdat, scpp->Stype, "");
        s->Sfl = FLdata;
        s->Sflags |= SFLnodebug;
        DtBuilder dtb;
        cpp_type_info_ptr_toDt(cd, dtb);
        s->Sdt = dtb.finish();
        outdata(s);
        cd->cpp_type_info_ptr_sym = s;
    }
    return cd->cpp_type_info_ptr_sym;
}

/**********************************
 * Generate Symbol of C++ type info for C++ class cd.
 * Params:
 *      cd = C++ class
 * Returns:
 *      Symbol of cd's rtti type info
 */
Symbol *toSymbolCppTypeInfo(ClassDeclaration *cd)
{
    const char *id = target.cpp.typeInfoMangle(cd);
    Symbol* s = symbol_calloc(id);
    s->Sclass = SCextern;
    s->Sfl = FLextern;          // C++ code will provide the definition
    s->Sflags |= SFLnodebug;
    TYPE *t = type_fake(TYnptr);
    t->Tcount++;
    s->Stype = t;
    return s;
}
