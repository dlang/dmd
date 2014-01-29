
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
#include "target.h"

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
        //printf("push %s\n", p ? p->toChars() : NULL);
        components.push(p);
    }

    void source_name(Dsymbol *s)
    {
        char *name = s->ident->toChars();
        TemplateInstance *ti = s->isTemplateInstance();
        if (ti)
        {
            if (!substitute(ti->tempdecl))
            {
                store(ti->tempdecl);
                name = ti->name->toChars();
                buf.printf("%d%s", strlen(name), name);
            }
            buf.writeByte('I');
            bool is_var_arg = false;
            for (size_t i = 0; i < ti->tiargs->dim; i++)
            {
                RootObject *o = (RootObject *)(*ti->tiargs)[i];

                TemplateParameter *tp = NULL;
                TemplateValueParameter *tv = NULL;
                TemplateTupleParameter *tt = NULL;
                if (!is_var_arg)
                {
                    TemplateDeclaration *td = ti->tempdecl->isTemplateDeclaration();
                    tp = (*td->parameters)[i];
                    tv = tp->isTemplateValueParameter();
                    tt = tp->isTemplateTupleParameter();
                }
                /*
                 *           <template-arg> ::= <type>            # type or template
                 *                          ::= <expr-primary>   # simple expressions
                 */

                if (tt)
                {
                    buf.writeByte('I');
                    is_var_arg = true;
                    tp = NULL;
                }

                if (tv)
                {
                    // <expr-primary> ::= L <type> <value number> E                   # integer literal
                    if (tv->valType->isintegral())
                    {
                        Expression* e = isExpression(o);
                        assert(e);
                        buf.writeByte('L');
                        tv->valType->accept(this);
                        if (tv->valType->isunsigned())
                        {
                            buf.printf("%llu", e->toUInteger());
                        }
                        else
                        {
                            dinteger_t val = e->toInteger();
                            if (val < 0)
                            {
                                val = -val;
                                buf.writeByte('n');
                            }
                            buf.printf("%lld", val);
                        }
                        buf.writeByte('E');
                    }
                    else
                    {
                        s->error("ICE: C++ %s template value parameter is not supported", tv->valType->toChars());
                        assert(0);
                    }
                }
                else if (!tp || tp->isTemplateTypeParameter())
                {
                    Type *t = isType(o);
                    assert(t);
                    t->accept(this);
                }
                else if (tp->isTemplateAliasParameter())
                {
                    Dsymbol* d = isDsymbol(o);
                    Expression* e = isExpression(o);
                    if (!d && !e)
                    {
                        s->error("ICE: %s is unsupported parameter for C++ template: (%s)", o->toChars());
                        assert(0);
                    }
                    if (d && d->isFuncDeclaration())
                    {
                        bool is_nested = d->toParent() && !d->toParent()->isModule() && ((TypeFunction *)d->isFuncDeclaration()->type)->linkage == LINKcpp;
                        if (is_nested) buf.writeByte('X');
                        buf.writeByte('L');
                        mangle_function(d->isFuncDeclaration());
                        buf.writeByte('E');
                        if (is_nested) buf.writeByte('E');
                    }
                    else if (e && e->op == TOKvar && ((VarExp*)e)->var->isVarDeclaration())
                    {
                        VarDeclaration *vd = ((VarExp*)e)->var->isVarDeclaration();
                        buf.writeByte('L');
                        mangle_variable(vd, true);
                        buf.writeByte('E');
                    }
                    else if (d && d->isTemplateDeclaration() && d->isTemplateDeclaration()->onemember)
                    {
                        if (!substitute(d))
                        {
                            cpp_mangle_name(d);
                            store(d);
                        }
                    }
                    else
                    {
                        s->error("ICE: %s is unsupported parameter for C++ template", o->toChars());
                        assert(0);
                    }

                }
                else
                {
                    s->error("ICE: C++ templates support only integral value , type parameters, alias templates and alias function parameters");
                    assert(0);
                }
            }
            if (is_var_arg)
            {
                buf.writeByte('E');
            }
            buf.writeByte('E');
            return;
        }
        else
        {
            buf.printf("%d%s", strlen(name), name);
        }
    }

    void prefix_name(Dsymbol *s)
    {
        if (!substitute(s))
        {
            store(s);
            Dsymbol *p = s->toParent();
            if (p && p->isTemplateInstance())
            {
                s = p;
                if (exist(p->isTemplateInstance()->tempdecl))
                {
                    p = NULL;
                }
                else
                {
                    p = p->toParent();
                }
            }

            if (p && !p->isModule())
            {
                prefix_name(p);
            }
            source_name(s);
        }
    }

    void cpp_mangle_name(Dsymbol *s)
    {
        Dsymbol *p = s->toParent();
        bool dont_write_prefix = false;
        if (p && p->isTemplateInstance())
        {
            s = p;
            if (exist(p->isTemplateInstance()->tempdecl))
                dont_write_prefix = true;
            p = p->toParent();
        }

        if (p && !p->isModule())
        {
            buf.writeByte('N');
            if (!dont_write_prefix)
                prefix_name(p);
            source_name(s);
            buf.writeByte('E');
        }
        else
            source_name(s);
    }


    void mangle_variable(VarDeclaration *d, bool is_temp_arg_ref)
    {

        if (!(d->storage_class & (STCextern | STCgshared)))
        {
            d->error("ICE: C++ static non- __gshared non-extern variables not supported");
            assert(0);
        }

        Dsymbol *p = d->toParent();
        if (p && !p->isModule()) //for example: char Namespace1::beta[6] should be mangled as "_ZN10Namespace14betaE"
        {
            buf.writestring(global.params.isOSX ? "__ZN" : "_ZN");      // "__Z" for OSX, "_Z" for other
            prefix_name(p);
            source_name(d);
            buf.writeByte('E');
        }
        else //char beta[6] should mangle as "beta"
        {
            if (!is_temp_arg_ref)
            {
                if (global.params.isOSX)
                    buf.writeByte('_');
                buf.writestring(d->ident->toChars());
            }
            else
            {
                buf.writestring(global.params.isOSX ? "__Z" : "_Z");
                source_name(d);
            }
        }
    }


    void mangle_function(FuncDeclaration *d)
    {
        /*
         * <mangled-name> ::= _Z <encoding>
         * <encoding> ::= <function name> <bare-function-type>
         *         ::= <data name>
         *         ::= <special-name>
         */
        TypeFunction *tf = (TypeFunction *)d->type;

        buf.writestring(global.params.isOSX ? "__Z" : "_Z");      // "__Z" for OSX, "_Z" for other
        Dsymbol *p = d->toParent();
        if (p && !p->isModule() && tf->linkage == LINKcpp)
        {
            buf.writeByte('N');
            if (d->type->isConst())
                buf.writeByte('K');
            prefix_name(p);
            if (d->isDtorDeclaration())
            {
                buf.writestring("D1");
            }
            else
            {
                source_name(d);
            }
            buf.writeByte('E');
        }
        else
        {
            source_name(d);
        }

        if (tf->linkage == LINKcpp) //Template args accept extern "C" symbols with special mangling
        {
            assert(tf->ty == Tfunction);
            argsCppMangle(tf->parameters, tf->varargs);
        }
    }

    static int argsCppMangleDg(void *ctx, size_t n, Parameter *arg)
    {
        CppMangleVisitor *mangler = (CppMangleVisitor *)ctx;

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
            t->error(Loc(), "ICE: Unable to pass static array to extern(C++) function.");
            t->error(Loc(), "Use pointer instead.");
            assert(0);
            //t = t->nextOf()->pointerTo();
        }

        /* If it is a basic, enum or struct type,
         * then don't mark it const
         */
        if ((t->ty == Tenum || t->ty == Tstruct || t->ty == Tpointer || t->isTypeBasic()) && t->isConst())
            t->mutableOf()->accept(mangler);
        else
            t->accept(mangler);

        return 0;
    }

    void argsCppMangle(Parameters *arguments, int varargs)
    {
        if (arguments)
            Parameter::foreach(arguments, &argsCppMangleDg, (void*)this);

        if (varargs)
            buf.writestring("z");
        else if (!arguments || !arguments->dim)
            buf.writeByte('v');            // encode ( ) arguments
    }

public:
    CppMangleVisitor()
        : buf(), components()
    {
    }

    char* mangleOf(Dsymbol *s)
    {
        VarDeclaration *vd = s->isVarDeclaration();
        FuncDeclaration *fd = s->isFuncDeclaration();
        if (vd)
        {
            mangle_variable(vd, false);
        }
        else
        {
            mangle_function(fd);
        }
        return buf.extractString();
    }

    void visit(Type *t)
    {
        if (t->isImmutable() || t->isShared())
        {
            t->error(Loc(), "ICE: shared or immutable types can not be mapped to C++ (%s)", t->toChars());
        }
        else
        {
            t->error(Loc(), "ICE: Unsupported type %s\n", t->toChars());
        }
        assert(0); //Assert, because this error should be handled in frontend
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
            case Tint64:    c = (Target::longsize == 8 ? 'l' : 'x'); break;
            case Tuns64:    c = (Target::longsize == 8 ? 'm' : 'y'); break;
            case Tfloat64:  c = 'd';        break;
            case Tfloat80:  c = (Target::realsize - Target::realpad == 16) ? 'g' : 'e'; break;
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

            default:        visit((Type *)t); return;
        }
        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }
        if (p || t->isConst())
        {
            if (substitute(t))
            {
                return;
            }
            else
            {
                store(t);
            }
        }

        if (t->isShared())
            buf.writeByte('V'); //shared -> volatile

        if (t->isConst())
            buf.writeByte('K');

        if (p)
            buf.writeByte(p);

        buf.writeByte(c);
    }


    void visit(TypeVector *t)
    {
        if (substitute(t)) return;
        store(t);
        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }
        if (t->isConst())
            buf.writeByte('K');
        assert(t->basetype && t->basetype->ty == Tsarray);
        assert(((TypeSArray *)t->basetype)->dim);
        //buf.printf("Dv%llu_", ((TypeSArray *)t->basetype)->dim->toInteger());// -- Gnu ABI v.4
        buf.writestring("U8__vector"); //-- Gnu ABI v.3
        t->basetype->nextOf()->accept(this);
        
    }

    void visit(TypeSArray *t)
    {
        if (!substitute(t))
        store(t);
        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }
        if (t->isConst())
            buf.writeByte('K');
        buf.printf("A%llu_", t->dim ? t->dim->toInteger() : 0);
        t->next->accept(this);
        
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
        if (substitute(t)) return;
        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }
        if (t->isConst())
            buf.writeByte('K');
        buf.writeByte('P');
        t->next->accept(this);
        store(t);


    }

    void visit(TypeReference *t)
    {
        if (substitute(t)) return;
        buf.writeByte('R');
        t->next->accept(this);
        store(t);
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
        if (substitute(t)) return;
        buf.writeByte('F');
        if (t->linkage == LINKc)
            buf.writeByte('Y');
        Type *tn = t->next;
        if (t->isref)
            tn  = tn->referenceTo();
        tn->accept(this);
        argsCppMangle(t->parameters, t->varargs);
        buf.writeByte('E');
        store(t);


    }

    void visit(TypeDelegate *t)
    {
        visit((Type *)t);
    }

    void visit(TypeStruct *t)
    {
        if (substitute(t)) return;
        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }
        if (t->isConst())
            buf.writeByte('K');

        if (!substitute(t->sym))
        {
            cpp_mangle_name(t->sym);
            store(t->sym);
        }

        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }

        if (t->isConst())
            store(t);
    }

    void visit(TypeEnum *t)
    {
        if (substitute(t)) return;
        if (t->isShared())
            buf.writeByte('V');
        if (t->isConst())
            buf.writeByte('K');
        
        if (!substitute(t->sym))
        {
            cpp_mangle_name(t->sym);
            store(t->sym);
        }
        
        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }

        if (t->isConst())
            store(t);
        
    }

    void visit(TypeTypedef *t)
    {
        visit((Type *)t);
    }

    void visit(TypeClass *t)
    {
        if (substitute(t)) return;
        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }
        
        buf.writeByte('P');
        if (t->isConst())
            buf.writeByte('K');
        if (!substitute(t->sym))
        {
            cpp_mangle_name(t->sym);
            store(t->sym);
        }
        if (t->isConst())
            store(NULL);
        store(t);
    }
};

char *toCppMangle(Dsymbol *s)
{
    CppMangleVisitor v;
    return v.mangleOf(s);
}

#else

char *toCppMangle(Dsymbol *s)
{
    // Windows C++ mangling is done by C++ back end
    return s->ident->toChars();
}

#endif

