
// Compiler implementation of the D programming language
// Copyright (c) 1999-2009 by Digital Mars
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

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
char *cpp_mangle(Dsymbol *s);
#endif

void mangleFunc(OutBuffer *buf, FuncDeclaration *fd, bool inParent)
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

        tf->toDecoBuffer(buf);

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

void mangleParent(OutBuffer *buf, Dsymbol *s)
{
    Dsymbol *p;
    if (TemplateInstance *ti = s->isTemplateInstance())
        p = ti->isnested || ti->isTemplateMixin() ? ti->parent : ti->tempdecl->parent;
    else
        p = s->parent;

    if (p)
    {
        mangleParent(buf, p);

        if (p->ident)
        {
            const char *id = p->ident->toChars();
            buf->printf("%llu%s", (ulonglong)strlen(id), id);

            if (FuncDeclaration *f = p->isFuncDeclaration())
                mangleFunc(buf, f, true);
        }
        else
            buf->writeByte('0');
    }
}

void mangleDecl(OutBuffer *buf, Declaration *sthis)
{
    mangleParent(buf, sthis);

    assert(sthis->ident);
    const char *id = sthis->ident->toChars();
    buf->printf("%llu%s", (ulonglong)strlen(id), id);

    if (FuncDeclaration *fd = sthis->isFuncDeclaration())
    {
        mangleFunc(buf, fd, false);
    }
    else if (sthis->type->deco)
    {
        buf->writestring(sthis->type->deco);
    }
    else
        assert(0);
}

char *Declaration::mangle()
#if __DMC__
    __out(result)
    {
        int len = strlen(result);

        assert(len > 0);
        //printf("mangle: '%s' => '%s'\n", toChars(), result);
        for (int i = 0; i < len; i++)
        {
            assert(result[i] == '_' ||
                   result[i] == '@' ||
                   isalnum(result[i]) || result[i] & 0x80);
        }
    }
    __body
#endif
    {
        //printf("Declaration::mangle(this = %p, '%s', parent = '%s', linkage = %d)\n", this, toChars(), parent ? parent->toChars() : "null", linkage);
        if (!parent || parent->isModule())      // if at global scope
        {
            // If it's not a D declaration, no mangling
            switch (linkage)
            {
                case LINKd:
                    break;

                case LINKc:
                case LINKwindows:
                case LINKpascal:
                    return ident->toChars();

                case LINKcpp:
#if DMDV2 && (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
                    return cpp_mangle(this);
#else
                    // Windows C++ mangling is done by C++ back end
                    return ident->toChars();
#endif

                case LINKdefault:
                    error("forward declaration");
                    return ident->toChars();

                default:
                    fprintf(stdmsg, "'%s', linkage = %d\n", toChars(), linkage);
                    assert(0);
            }
        }
        OutBuffer buf;
        buf.writestring("_D");
        mangleDecl(&buf, this);
        char *p = buf.toChars();
        buf.data = NULL;
        //printf("Declaration::mangle(this = %p, '%s', parent = '%s', linkage = %d) = %s\n", this, toChars(), parent ? parent->toChars() : "null", linkage, p);
        return p;
    }

char *FuncDeclaration::mangle()
#if __DMC__
    __out(result)
    {
        assert(strlen(result) > 0);
    }
    __body
#endif
    {
        if (isMain())
            return (char *)"_Dmain";

        if (isWinMain() || isDllMain())
            return ident->toChars();

        assert(this);
        return Declaration::mangle();
    }

char *StructDeclaration::mangle()
{
    //printf("StructDeclaration::mangle() '%s'\n", toChars());
    return Dsymbol::mangle();
}


char *TypedefDeclaration::mangle()
{
    //printf("TypedefDeclaration::mangle() '%s'\n", toChars());
    return Dsymbol::mangle();
}


char *ClassDeclaration::mangle()
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
        this == classinfo  ||
        this == Module::moduleinfo ||
        memcmp(ident->toChars(), "TypeInfo_", 9) == 0
       )
        parent = NULL;

    char *id = Dsymbol::mangle();
    parent = parentsave;
    return id;
}


char *TemplateInstance::mangle()
{
#if 0
    printf("TemplateInstance::mangle() %s", toChars());
    if (parent)
        printf("  parent = %s %s", parent->kind(), parent->toChars());
    printf("\n");
#endif

    OutBuffer buf;
    if (!tempdecl)
        error("is not defined");
    else
        mangleParent(&buf, this);

    char *id = ident ? ident->toChars() : toChars();
    buf.printf("%zu%s", strlen(id), id);
    id = buf.toChars();
    buf.data = NULL;
    //printf("TemplateInstance::mangle() %s = %s\n", toChars(), id);
    return id;
}



char *Dsymbol::mangle()
{
#if 0
    printf("Dsymbol::mangle() '%s'", toChars());
    if (parent)
        printf("  parent = %s %s", parent->kind(), parent->toChars());
    printf("\n");
#endif
    OutBuffer buf;
    mangleParent(&buf, this);

    char *id = ident ? ident->toChars() : toChars();
    buf.printf("%zu%s", strlen(id), id);
    id = buf.toChars();
    buf.data = NULL;
    //printf("Dsymbol::mangle() %s = %s\n", toChars(), id);
    return id;
}


