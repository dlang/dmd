
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

char *toCppMangle(Dsymbol *s);

class Mangler : public Visitor
{
public:
    OutBuffer *buf;

    Mangler(OutBuffer *buf)
    {
        this->buf = buf;
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
            TypeFunction *tfx = (TypeFunction *)fd->type;
            TypeFunction *tf = (TypeFunction *)fd->originalType;

            // replace with the actual parameter types
            Parameters *prms = tf->parameters;
            tf->parameters = tfx->parameters;

            // do not mangle return type
            Type *tret = tf->next;
            tf->next = NULL;

            tf->toDecoBuffer(buf, 0);

            tf->parameters = prms;
            tf->next = tret;
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
