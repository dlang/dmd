
// Compiler implementation of the D programming language
// Copyright (c) 1999-2010 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
const char *mangle(Dsymbol *s, bool isv = false);
const char *mangleExact(FuncDeclaration *fd, bool isv = false);

/******************************************************************************
 *  isv     : for the enclosing auto functions of an inner class/struct type.
 *            An aggregate type which defined inside auto function, it might
 *            become Voldemort Type so its object might be returned.
 *            This flag is necessary due to avoid mutual mangling
 *            between return type and enclosing scope. See bugzilla 8847.
 */
char *mangleDecl(Declaration *sthis, bool isv)
{
    OutBuffer buf;
    char *id;
    Dsymbol *s;

    //printf("::mangleDecl(%s)\n", sthis->toChars());
    s = sthis;
    do
    {
        //printf("mangle: s = %p, '%s', parent = %p\n", s, s->toChars(), s->parent);
        if (s->getIdent())
        {
            FuncDeclaration *fd = s->isFuncDeclaration();
            if (s != sthis && fd)
            {
                id = mangleDecl(fd, isv);
                buf.prependstring(id);
                goto L1;
            }
            else
            {
                id = s->ident->toChars();
                size_t len = strlen(id);
                char tmp[sizeof(len) * 3 + 1];
                buf.prependstring(id);
                sprintf(tmp, "%d", (int)len);
                buf.prependstring(tmp);
            }
        }
        else
            buf.prependstring("0");

        TemplateInstance *ti = s->isTemplateInstance();
        if (ti && !ti->isTemplateMixin())
            s = ti->tempdecl->parent;
        else
            s = s->parent;
    } while (s);

//    buf.prependstring("_D");
L1:
    //printf("deco = '%s'\n", sthis->type->deco ? sthis->type->deco : "null");
    //printf("sthis->type = %s\n", sthis->type->toChars());
    FuncDeclaration *fd = sthis->isFuncDeclaration();
    if (fd && (fd->needThis() || fd->isNested()))
        buf.writeByte(Type::needThisPrefix());
    if (isv && fd && (fd->inferRetType || getFuncTemplateDecl(fd)))
    {
#if DDMD
        TypeFunction *tfn = (TypeFunction *)sthis->type->copy();
        TypeFunction *tfo = (TypeFunction *)sthis->originalType;
        tfn->purity      = tfo->purity;
        tfn->isnothrow   = tfo->isnothrow;
        tfn->isproperty  = tfo->isproperty;
        tfn->isref       = fd->storage_class & STCauto ? false : tfo->isref;
        tfn->trust       = tfo->trust;
        tfn->next        = NULL;     // do not mangle return type
        tfn->toDecoBuffer(&buf, 0);
#else
        TypeFunction tfn = *(TypeFunction *)sthis->type;
        TypeFunction *tfo = (TypeFunction *)sthis->originalType;
        tfn.purity      = tfo->purity;
        tfn.isnothrow   = tfo->isnothrow;
        tfn.isproperty  = tfo->isproperty;
        tfn.isref       = fd->storage_class & STCauto ? false : tfo->isref;
        tfn.trust       = tfo->trust;
        tfn.next        = NULL;     // do not mangle return type
        tfn.toDecoBuffer(&buf, 0);
#endif
    }
    else if (sthis->type->deco)
        buf.writestring(sthis->type->deco);
    else
    {
#ifdef DEBUG
        if (!fd->inferRetType)
            printf("%s\n", fd->toChars());
#endif
        assert(fd && fd->inferRetType && fd->type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)sthis->type;
        Type *tn = tf->next;
        tf->next = NULL;    // do not mangle undetermined return type
        tf->toDecoBuffer(&buf, 0);
        tf->next = tn;
    }

    id = buf.extractString();
    return id;
}

class Mangler : public Visitor
{
public:
    bool isv;
    const char *result;

    Mangler(bool isv)
        : isv(isv)
    {
        result = NULL;
    }

    void visit(Declaration *d)
    {
        //printf("Declaration::mangle(this = %p, '%s', parent = '%s', linkage = %d)\n", d, d->toChars(), d->parent ? d->parent->toChars() : "null", d->linkage);
        if (!d->parent || d->parent->isModule() || d->linkage == LINKcpp) // if at global scope
        {
            switch (d->linkage)
            {
                case LINKd:
                    break;

                case LINKc:
                case LINKwindows:
                case LINKpascal:
                    result = d->ident->toChars();
                    break;

                case LINKcpp:
                    result = toCppMangle(d);
                    break;

                case LINKdefault:
                    d->error("forward declaration");
                    result = d->ident->toChars();
                    break;

                default:
                    fprintf(stderr, "'%s', linkage = %d\n", d->toChars(), d->linkage);
                    assert(0);
            }
        }
        //printf("Declaration::mangle(this = %p, '%s', parent = '%s', linkage = %d) = %s\n", d, d->toChars(), d->parent ? d->parent->toChars() : "null", d->linkage, result);

        if (!result)
        {
            OutBuffer buf;
            buf.writestring("_D");
            buf.writestring(mangleDecl(d, isv));
            result = buf.extractString();
        }

    #ifdef DEBUG
        assert(result);
        size_t len = strlen(result);
        assert(len > 0);
        for (size_t i = 0; i < len; i++)
        {
            assert(result[i] == '_' ||
                   result[i] == '@' ||
                   result[i] == '?' ||
                   result[i] == '$' ||
                   isalnum(result[i]) || result[i] & 0x80);
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

    void mangleExact(FuncDeclaration *fd)
    {
        assert(!fd->isFuncAliasDeclaration());

        if (fd->mangleOverride)
        {
            result = fd->mangleOverride;
            return;
        }

        if (fd->isMain())
        {
            result = "_Dmain";
            return;
        }

        if (fd->isWinMain() || fd->isDllMain() || fd->ident == Id::tls_get_addr)
        {
            result = fd->ident->toChars();
            return;
        }

        visit((Declaration *)fd);
    }

    void visit(VarDeclaration *vd)
    {
        if (vd->mangleOverride)
        {
            result = vd->mangleOverride;
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
        //printf("AggregateDeclaration::mangle() '%s'\n", ad->toChars());
        if (Dsymbol *p = ad->toParent2())
        {
            if (FuncDeclaration *fd = p->isFuncDeclaration())
            {
                // This might be the Voldemort Type
                bool save = isv;
                isv = fd->inferRetType || getFuncTemplateDecl(fd);
                visit((Dsymbol *)ad);
                isv = save;
                //printf("isv ad %s, %s\n", ad->toChars(), result);
                return;
            }
        }

        visit((Dsymbol *)ad);
    }

    void visit(StructDeclaration *sd)
    {
        //printf("StructDeclaration::mangle() '%s'\n", sd->toChars());
        visit((AggregateDeclaration *)sd);
    }

    void visit(ClassDeclaration *cd)
    {
        Dsymbol *parentsave = cd->parent;

        //printf("ClassDeclaration::mangle() %s.%s\n", cd->parent->toChars(), cd->toChars());

        /* These are reserved to the compiler, so keep simple
         * names for them.
         */
        if (cd->ident == Id::Exception)
        {
            if (cd->parent->ident == Id::object)
                cd->parent = NULL;
        }
        else if (cd->ident == Id::TypeInfo ||
            cd->ident == Id::TypeInfo_Struct ||
            cd->ident == Id::TypeInfo_Class ||
            cd->ident == Id::TypeInfo_Typedef ||
            cd->ident == Id::TypeInfo_Tuple ||
            cd == ClassDeclaration::object ||
            cd == Type::typeinfoclass ||
            cd == Module::moduleinfo ||
            memcmp(cd->ident->toChars(), "TypeInfo_", 9) == 0)
            cd->parent = NULL;

        visit((AggregateDeclaration *)cd);
        cd->parent = parentsave;
        return;
    }

    void visit(TemplateInstance *ti)
    {
        OutBuffer buf;

    #if 0
        printf("TemplateInstance::mangle() %p %s", ti, ti->toChars());
        if (ti->parent)
            printf("  parent = %s %s", ti->parent->kind(), ti->parent->toChars());
        printf("\n");
    #endif
        ti->getIdent();
        const char *id = ti->ident ? ti->ident->toChars() : ti->toChars();
        if (!ti->tempdecl)
            ti->error("is not defined");
        else
        {
            Dsymbol *par = ti->isTemplateMixin() ? ti->parent : ti->tempdecl->parent;
            if (par)
            {
                const char *p = mangle(par, isv);
                if (p[0] == '_' && p[1] == 'D')
                    p += 2;
                buf.writestring(p);
            }
        }
        buf.printf("%llu%s", (ulonglong)strlen(id), id);
        id = buf.extractString();
        //printf("TemplateInstance::mangle() %s = %s\n", ti->toChars(), ti->id);
        result = id;
    }

    void visit(Dsymbol *s)
    {
    #if 0
        printf("Dsymbol::mangle() '%s'", s->toChars());
        if (s->parent)
            printf("  parent = %s %s", s->parent->kind(), s->parent->toChars());
        printf("\n");
    #endif

        char *id = s->ident ? s->ident->toChars() : s->toChars();
        OutBuffer buf;
        if (s->parent)
        {
            FuncDeclaration *f = s->parent->isFuncDeclaration();
            if (f)
                mangleExact(f);
            else
                s->parent->accept(this);
            if (result[0] == '_' && result[1] == 'D')
                result += 2;
            buf.writestring(result);
        }
        buf.printf("%llu%s", (ulonglong)strlen(id), id);
        id = buf.extractString();
        //printf("Dsymbol::mangle() %s = %s\n", s->toChars(), id);
        result = id;
    }
};

const char *mangle(Dsymbol *s, bool isv)
{
    Mangler v(isv);
    s->accept(&v);
    return v.result;
}

/******************************************************************************
 * Returns exact mangled name of function.
 */
const char *mangleExact(FuncDeclaration *fd, bool isv)
{
    Mangler v(isv);
    v.mangleExact(fd);
    return v.result;
}
