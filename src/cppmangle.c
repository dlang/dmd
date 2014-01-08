
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "mars.h"
#include "dsymbol.h"
#include "mtype.h"
#include "scope.h"
#include "init.h"
#include "expression.h"
#include "attrib.h"
#include "declaration.h"
#include "template.h"
#include "id.h"
#include "enum.h"
#include "import.h"
#include "aggregate.h"

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS

/* Do mangling for C++ linkage.
 * Follows Itanium C++ ABI 1.86
 * No attempt is made to support mangling of templates, operator
 * overloading, or special functions.
 *
 * So why don't we use the C++ ABI for D name mangling?
 * Because D supports a lot of things (like modules) that the C++
 * ABI has no concept of. These affect every D mangled name,
 * so nothing would be compatible anyway.
 */

class CppMangleVisitor : public Visitor
{
    Objects components;
    OutBuffer buf;

    void writeBase36(size_t i)
    {
        if (i >= 36)
        {
            writeBase36(i / 36);
            i %= 36;
        }
        if (i < 10)
            buf.writeByte((char)(i + '0'));
        else if (i < 36)
            buf.writeByte((char)(i - 10 + 'A'));
        else
            assert(0);
    }

    int substitute(RootObject *p)
    {
        for (size_t i = 0; i < components.dim; i++)
        {
            if (p == components[i])
            {
                /* Sequence is S_, S0_, .., S9_, SA_, ..., SZ_, S10_, ...
                 */
                buf.writeByte('S');
                if (i)
                    writeBase36(i - 1);
                buf.writeByte('_');
                return 1;
            }
        }
        components.push(p);
        return 0;
    }

    int exist(RootObject *p)
    {
        for (size_t i = 0; i < components.dim; i++)
        {
            if (p == components[i])
            {
                return 1;
            }
        }
        return 0;
    }

    void store(RootObject *p)
    {
        components.push(p);
    }

    void source_name(Dsymbol *s)
    {
        char *name = s->ident->toChars();
        buf.printf("%d%s", strlen(name), name);
    }

    void prefix_name(Dsymbol *s)
    {
        if (!substitute(s))
        {
            Dsymbol *p = s->toParent();
            if (p && !p->isModule())
            {
                prefix_name(p);
            }
            source_name(s);
        }
    }

public:
    CppMangleVisitor(const char *prefix)
        : buf(), components()
    {
        buf.writestring(prefix);
    }

    char *finish()
    {
        buf.writeByte(0);
        return (char *)buf.extractData();
    }

    void cpp_mangle_name(Dsymbol *s)
    {
        Dsymbol *p = s->toParent();
        if (p && !p->isModule())
        {
            buf.writeByte('N');

            FuncDeclaration *fd = s->isFuncDeclaration();
            VarDeclaration *vd = s->isVarDeclaration();
            if (fd && fd->type->isConst())
            {
                buf.writeByte('K');
            }
            if (vd && !(vd->storage_class & (STCextern | STCgshared)))
            {
                s->error("C++ static non- __gshared non-extern variables not supported");
            }
            if (vd || fd)
            {
                prefix_name(p);
                source_name(s);
            }
            else
            {
                assert(0);
            }
            buf.writeByte('E');
        }
        else
            source_name(s);
    }

    void visit(Type *t)
    {
        /* Make this the 'vendor extended type' when there is no
         * C++ analog.
         * u <source-name>
         */
        if (!substitute(t))
        {   assert(t->deco);
            buf.printf("u%d%s", strlen(t->deco), t->deco);
        }
    }

    void visit(TypeBasic *t)
    {
        /* ABI spec says:
         * v        void
         * w        wchar_t
         * b        bool
         * c        char
         * a        signed char
         * h        unsigned char
         * s        short
         * t        unsigned short
         * i        int
         * j        unsigned int
         * l        long
         * m        unsigned long
         * x        long long, __int64
         * y        unsigned long long, __int64
         * n        __int128
         * o        unsigned __int128
         * f        float
         * d        double
         * e        long double, __float80
         * g        __float128
         * z        ellipsis
         * u <source-name>  # vendor extended type
         */

        char c;
        char p = 0;
        switch (t->ty)
        {
            case Tvoid:     c = 'v';        break;
            case Tint8:     c = 'a';        break;
            case Tuns8:     c = 'h';        break;
            case Tint16:    c = 's';        break;
            case Tuns16:    c = 't';        break;
            case Tint32:    c = 'i';        break;
            case Tuns32:    c = 'j';        break;
            case Tfloat32:  c = 'f';        break;
            case Tint64:    c = 'x';        break;
            case Tuns64:    c = 'y';        break;
            case Tfloat64:  c = 'd';        break;
            case Tfloat80:  c = 'e';        break;
            case Tbool:     c = 'b';        break;
            case Tchar:     c = 'c';        break;
            case Twchar:    c = 't';        break;
            case Tdchar:    c = 'w';        break;

            case Timaginary32: p = 'G'; c = 'f';    break;
            case Timaginary64: p = 'G'; c = 'd';    break;
            case Timaginary80: p = 'G'; c = 'e';    break;
            case Tcomplex32:   p = 'C'; c = 'f';    break;
            case Tcomplex64:   p = 'C'; c = 'd';    break;
            case Tcomplex80:   p = 'C'; c = 'e';    break;

            default:        assert(0);
        }
        if (p || t->isConst())
        {
            if (substitute(t))
                return;
        }

        if (t->isConst())
            buf.writeByte('K');

        if (p)
            buf.writeByte(p);

        buf.writeByte(c);
    }


    void visit(TypeVector *t)
    {
        if (!substitute(t))
        {
            buf.writestring("U8__vector");
            t->basetype->accept(this);
        }
    }

    void visit(TypeSArray *t)
    {
        if (!substitute(t))
        {
            buf.printf("A%llu_", t->dim ? t->dim->toInteger() : 0);
            t->next->accept(this);
        }
    }

    void visit(TypeDArray *t)
    {
        visit((Type *)t);
    }

    void visit(TypeAArray *t)
    {
        visit((Type *)t);
    }

    void visit(TypePointer *t)
    {
        if (!exist(t))
        {
            buf.writeByte('P');
            t->next->accept(this);
            store(t);
        }
        else
            substitute(t);
    }

    void visit(TypeReference *t)
    {
        if (!exist(t))
        {
            buf.writeByte('R');
            t->next->accept(this);
            store(t);
        }
        else
            substitute(t);
    }

    void visit(TypeFunction *t)
    {
        /*
         *  <function-type> ::= F [Y] <bare-function-type> E
         *  <bare-function-type> ::= <signature type>+
         *  # types are possible return type, then parameter types
         */

        /* ABI says:
            "The type of a non-static member function is considered to be different,
            for the purposes of substitution, from the type of a namespace-scope or
            static member function whose type appears similar. The types of two
            non-static member functions are considered to be different, for the
            purposes of substitution, if the functions are members of different
            classes. In other words, for the purposes of substitution, the class of
            which the function is a member is considered part of the type of
            function."

            BUG: Right now, types of functions are never merged, so our simplistic
            component matcher always finds them to be different.
            We should use Type::equals on these, and use different
            TypeFunctions for non-static member functions, and non-static
            member functions of different classes.
         */
        if (!exist(t))
        {
            buf.writeByte('F');
            if (t->linkage == LINKc || t->linkage == LINKobjc)
                buf.writeByte('Y');
            t->next->accept(this);
            argsCppMangle(t->parameters, t->varargs);
            buf.writeByte('E');
            store(t);
        }
        else
            substitute(t);
    }

    void visit(TypeDelegate *t)
    {
        visit((Type *)t);
    }

#if DMD_OBJC
    void visit (TypeObjcSelector *t)
    {
        buf.writestring("P13objc_selector");
    }
#endif

    void visit(TypeStruct *t)
    {
        if (!exist(t))
        {
            if (t->isConst())
                buf.writeByte('K');

            if (!substitute(t->sym))
                cpp_mangle_name(t->sym);

            if (t->isConst())
                store(t);
        }
        else
            substitute(t);
    }

    void visit(TypeEnum *t)
    {
        if (!exist(t))
        {
            if (t->isConst())
                buf.writeByte('K');

            if (!substitute(t->sym))
                cpp_mangle_name(t->sym);

            if (t->isConst())
                store(t);
        }
        else
            substitute(t);
    }

    void visit(TypeTypedef *t)
    {
        visit((Type *)t);
    }

    void visit(TypeClass *t)
    {
        if (!exist(t))
        {
            buf.writeByte('P');

            if (!substitute(t->sym))
                cpp_mangle_name(t->sym);

            store(t);
        }
        else
            substitute(t);
    }

    struct ArgsCppMangleCtx
    {
        CppMangleVisitor *v;
        size_t cnt;
    };

    void argsCppMangle(Parameters *arguments, int varargs)
    {
        size_t n = 0;
        if (arguments)
        {
            ArgsCppMangleCtx ctx = { this, 0 };
            Parameter::foreach(arguments, &argsCppMangleDg, &ctx);
            n = ctx.cnt;
        }
        if (varargs)
            buf.writestring("z");
        else if (!n)
            buf.writeByte('v');            // encode ( ) arguments
    }

    static int argsCppMangleDg(void *ctx, size_t n, Parameter *arg)
    {
        ArgsCppMangleCtx *p = (ArgsCppMangleCtx *)ctx;

        Type *t = arg->type->merge2();
        if (arg->storageClass & (STCout | STCref))
            t = t->referenceTo();
        else if (arg->storageClass & STClazy)
        {   // Mangle as delegate
            Type *td = new TypeFunction(NULL, t, 0, LINKd);
            td = new TypeDelegate(td);
            t = t->merge();
        }
        if (t->ty == Tsarray)
        {   // Mangle static arrays as pointers
            t = t->pointerTo();
        }

        /* If it is a basic, enum or struct type,
         * then don't mark it const
         */
        if ((t->ty == Tenum || t->ty == Tstruct || t->isTypeBasic()) && t->isConst())
            t->mutableOf()->accept(p->v);
        else
            t->accept(p->v);

        p->cnt++;
        return 0;
    }
};

char *toCppMangle(Dsymbol *s)
{
    /*
     * <mangled-name> ::= _Z <encoding>
     * <encoding> ::= <function name> <bare-function-type>
     *         ::= <data name>
     *         ::= <special-name>
     */

    CppMangleVisitor v(global.params.isOSX ? "__Z" : "_Z");

    v.cpp_mangle_name(s);

    FuncDeclaration *fd = s->isFuncDeclaration();
    if (fd)
    {   // add <bare-function-type>
        assert(fd->type->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)fd->type;
        v.argsCppMangle(tf->parameters, tf->varargs);
    }
    return v.finish();
}

#else

char *toCppMangle(Dsymbol *s)
{
    // Windows C++ mangling is done by C++ back end
    return s->ident->toChars();
}

#endif

