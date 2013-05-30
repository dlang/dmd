
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
#include "mangle.h"
#include "target.h"

/******************************************************************************
 *  isv     : for the enclosing auto functions of an inner class/struct type.
 *            An aggregate type which defined inside auto function, it might
 *            become Voldemort Type so its object might be returned.
 *            This flag is necessary due to avoid mutual mangling
 *            between return type and enclosing scope. See bugzilla 8847.
 */
char *mangle(Declaration *sthis, bool isv)
{
    OutBuffer buf;
    char *id;
    Dsymbol *s;

    //printf("::mangle(%s)\n", sthis->toChars());
    s = sthis;
    do
    {
        //printf("mangle: s = %p, '%s', parent = %p\n", s, s->toChars(), s->parent);
        if (s->getIdent())
        {
            FuncDeclaration *fd = s->isFuncDeclaration();
            if (s != sthis && fd)
            {
                id = mangle(fd, isv);
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
        assert(fd && fd->inferRetType);
    }

    id = buf.toChars();
    buf.data = NULL;
    return id;
}

const char *Declaration::mangle(bool isv)
#if __DMC__
    __out(result)
    {
        assert(Target::validateMangle(loc, mangleOverride, strlen(result)));
    }
    __body
#endif
    {
        if (mangleOverride)
        {
            return mangleOverride;
        }
        //printf("Declaration::mangle(this = %p, '%s', parent = '%s', linkage = %d)\n", this, toChars(), parent ? parent->toChars() : "null", linkage);
        if (linkage != LINKd && (!parent || parent->isModule() || linkage == LINKcpp)) // if at global scope
        {
            // If it's not a D declaration, no mangling
            if (linkage == LINKcpp)
            {
                return Target::mangleSymbol(this, LINKcpp);
            }
            else if (linkage == LINKdefault)
            {
                error("forward declaration");
                return ident->toChars();
            }
            else
            {
                return ident->toChars();
            }
        }
        char *p = ::mangle(this, isv);
        OutBuffer buf;
        buf.writestring("_D");
        buf.writestring(p);
        p = buf.toChars();
        buf.data = NULL;
        //printf("Declaration::mangle(this = %p, '%s', parent = '%s', linkage = %d) = %s\n", this, toChars(), parent ? parent->toChars() : "null", linkage, p);
        return p;
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
const char *FuncDeclaration::mangle(bool isv)
{
    return isUnique() ? mangleExact(isv) : Dsymbol::mangle(isv);
}
// ditto
const char *FuncAliasDeclaration::mangle(bool isv)
{
    FuncDeclaration *f = toAliasFunc();
    FuncAliasDeclaration *fa = f->isFuncAliasDeclaration();
    if (!hasOverloads && !fa)
        return f->mangleExact(isv);
    if (fa)
        return fa->mangle(isv);
    return Dsymbol::mangle(isv);
}

/******************************************************************************
 * Returns exact mangled name of function.
 */
const char *FuncDeclaration::mangleExact(bool isv)
#if __DMC__
    __out(result)
    {
        assert(Target::validateMangle(loc, mangleOverride, strlen(result)));
    }
    __body
#endif
    {
        assert(!isFuncAliasDeclaration());

        if (mangleOverride)
            return Declaration::mangle(isv);

        if (isMain())
            return (char *)"_Dmain";

        if (isWinMain() || isDllMain() || ident == Id::tls_get_addr || ident == Id::__alloca)
            return ident->toChars();

        assert(this);
        return Declaration::mangle(isv);
    }


const char *TypedefDeclaration::mangle(bool isv)
{
    //printf("TypedefDeclaration::mangle() '%s'\n", toChars());
    return Dsymbol::mangle(isv);
}


const char *AggregateDeclaration::mangle(bool isv)
{
#if 1
    //printf("AggregateDeclaration::mangle() '%s'\n", toChars());
    if (Dsymbol *p = toParent2())
    {   if (FuncDeclaration *fd = p->isFuncDeclaration())
        {   // This might be the Voldemort Type
            const char *id = Dsymbol::mangle(fd->inferRetType || getFuncTemplateDecl(fd));
            //printf("isv ad %s, %s\n", toChars(), id);
            return id;
        }
    }
#endif
    return Dsymbol::mangle(isv);
}

const char *StructDeclaration::mangle(bool isv)
{
    //printf("StructDeclaration::mangle() '%s'\n", toChars());
    return AggregateDeclaration::mangle(isv);
}

const char *ClassDeclaration::mangle(bool isv)
{
    Dsymbol *parentsave = parent;

    //printf("ClassDeclaration::mangle() %s.%s\n", parent->toChars(), toChars());

    /* These are reserved to the compiler, so keep simple
     * names for them.
     */
    if (ident == Id::Exception)
    {   if (parent->ident == Id::object)
            parent = NULL;
    }
    else if (ident == Id::TypeInfo   ||
//      ident == Id::Exception ||
        ident == Id::TypeInfo_Struct   ||
        ident == Id::TypeInfo_Class    ||
        ident == Id::TypeInfo_Typedef  ||
        ident == Id::TypeInfo_Tuple ||
        this == object     ||
        this == Type::typeinfoclass  ||
        this == Module::moduleinfo ||
        memcmp(ident->toChars(), "TypeInfo_", 9) == 0
       )
        parent = NULL;

    const char *id = AggregateDeclaration::mangle(isv);
    parent = parentsave;
    return id;
}


const char *TemplateInstance::mangle(bool isv)
{
    OutBuffer buf;

#if 0
    printf("TemplateInstance::mangle() %p %s", this, toChars());
    if (parent)
        printf("  parent = %s %s", parent->kind(), parent->toChars());
    printf("\n");
#endif
    getIdent();
    const char *id = ident ? ident->toChars() : toChars();
    if (!tempdecl)
        error("is not defined");
    else
    {
        Dsymbol *par = enclosing || isTemplateMixin() ? parent : tempdecl->parent;
        if (par)
        {
            const char *p = par->mangle();
            if (p[0] == '_' && p[1] == 'D')
                p += 2;
            buf.writestring(p);
        }
    }
    buf.printf("%llu%s", (ulonglong)strlen(id), id);
    id = buf.toChars();
    buf.data = NULL;
    //printf("TemplateInstance::mangle() %s = %s\n", toChars(), id);
    return id;
}

const char *Dsymbol::mangle(bool isv)
{
    OutBuffer buf;
    char *id;

#if 0
    printf("Dsymbol::mangle() '%s'", toChars());
    if (parent)
        printf("  parent = %s %s", parent->kind(), parent->toChars());
    printf("\n");
#endif
    id = ident ? ident->toChars() : toChars();
    if (parent)
    {
        const char *p = parent->mangle(isv);
        if (p[0] == '_' && p[1] == 'D')
            p += 2;
        buf.writestring(p);
    }
    buf.printf("%llu%s", (ulonglong)strlen(id), id);
    id = buf.toChars();
    buf.data = NULL;
    //printf("Dsymbol::mangle() %s = %s\n", toChars(), id);
    return id;
}

const char *Dsymbol::mangleX(Mangler *m)
{
    return m->mangleDsymbol(this);
}
const char *VarDeclaration::mangleX(Mangler *m)
{
    return m->mangleDsymbol(this);
}
const char *FuncDeclaration::mangleX(Mangler *m)
{
    return m->mangleDsymbol(this);
}

void Type::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeBasic::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeVector::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeSArray::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeDArray::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeAArray::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypePointer::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeReference::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeFunction::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeDelegate::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeStruct::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeEnum::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeTypedef::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
void TypeClass::mangleX(Mangler *m, OutBuffer *buf)
{
    m->mangleType(this, buf);
}
