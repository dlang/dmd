
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/mangle.c
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>

#include "root.h"

#include "init.h"
#include "declaration.h"
#include "aggregate.h"
#include "mtype.h"
#include "attrib.h"
#include "template.h"
#include "id.h"
#include "module.h"
#include "enum.h"

char *toCppMangle(Dsymbol *s);
void mangleToBuffer(Type *t, OutBuffer *buf);

static unsigned char mangleChar[TMAX];

void initTypeMangle()
{
    mangleChar[Tarray] = 'A';
    mangleChar[Tsarray] = 'G';
    mangleChar[Taarray] = 'H';
    mangleChar[Tpointer] = 'P';
    mangleChar[Treference] = 'R';
    mangleChar[Tfunction] = 'F';
    mangleChar[Tident] = 'I';
    mangleChar[Tclass] = 'C';
    mangleChar[Tstruct] = 'S';
    mangleChar[Tenum] = 'E';
    mangleChar[Ttypedef] = 'T';
    mangleChar[Tdelegate] = 'D';

    mangleChar[Tnone] = 'n';
    mangleChar[Tvoid] = 'v';
    mangleChar[Tint8] = 'g';
    mangleChar[Tuns8] = 'h';
    mangleChar[Tint16] = 's';
    mangleChar[Tuns16] = 't';
    mangleChar[Tint32] = 'i';
    mangleChar[Tuns32] = 'k';
    mangleChar[Tint64] = 'l';
    mangleChar[Tuns64] = 'm';
    mangleChar[Tfloat32] = 'f';
    mangleChar[Tfloat64] = 'd';
    mangleChar[Tfloat80] = 'e';

    mangleChar[Timaginary32] = 'o';
    mangleChar[Timaginary64] = 'p';
    mangleChar[Timaginary80] = 'j';
    mangleChar[Tcomplex32] = 'q';
    mangleChar[Tcomplex64] = 'r';
    mangleChar[Tcomplex80] = 'c';

    mangleChar[Tbool] = 'b';
    mangleChar[Tchar] = 'a';
    mangleChar[Twchar] = 'u';
    mangleChar[Tdchar] = 'w';

    // '@' shouldn't appear anywhere in the deco'd names
    mangleChar[Tinstance] = '@';
    mangleChar[Terror] = '@';
    mangleChar[Ttypeof] = '@';
    mangleChar[Ttuple] = 'B';
    mangleChar[Tslice] = '@';
    mangleChar[Treturn] = '@';
    mangleChar[Tvector] = '@';
    mangleChar[Tint128] = '@';
    mangleChar[Tuns128] = '@';

    mangleChar[Tnull] = 'n';    // same as TypeNone

    for (size_t i = 0; i < TMAX; i++)
    {
        if (!mangleChar[i])
            fprintf(stderr, "ty = %llu\n", (ulonglong)i);
        assert(mangleChar[i]);
    }
}

/*********************************
 * Mangling for mod.
 */
void MODtoDecoBuffer(OutBuffer *buf, MOD mod)
{
    switch (mod)
    {
        case 0:
            break;
        case MODconst:
            buf->writeByte('x');
            break;
        case MODimmutable:
            buf->writeByte('y');
            break;
        case MODshared:
            buf->writeByte('O');
            break;
        case MODshared | MODconst:
            buf->writestring("Ox");
            break;
        case MODwild:
            buf->writestring("Ng");
            break;
        case MODwildconst:
            buf->writestring("Ngx");
            break;
        case MODshared | MODwild:
            buf->writestring("ONg");
            break;
        case MODshared | MODwildconst:
            buf->writestring("ONgx");
            break;
        default:
            assert(0);
    }
}

class Mangler : public Visitor
{
public:
    OutBuffer *buf;

    Mangler(OutBuffer *buf)
    {
        this->buf = buf;
    }


    ////////////////////////////////////////////////////////////////////////////

    /**************************************************
     * Type mangling
     */

    void visitWithMask(Type *t, unsigned char modMask)
    {
        if (modMask != t->mod)
        {
            MODtoDecoBuffer(buf, t->mod);
        }
        t->accept(this);
    }

    void visit(Type *t)
    {
        buf->writeByte(mangleChar[t->ty]);
    }

    void visit(TypeNext *t)
    {
        visit((Type *)t);
        visitWithMask(t->next, t->mod);
    }

    void visit(TypeVector *t)
    {
        buf->writestring("Nh");
        visitWithMask(t->basetype, t->mod);
    }

    void visit(TypeSArray *t)
    {
        visit((Type *)t);
        if (t->dim)
            buf->printf("%llu", t->dim->toInteger());
        if (t->next)
            visitWithMask(t->next, t->mod);
    }

    void visit(TypeDArray *t)
    {
        visit((Type *)t);
        if (t->next)
            visitWithMask(t->next, t->mod);
    }

    void visit(TypeAArray *t)
    {
        visit((Type *)t);
        visitWithMask(t->index, 0);
        visitWithMask(t->next, t->mod);
    }

    void visit(TypeFunction *t)
    {
        //printf("TypeFunction::toDecoBuffer() t = %p %s\n", t, t->toChars());
        //static int nest; if (++nest == 50) *(char*)0=0;

        mangleFuncType(t, t, t->mod, t->next);
    }

    void mangleFuncType(TypeFunction *t, TypeFunction *ta, unsigned char modMask, Type *tret)
    {
        if (t->inuse)
        {
            t->inuse = 2;       // flag error to caller
            return;
        }
        t->inuse++;

        if (modMask != t->mod)
            MODtoDecoBuffer(buf, t->mod);

        unsigned char mc;
        switch (t->linkage)
        {
            case LINKd:             mc = 'F';       break;
            case LINKc:             mc = 'U';       break;
            case LINKwindows:       mc = 'W';       break;
            case LINKpascal:        mc = 'V';       break;
            case LINKcpp:           mc = 'R';       break;
            default:
                assert(0);
        }
        buf->writeByte(mc);

        if (ta->purity || ta->isnothrow || ta->isnogc || ta->isproperty || ta->isref || ta->trust)
        {
            if (ta->purity)
                buf->writestring("Na");
            if (ta->isnothrow)
                buf->writestring("Nb");
            if (ta->isref)
                buf->writestring("Nc");
            if (ta->isproperty)
                buf->writestring("Nd");
            if (ta->isnogc)
                buf->writestring("Ni");
            switch (ta->trust)
            {
                case TRUSTtrusted:
                    buf->writestring("Ne");
                    break;
                case TRUSTsafe:
                    buf->writestring("Nf");
                    break;
                default:
                    break;
            }
        }

        // Write argument types
        argsToDecoBuffer(t->parameters);
        //if (buf->data[buf->offset - 1] == '@') halt();
        buf->writeByte('Z' - t->varargs);   // mark end of arg list
        if (tret != NULL)
            visitWithMask(tret, 0);

        t->inuse--;
    }

    void visit(TypeIdentifier *t)
    {
        visit((Type *)t);
        const char *name = t->ident->toChars();
        size_t len = strlen(name);
        buf->printf("%u%s", (unsigned)len, name);
    }

    void visit(TypeEnum *t)
    {
        visit((Type *)t);
        t->sym->accept(this);
    }

    void visit(TypeTypedef *t)
    {
        visit((Type *)t);
        t->sym->accept(this);
    }

    void visit(TypeStruct *t)
    {
        //printf("TypeStruct::toDecoBuffer('%s') = '%s'\n", t->toChars(), name);
        visit((Type *)t);
        t->sym->accept(this);
    }

    void visit(TypeClass *t)
    {
        //printf("TypeClass::toDecoBuffer('%s' mod=%x) = '%s'\n", t->toChars(), mod, name);
        visit((Type *)t);
        t->sym->accept(this);
    }

    void visit(TypeTuple *t)
    {
        //printf("TypeTuple::toDecoBuffer() t = %p, %s\n", t, t->toChars());
        visit((Type *)t);

        OutBuffer buf2;
        buf2.reserve(32);
        Mangler v(&buf2);
        v.argsToDecoBuffer(t->arguments);
        int len = (int)buf2.offset;
        buf->printf("%d%.*s", len, len, buf2.extractData());
    }

    void visit(TypeNull *t)
    {
        visit((Type *)t);
    }

    ////////////////////////////////////////////////////////////////////////////

    void mangleDecl(Declaration *sthis)
    {
        mangleParent(sthis);

        assert(sthis->ident);
        const char *id = sthis->ident->toChars();
        toBuffer(id, sthis);

        if (FuncDeclaration *fd = sthis->isFuncDeclaration())
        {
            mangleFunc(fd, false);
        }
        else if (sthis->type->deco)
        {
            buf->writestring(sthis->type->deco);
        }
        else
            assert(0);
    }

    void mangleParent(Dsymbol *s)
    {
        Dsymbol *p;
        if (TemplateInstance *ti = s->isTemplateInstance())
            p = ti->isTemplateMixin() ? ti->parent : ti->tempdecl->parent;
        else
            p = s->parent;

        if (p)
        {
            mangleParent(p);

            if (p->getIdent())
            {
                const char *id = p->ident->toChars();
                toBuffer(id, s);

                if (FuncDeclaration *f = p->isFuncDeclaration())
                    mangleFunc(f, true);
            }
            else
                buf->writeByte('0');
        }
    }

    void mangleFunc(FuncDeclaration *fd, bool inParent)
    {
        //printf("deco = '%s'\n", fd->type->deco ? fd->type->deco : "null");
        //printf("fd->type = %s\n", fd->type->toChars());
        if (fd->needThis() || fd->isNested())
            buf->writeByte(Type::needThisPrefix());
        if (inParent)
        {
            TypeFunction *tf = (TypeFunction *)fd->type;
            TypeFunction *tfo = (TypeFunction *)fd->originalType;
            mangleFuncType(tf, tfo, 0, NULL);
        }
        else if (fd->type->deco)
        {
            buf->writestring(fd->type->deco);
        }
        else
        {
            printf("[%s] %s %s\n", fd->loc.toChars(), fd->toChars(), fd->type->toChars());
            assert(0);  // don't mangle function until semantic3 done.
        }
    }

    /************************************************************
     * Write length prefixed string to buf.
     */
    void toBuffer(const char *id, Dsymbol *s)
    {
        size_t len = strlen(id);
        if (len >= 8 * 1024 * 1024)         // 8 megs ought be enough for anyone
            s->error("excessive length %llu for symbol, possible recursive expansion?", len);
        else
        {
            buf->printf("%llu", (ulonglong)len);
            buf->write(id, len);
        }
    }

    void visit(Declaration *d)
    {
        //printf("Declaration::mangle(this = %p, '%s', parent = '%s', linkage = %d)\n",
        //        d, d->toChars(), d->parent ? d->parent->toChars() : "null", d->linkage);
        if (!d->parent || d->parent->isModule() || d->linkage == LINKcpp) // if at global scope
        {
            switch (d->linkage)
            {
                case LINKd:
                    break;

                case LINKc:
                case LINKwindows:
                case LINKpascal:
                    buf->writestring(d->ident->toChars());
                    return;

                case LINKcpp:
                    buf->writestring(toCppMangle(d));
                    return;

                case LINKdefault:
                    d->error("forward declaration");
                    buf->writestring(d->ident->toChars());
                    return;

                default:
                    fprintf(stderr, "'%s', linkage = %d\n", d->toChars(), d->linkage);
                    assert(0);
                    return;
            }
        }

        buf->writestring("_D");
        mangleDecl(d);

    #ifdef DEBUG
        assert(buf->data);
        size_t len = buf->offset;
        assert(len > 0);
        for (size_t i = 0; i < len; i++)
        {
            assert(buf->data[i] == '_' ||
                   buf->data[i] == '@' ||
                   buf->data[i] == '?' ||
                   buf->data[i] == '$' ||
                   isalnum(buf->data[i]) || buf->data[i] & 0x80);
        }
    #endif
    }

    /******************************************************************************
     * Normally FuncDeclaration and FuncAliasDeclaration have overloads.
     * If and only if there is no overloads, mangle() could return
     * exact mangled name.
     *
     *      module test;
     *      void foo(long) {}           // _D4test3fooFlZv
     *      void foo(string) {}         // _D4test3fooFAyaZv
     *
     *      // from FuncDeclaration::mangle().
     *      pragma(msg, foo.mangleof);  // prints unexact mangled name "4test3foo"
     *                                  // by calling Dsymbol::mangle()
     *
     *      // from FuncAliasDeclaration::mangle()
     *      pragma(msg, __traits(getOverloads, test, "foo")[0].mangleof);  // "_D4test3fooFlZv"
     *      pragma(msg, __traits(getOverloads, test, "foo")[1].mangleof);  // "_D4test3fooFAyaZv"
     *
     * If a function has no overloads, .mangleof property still returns exact mangled name.
     *
     *      void bar() {}
     *      pragma(msg, bar.mangleof);  // still prints "_D4test3barFZv"
     *                                  // by calling FuncDeclaration::mangleExact().
     */
    void visit(FuncDeclaration *fd)
    {
        if (fd->isUnique())
            mangleExact(fd);
        else
            visit((Dsymbol *)fd);
    }

    // ditto
    void visit(FuncAliasDeclaration *fd)
    {
        FuncDeclaration *f = fd->toAliasFunc();
        FuncAliasDeclaration *fa = f->isFuncAliasDeclaration();
        if (!fd->hasOverloads && !fa)
        {
            mangleExact(f);
            return;
        }
        if (fa)
        {
            fa->accept(this);
            return;
        }
        visit((Dsymbol *)fd);
    }

    void visit(OverDeclaration *od)
    {
        if (od->overnext)
        {
            visit((Dsymbol *)od);
            return;
        }

        if (FuncDeclaration *fd = od->aliassym->isFuncDeclaration())
        {
            if (!od->hasOverloads || fd->isUnique())
            {
                mangleExact(fd);
                return;
            }
        }
        if (TemplateDeclaration *td = od->aliassym->isTemplateDeclaration())
        {
            if (!od->hasOverloads || td->overnext == NULL)
            {
                td->accept(this);
                return;
            }
        }
        visit((Dsymbol *)od);
    }

    void mangleExact(FuncDeclaration *fd)
    {
        assert(!fd->isFuncAliasDeclaration());

        if (fd->mangleOverride)
        {
            buf->writestring(fd->mangleOverride);
            return;
        }

        if (fd->isMain())
        {
            buf->writestring("_Dmain");
            return;
        }

        if (fd->isWinMain() || fd->isDllMain() || fd->ident == Id::tls_get_addr)
        {
            buf->writestring(fd->ident->toChars());
            return;
        }

        visit((Declaration *)fd);
    }

    void visit(VarDeclaration *vd)
    {
        if (vd->mangleOverride)
        {
            buf->writestring(vd->mangleOverride);
            return;
        }

        visit((Declaration *)vd);
    }

    void visit(TypedefDeclaration *td)
    {
        //printf("TypedefDeclaration::mangle() '%s'\n", toChars());
        visit((Dsymbol *)td);
    }

    void visit(AggregateDeclaration *ad)
    {
        ClassDeclaration *cd = ad->isClassDeclaration();
        Dsymbol *parentsave = ad->parent;
        if (cd)
        {
            /* These are reserved to the compiler, so keep simple
             * names for them.
             */
            if (cd->ident == Id::Exception && cd->parent->ident == Id::object ||
                cd->ident == Id::TypeInfo ||
                cd->ident == Id::TypeInfo_Struct ||
                cd->ident == Id::TypeInfo_Class ||
                cd->ident == Id::TypeInfo_Typedef ||
                cd->ident == Id::TypeInfo_Tuple ||
                cd == ClassDeclaration::object ||
                cd == Type::typeinfoclass ||
                cd == Module::moduleinfo ||
                strncmp(cd->ident->toChars(), "TypeInfo_", 9) == 0)
            {
                // Don't mangle parent
                ad->parent = NULL;
            }
        }

        visit((Dsymbol *)ad);

        ad->parent = parentsave;
    }

    void visit(TemplateInstance *ti)
    {
    #if 0
        printf("TemplateInstance::mangle() %p %s", ti, ti->toChars());
        if (ti->parent)
            printf("  parent = %s %s", ti->parent->kind(), ti->parent->toChars());
        printf("\n");
    #endif

        if (!ti->tempdecl)
            ti->error("is not defined");
        else
            mangleParent(ti);

        ti->getIdent();
        const char *id = ti->ident ? ti->ident->toChars() : ti->toChars();
        toBuffer(id, ti);

        //printf("TemplateInstance::mangle() %s = %s\n", ti->toChars(), ti->id);
    }

    void visit(Dsymbol *s)
    {
    #if 0
        printf("Dsymbol::mangle() '%s'", s->toChars());
        if (s->parent)
            printf("  parent = %s %s", s->parent->kind(), s->parent->toChars());
        printf("\n");
    #endif

        mangleParent(s);

        char *id = s->ident ? s->ident->toChars() : s->toChars();
        toBuffer(id, s);

        //printf("Dsymbol::mangle() %s = %s\n", s->toChars(), id);
    }

    ////////////////////////////////////////////////////////////////////////////

    void argsToDecoBuffer(Parameters *arguments)
    {
        //printf("Parameter::argsToDecoBuffer()\n");
        Parameter::foreach(arguments, &argsToDecoBufferDg, (void *)this);
    }

    static int argsToDecoBufferDg(void *ctx, size_t n, Parameter *arg)
    {
        arg->accept((Visitor *)ctx);
        return 0;
    }

    void visit(Parameter *p)
    {
        if (p->storageClass & STCscope)
            buf->writeByte('M');
        switch (p->storageClass & (STCin | STCout | STCref | STClazy))
        {
            case 0:
            case STCin:
                break;
            case STCout:
                buf->writeByte('J');
                break;
            case STCref:
                buf->writeByte('K');
                break;
            case STClazy:
                buf->writeByte('L');
                break;
            default:
    #ifdef DEBUG
                printf("storageClass = x%llx\n", p->storageClass & (STCin | STCout | STCref | STClazy));
                halt();
    #endif
                assert(0);
        }
        visitWithMask(p->type, 0);
    }
};

const char *mangle(Dsymbol *s)
{
    OutBuffer buf;
    Mangler v(&buf);
    s->accept(&v);
    return buf.extractString();
}

/******************************************************************************
 * Returns exact mangled name of function.
 */
const char *mangleExact(FuncDeclaration *fd)
{
    OutBuffer buf;
    Mangler v(&buf);
    v.mangleExact(fd);
    return buf.extractString();
}

void mangleToBuffer(Type *t, OutBuffer *buf)
{
    Mangler v(buf);
    v.visitWithMask(t, 0);
}

void mangleToBuffer(Type *t, OutBuffer *buf, bool internal)
{
    if (internal)
    {
        buf->writeByte(mangleChar[t->ty]);
        if (t->ty == Tarray)
            buf->writeByte(mangleChar[((TypeArray *)t)->next->ty]);
    }
    else if (t->deco)
        buf->writestring(t->deco);
    else
        mangleToBuffer(t, buf);
}
