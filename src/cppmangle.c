
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/cppmangle.c
 */

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

/* Do mangling for C++ linkage.
 * No attempt is made to support mangling of templates, operator
 * overloading, or special functions.
 *
 * So why don't we use the C++ ABI for D name mangling?
 * Because D supports a lot of things (like modules) that the C++
 * ABI has no concept of. These affect every D mangled name,
 * so nothing would be compatible anyway.
 */

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS

/*
 * Follows Itanium C++ ABI 1.86
 */

class CppMangleVisitor : public Visitor
{
    Objects components;
    OutBuffer buf;
    bool is_top_level;
    bool components_on;

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

    bool substitute(RootObject *p)
    {
        //printf("substitute %s\n", p ? p->toChars() : NULL);
        if (components_on)
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
                    return true;
                }
            }
        return false;
    }

    bool exist(RootObject *p)
    {
        //printf("exist %s\n", p ? p->toChars() : NULL);
        if (components_on)
            for (size_t i = 0; i < components.dim; i++)
            {
                if (p == components[i])
                {
                    return true;
                }
            }
        return false;
    }

    void store(RootObject *p)
    {
        //printf("store %s\n", p ? p->toChars() : NULL);
        if (components_on)
            components.push(p);
    }

    void source_name(Dsymbol *s, bool skipname = false)
    {
        //printf("source_name(%s)\n", s->toChars());
        TemplateInstance *ti = s->isTemplateInstance();
        if (ti)
        {
            if (!skipname && !substitute(ti->tempdecl))
            {
                store(ti->tempdecl);
                const char *name = ti->toAlias()->ident->toChars();
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
                    assert(td);
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
                        Expression *e = isExpression(o);
                        assert(e);
                        buf.writeByte('L');
                        tv->valType->accept(this);
                        if (tv->valType->isunsigned())
                        {
                            buf.printf("%llu", e->toUInteger());
                        }
                        else
                        {
                            sinteger_t val = e->toInteger();
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
                        s->error("Internal Compiler Error: C++ %s template value parameter is not supported", tv->valType->toChars());
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
                    Dsymbol *d = isDsymbol(o);
                    Expression *e = isExpression(o);
                    if (!d && !e)
                    {
                        s->error("Internal Compiler Error: %s is unsupported parameter for C++ template: (%s)", o->toChars());
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
                            cpp_mangle_name(d, false);
                        }
                    }
                    else
                    {
                        s->error("Internal Compiler Error: %s is unsupported parameter for C++ template", o->toChars());
                        assert(0);
                    }

                }
                else
                {
                    s->error("Internal Compiler Error: C++ templates support only integral value, type parameters, alias templates and alias function parameters");
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
            const char *name = s->ident->toChars();
            buf.printf("%d%s", strlen(name), name);
        }
    }

    void prefix_name(Dsymbol *s)
    {
        //printf("prefix_name(%s)\n", s->toChars());
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

    /* Is s the initial qualifier?
     */
    bool is_initial_qualifier(Dsymbol *s)
    {
        Dsymbol *p = s->toParent();
        if (p && p->isTemplateInstance())
        {
            if (exist(p->isTemplateInstance()->tempdecl))
            {
                return true;
            }
            p = p->toParent();
        }

        return !p || p->isModule();
    }

    void cpp_mangle_name(Dsymbol *s, bool qualified)
    {
        //printf("cpp_mangle_name(%s, %d)\n", s->toChars(), qualified);
        Dsymbol *p = s->toParent();
        Dsymbol *se = s;
        bool dont_write_prefix = false;
        if (p && p->isTemplateInstance())
        {
            se = p;
            if (exist(p->isTemplateInstance()->tempdecl))
                dont_write_prefix = true;
            p = p->toParent();
        }

        if (p && !p->isModule())
        {
            /* The N..E is not required if:
             * 1. the parent is 'std'
             * 2. 'std' is the initial qualifier
             * 3. there is no CV-qualifier or a ref-qualifier for a member function
             * ABI 5.1.8
             */
            if (p->ident == Id::std &&
                is_initial_qualifier(p) &&
                !qualified)
            {
                if (s->ident == Id::allocator)
                {
                    buf.writestring("Sa");      // "Sa" is short for ::std::allocator
                    source_name(se, true);
                }
                else if (s->ident == Id::basic_string)
                {
                    components_on = false;      // turn off substitutions
                    buf.writestring("Sb");      // "Sb" is short for ::std::basic_string
                    size_t off = buf.offset;
                    source_name(se, true);
                    components_on = true;

                    // Replace ::std::basic_string < char, ::std::char_traits<char>, ::std::allocator<char> >
                    // with Ss
                    //printf("xx: '%.*s'\n", (int)(buf.offset - off), buf.data + off);
                    if (buf.offset - off >= 26 &&
                        memcmp(buf.data + off, "IcSt11char_traitsIcESaIcEE", 26) == 0)
                    {
                        buf.remove(off - 2, 28);
                        buf.insert(off - 2, (const char *)"Ss", 2);
                        return;
                    }
                    buf.setsize(off);
                    source_name(se, true);
                }
                else if (s->ident == Id::basic_istream ||
                         s->ident == Id::basic_ostream ||
                         s->ident == Id::basic_iostream)
                {
                    /* Replace
                     * ::std::basic_istream<char,  std::char_traits<char> > with Si
                     * ::std::basic_ostream<char,  std::char_traits<char> > with So
                     * ::std::basic_iostream<char, std::char_traits<char> > with Sd
                     */
                    size_t off = buf.offset;
                    components_on = false;      // turn off substitutions
                    source_name(se, true);
                    components_on = true;

                    //printf("xx: '%.*s'\n", (int)(buf.offset - off), buf.data + off);
                    if (buf.offset - off >= 21 &&
                        memcmp(buf.data + off, "IcSt11char_traitsIcEE", 21) == 0)
                    {
                        buf.remove(off, 21);
                        char mbuf[2];
                        mbuf[0] = 'S';
                        mbuf[1] = 'i';
                        if (s->ident == Id::basic_ostream)
                            mbuf[1] = 'o';
                        else if(s->ident == Id::basic_iostream)
                            mbuf[1] = 'd';
                        buf.insert(off, mbuf, 2);
                        return;
                    }
                    buf.setsize(off);
                    buf.writestring("St");
                    source_name(se);
                }
                else
                {
                    buf.writestring("St");
                    source_name(se);
                }
            }
            else
            {
                buf.writeByte('N');
                if (!dont_write_prefix)
                    prefix_name(p);
                source_name(se);
                buf.writeByte('E');
            }
        }
        else
            source_name(se);
        store(s);
    }

    void mangle_variable(VarDeclaration *d, bool is_temp_arg_ref)
    {

        if (!(d->storage_class & (STCextern | STCgshared)))
        {
            d->error("Internal Compiler Error: C++ static non- __gshared non-extern variables not supported");
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
        //printf("mangle_function(%s)\n", d->toChars());
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

            // See ABI 5.1.8 Compression

            // Replace ::std::allocator with Sa
            if (buf.offset >= 17 && memcmp(buf.data, "_ZN3std9allocator", 17) == 0)
            {
                buf.remove(3, 14);
                buf.insert(3, (const char *)"Sa", 2);
            }

            // Replace ::std::basic_string with Sb
            if (buf.offset >= 21 && memcmp(buf.data, "_ZN3std12basic_string", 21) == 0)
            {
                buf.remove(3, 18);
                buf.insert(3, (const char *)"Sb", 2);
            }

            // Replace ::std with St
            if (buf.offset >= 7 && memcmp(buf.data, "_ZN3std", 7) == 0)
            {
                buf.remove(3, 4);
                buf.insert(3, (const char *)"St", 2);
            }

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

    static int paramsCppMangleDg(void *ctx, size_t n, Parameter *fparam)
    {
        CppMangleVisitor *mangler = (CppMangleVisitor *)ctx;

        Type *t = fparam->type->merge2();
        if (fparam->storageClass & (STCout | STCref))
            t = t->referenceTo();
        else if (fparam->storageClass & STClazy)
        {
            // Mangle as delegate
            Type *td = new TypeFunction(NULL, t, 0, LINKd);
            td = new TypeDelegate(td);
            t = t->merge();
        }
        if (t->ty == Tsarray)
        {
            // Mangle static arrays as pointers
            t->error(Loc(), "Internal Compiler Error: unable to pass static array to extern(C++) function.");
            t->error(Loc(), "Use pointer instead.");
            assert(0);
            //t = t->nextOf()->pointerTo();
        }

        /* If it is a basic, enum or struct type,
         * then don't mark it const
         */
        mangler->is_top_level = true;
        if ((t->ty == Tenum || t->ty == Tstruct || t->ty == Tpointer || t->isTypeBasic()) && t->isConst())
            t->mutableOf()->accept(mangler);
        else
            t->accept(mangler);
        mangler->is_top_level = false;
        return 0;
    }

    void argsCppMangle(Parameters *parameters, int varargs)
    {
        if (parameters)
            Parameter::foreach(parameters, &paramsCppMangleDg, (void*)this);

        if (varargs)
            buf.writestring("z");
        else if (!parameters || !parameters->dim)
            buf.writeByte('v');            // encode ( ) parameters
    }

public:
    CppMangleVisitor()
        : buf(), components(), is_top_level(false), components_on(true)
    {
    }

    char *mangleOf(Dsymbol *s)
    {
        VarDeclaration *vd = s->isVarDeclaration();
        FuncDeclaration *fd = s->isFuncDeclaration();
        if (vd)
        {
            mangle_variable(vd, false);
        }
        else if (fd)
        {
            mangle_function(fd);
        }
        else
        {
            assert(0);
        }
        return buf.extractString();
    }

    void visit(Type *t)
    {
        if (t->isImmutable() || t->isShared())
        {
            t->error(Loc(), "Internal Compiler Error: shared or immutable types can not be mapped to C++ (%s)", t->toChars());
        }
        else
        {
            t->error(Loc(), "Internal Compiler Error: unsupported type %s\n", t->toChars());
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
            case Tint64:    c = (Target::c_longsize == 8 ? 'l' : 'x'); break;
            case Tuns64:    c = (Target::c_longsize == 8 ? 'm' : 'y'); break;
            case Tfloat64:  c = 'd';        break;
            case Tfloat80:  c = (Target::realsize - Target::realpad == 16) ? 'g' : 'e'; break;
            case Tbool:     c = 'b';        break;
            case Tchar:     c = 'c';        break;
            case Twchar:    c = 't';        break; // unsigned short
            case Tdchar:    c = 'w';        break; // wchar_t (UTF-32)

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

        if (t->isConst())
            buf.writeByte('K');

        if (p)
            buf.writeByte(p);

        buf.writeByte(c);
    }


    void visit(TypeVector *t)
    {
        is_top_level = false;
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
        is_top_level = false;
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
        is_top_level = false;
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
        is_top_level = false;
        if (substitute(t)) return;
        buf.writeByte('R');
        t->next->accept(this);
        store(t);
    }

    void visit(TypeFunction *t)
    {
        is_top_level = false;
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
        Identifier *id = t->sym->ident;
        //printf("struct id = '%s'\n", id->toChars());
        char c;
        if (id == Id::__c_long)
            c = 'l';
        else if (id == Id::__c_ulong)
            c = 'm';
        else
            c = 0;
        if (c)
        {
            if (t->isImmutable() || t->isShared())
            {
                visit((Type *)t);
            }
            if (t->isConst())
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

            if (t->isConst())
                buf.writeByte('K');

            buf.writeByte(c);
            return;
        }

        is_top_level = false;

        if (substitute(t)) return;
        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }
        if (t->isConst())
            buf.writeByte('K');

        if (!substitute(t->sym))
        {
            cpp_mangle_name(t->sym, t->isConst());
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
        is_top_level = false;
        if (substitute(t)) return;

        if (t->isConst())
            buf.writeByte('K');

        if (!substitute(t->sym))
        {
            cpp_mangle_name(t->sym, t->isConst());
        }

        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }

        if (t->isConst())
            store(t);
    }

    void visit(TypeClass *t)
    {
        if (substitute(t)) return;
        if (t->isImmutable() || t->isShared())
        {
            visit((Type *)t);
        }
        if (t->isConst() && !is_top_level)
            buf.writeByte('K');
        is_top_level = false;
        buf.writeByte('P');

        if (t->isConst())
            buf.writeByte('K');

        if (!substitute(t->sym))
        {
            cpp_mangle_name(t->sym, t->isConst());
        }
        if (t->isConst())
            store(NULL);
        store(t);
    }
};

char *toCppMangle(Dsymbol *s)
{
    //printf("toCppMangle(%s)\n", s->toChars());
    CppMangleVisitor v;
    return v.mangleOf(s);
}

#elif TARGET_WINDOS

// Windows DMC and Microsoft Visual C++ mangling
#define VC_SAVED_TYPE_CNT 10
#define VC_SAVED_IDENT_CNT 10

class VisualCPPMangler : public Visitor
{
    const char *saved_idents[VC_SAVED_IDENT_CNT];
    Type *saved_types[VC_SAVED_TYPE_CNT];

    // IS_NOT_TOP_TYPE: when we mangling one argument, we can call visit several times (for base types of arg type)
    // but we must save only arg type:
    // For example: if we have an int** argument, we should save "int**" but visit will be called for "int**", "int*", "int"
    // This flag is set up by the visit(NextType, ) function  and should be reset when the arg type output is finished.
    // MANGLE_RETURN_TYPE: return type shouldn't be saved and substituted in arguments
    // IGNORE_CONST: in some cases we should ignore CV-modifiers.

    enum Flags
    {
        IS_NOT_TOP_TYPE    = 0x1,
        MANGLE_RETURN_TYPE = 0x2,
        IGNORE_CONST       = 0x4,
        IS_DMC             = 0x8
    };

    int flags;
    OutBuffer buf;

    VisualCPPMangler(VisualCPPMangler *rvl)
        : buf(),
        flags(0)
    {
        flags |= (rvl->flags & IS_DMC);
        memcpy(&saved_idents, &rvl->saved_idents, sizeof(const char*) * VC_SAVED_IDENT_CNT);
        memcpy(&saved_types, &rvl->saved_types, sizeof(Type*) * VC_SAVED_TYPE_CNT);
    }
public:

    VisualCPPMangler(bool isdmc)
        : buf(),
        flags(0)
    {
        if (isdmc)
        {
            flags |= IS_DMC;
        }
        memset(&saved_idents, 0, sizeof(const char*) * VC_SAVED_IDENT_CNT);
        memset(&saved_types, 0, sizeof(Type*) * VC_SAVED_TYPE_CNT);
    }

    void visit(Type *type)
    {
        if (type->isImmutable() || type->isShared())
        {
            type->error(Loc(), "Internal Compiler Error: shared or immutable types can not be mapped to C++ (%s)", type->toChars());
        }
        else
        {
            type->error(Loc(), "Internal Compiler Error: unsupported type %s\n", type->toChars());
        }
        assert(0); // Assert, because this error should be handled in frontend
    }

    void visit(TypeBasic *type)
    {
        //printf("visit(TypeBasic); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (type->isImmutable() || type->isShared())
        {
            visit((Type*)type);
            return;
        }

        if (type->isConst() && ((flags & IS_NOT_TOP_TYPE) || (flags & IS_DMC)))
        {
            if (checkTypeSaved(type)) return;
        }

        if ((type->ty == Tbool) && checkTypeSaved(type))// try to replace long name with number
        {
            return;
        }
        mangleModifier(type);
        switch (type->ty)
        {
            case Tvoid:     buf.writeByte('X');        break;
            case Tint8:     buf.writeByte('C');        break;
            case Tuns8:     buf.writeByte('E');        break;
            case Tint16:    buf.writeByte('F');        break;
            case Tuns16:    buf.writeByte('G');        break;
            case Tint32:    buf.writeByte('H');        break;
            case Tuns32:    buf.writeByte('I');        break;
            case Tfloat32:  buf.writeByte('M');        break;
            case Tint64:    buf.writestring("_J");     break;
            case Tuns64:    buf.writestring("_K");     break;
            case Tfloat64:  buf.writeByte('N');        break;
            case Tbool:     buf.writestring("_N");     break;
            case Tchar:     buf.writeByte('D');        break;
            case Tdchar:    buf.writeByte('I');        break; // unsigned int

            case Tfloat80:
                if (flags & IS_DMC)
                    buf.writestring("_Z"); // DigitalMars long double
                else
                    buf.writestring("_T"); // Intel long double
                break;

            case Twchar:
                if (flags & IS_DMC)
                    buf.writestring("_Y"); // DigitalMars wchar_t
                else
                    buf.writestring("_W"); // Visual C++ wchar_t
                break;

            default:        visit((Type*)type); return;
        }
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    void visit(TypeVector *type)
    {
        //printf("visit(TypeVector); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type)) return;
        buf.writestring("T__m128@@"); // may be better as __m128i or __m128d?
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    void visit(TypeSArray *type)
    {
        // This method can be called only for static variable type mangling.
        //printf("visit(TypeSArray); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type)) return;
        // first dimension always mangled as const pointer
        if (flags & IS_DMC)
            buf.writeByte('Q');
        else
            buf.writeByte('P');

        flags |= IS_NOT_TOP_TYPE;
        assert(type->next);
        if (type->next->ty == Tsarray)
        {
            mangleArray((TypeSArray*)type->next);
        }
        else
        {
            type->next->accept(this);
        }
    }

    // attention: D int[1][2]* arr mapped to C++ int arr[][2][1]; (because it's more typical situation)
    // There is not way to map int C++ (*arr)[2][1] to D
    void visit(TypePointer *type)
    {
        //printf("visit(TypePointer); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (type->isImmutable() || type->isShared())
        {
            visit((Type*)type);
            return;
        }

        assert(type->next);
        if (type->next->ty == Tfunction)
        {
            const char *arg = mangleFunctionType((TypeFunction*)type->next); // compute args before checking to save; args should be saved before function type

            // If we've mangled this function early, previous call is meaningless.
            // However we should do it before checking to save types of function arguments before function type saving.
            // If this function was already mangled, types of all it arguments are save too, thus previous can't save
            // anything if function is saved.
            if (checkTypeSaved(type))
                return;

            if (type->isConst())
                buf.writeByte('Q'); // const
            else
                buf.writeByte('P'); // mutable

            buf.writeByte('6'); // pointer to a function
            buf.writestring(arg);
            flags &= ~IS_NOT_TOP_TYPE;
            flags &= ~IGNORE_CONST;
            return;
        }
        else if (type->next->ty == Tsarray)
        {
            if (checkTypeSaved(type))
                return;
            mangleModifier(type);

            if (type->isConst() || !(flags & IS_DMC))
                buf.writeByte('Q'); // const
            else
                buf.writeByte('P'); // mutable

            if (global.params.is64bit)
                buf.writeByte('E');
            flags |= IS_NOT_TOP_TYPE;

            mangleArray((TypeSArray*)type->next);
            return;
        }
        else
        {
            if (checkTypeSaved(type))
                return;
            mangleModifier(type);

            if (type->isConst())
            {
                buf.writeByte('Q'); // const
            }
            else
            {
                buf.writeByte('P'); // mutable
            }

            if (global.params.is64bit)
                buf.writeByte('E');
            flags |= IS_NOT_TOP_TYPE;
            type->next->accept(this);
        }
    }

    void visit(TypeReference *type)
    {
        //printf("visit(TypeReference); type = %s\n", type->toChars());
        if (checkTypeSaved(type)) return;

        if (type->isImmutable() || type->isShared())
        {
            visit((Type*)type);
            return;
        }

        buf.writeByte('A'); // mutable

        if (global.params.is64bit)
            buf.writeByte('E');
        flags |= IS_NOT_TOP_TYPE;
        assert(type->next);
        if (type->next->ty == Tsarray)
        {
            mangleArray((TypeSArray*)type->next);
        }
        else
        {
            type->next->accept(this);
        }
    }

    void visit(TypeFunction *type)
    {
        // We can mangle pointer to a function, not function.
        visit((Type*)type);
    }

    void visit(TypeStruct *type)
    {
        Identifier *id = type->sym->ident;
        char c;
        if (id == Id::__c_long_double)
            c = 'O';                    // VC++ long double
        else if (id == Id::__c_long)
            c = 'J';                    // VC++ long
        else if (id == Id::__c_ulong)
            c = 'K';                    // VC++ unsigned long
        else
            c = 0;

        if (c)
        {
            if (type->isImmutable() || type->isShared())
            {
                visit((Type*)type);
                return;
            }

            if (type->isConst() && ((flags & IS_NOT_TOP_TYPE) || (flags & IS_DMC)))
            {
                if (checkTypeSaved(type)) return;
            }

            mangleModifier(type);
            buf.writeByte(c);
        }
        else
        {
            if (checkTypeSaved(type)) return;
            //printf("visit(TypeStruct); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
            mangleModifier(type);
            if (type->sym->isUnionDeclaration())
                buf.writeByte('T');
            else
                buf.writeByte('U');
            mangleIdent(type->sym);
        }
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    void visit(TypeEnum *type)
    {
        //printf("visit(TypeEnum); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type)) return;
        mangleModifier(type);
        buf.writeByte('W');

        switch (type->sym->memtype->ty)
        {
            case Tchar:
            case Tint8:
                buf.writeByte('0');
                break;
            case Tuns8:
                buf.writeByte('1');
                break;
            case Tint16:
                buf.writeByte('2');
                break;
            case Tuns16:
                buf.writeByte('3');
                break;
            case Tint32:
                buf.writeByte('4');
                break;
            case Tuns32:
                buf.writeByte('5');
                break;
            case Tint64:
                buf.writeByte('6');
                break;
            case Tuns64:
                buf.writeByte('7');
                break;
            default:
                visit((Type*)type);
                break;
        }

        mangleIdent(type->sym);
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    // D class mangled as pointer to C++ class
    // const(Object) mangled as Object const* const
    void visit(TypeClass *type)
    {
        //printf("visit(TypeClass); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type)) return;
        if (flags & IS_NOT_TOP_TYPE)
            mangleModifier(type);

        if (type->isConst())
            buf.writeByte('Q');
        else
            buf.writeByte('P');

        if (global.params.is64bit)
            buf.writeByte('E');

        flags |= IS_NOT_TOP_TYPE;
        mangleModifier(type);

        buf.writeByte('V');

        mangleIdent(type->sym);
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    char *mangleOf(Dsymbol *s)
    {
        VarDeclaration *vd = s->isVarDeclaration();
        FuncDeclaration *fd = s->isFuncDeclaration();
        if (vd)
        {
            mangleVariable(vd);
        }
        else if (fd)
        {
            mangleFunction(fd);
        }
        else
        {
            assert(0);
        }
        return buf.extractString();
    }
private:

    void mangleFunction(FuncDeclaration *d)
    {
        // <function mangle> ? <qualified name> <flags> <return type> <arg list>
        assert(d);
        buf.writeByte('?');
        mangleIdent(d);

        if (d->needThis()) // <flags> ::= <virtual/protection flag> <const/volatile flag> <calling convention flag>
        {
            // Pivate methods always non-virtual in D and it should be mangled as non-virtual in C++
            if (d->isVirtual() && d->vtblIndex != -1)
            {
                switch (d->protection.kind)
                {
                    case PROTprivate:
                        buf.writeByte('E');
                        break;
                    case PROTprotected:
                        buf.writeByte('M');
                        break;
                    default:
                        buf.writeByte('U');
                        break;
                }
            }
            else
            {
                switch (d->protection.kind)
                {
                    case PROTprivate:
                        buf.writeByte('A');
                        break;
                    case PROTprotected:
                        buf.writeByte('I');
                        break;
                    default:
                        buf.writeByte('Q');
                        break;
                }
            }
            if (global.params.is64bit)
                buf.writeByte('E');
            if (d->type->isConst())
            {
                buf.writeByte('B');
            }
            else
            {
                buf.writeByte('A');
            }
        }
        else if (d->isMember2()) // static function
        {                        // <flags> ::= <virtual/protection flag> <calling convention flag>
            switch (d->protection.kind)
            {
                case PROTprivate:
                    buf.writeByte('C');
                    break;
                case PROTprotected:
                    buf.writeByte('K');
                    break;
                default:
                    buf.writeByte('S');
                    break;
            }
        }
        else // top-level function
        {    // <flags> ::= Y <calling convention flag>
            buf.writeByte('Y');
        }

        const char *args = mangleFunctionType((TypeFunction *)d->type, (bool)d->needThis(), d->isCtorDeclaration() || d->isDtorDeclaration());
        buf.writestring(args);
    }

    void mangleVariable(VarDeclaration *d)
    {
        // <static variable mangle> ::= ? <qualified name> <protection flag> <const/volatile flag> <type>
        assert(d);
        if (!(d->storage_class & (STCextern | STCgshared)))
        {
            d->error("Internal Compiler Error: C++ static non- __gshared non-extern variables not supported");
            assert(0);
        }
        buf.writeByte('?');
        mangleIdent(d);

        assert(!d->needThis());

        if (d->parent && d->parent->isModule()) // static member
        {
            buf.writeByte('3');
        }
        else
        {
            switch (d->protection.kind)
            {
                case PROTprivate:
                    buf.writeByte('0');
                    break;
                case PROTprotected:
                    buf.writeByte('1');
                    break;
                default:
                    buf.writeByte('2');
                    break;
            }
        }

        char cv_mod = 0;
        Type *t = d->type;

        if (t->isImmutable() || t->isShared())
        {
            visit((Type*)t);
            return;
        }
        if (t->isConst())
        {
            cv_mod = 'B'; // const
        }
        else
        {
            cv_mod = 'A'; // mutable
        }

        if (t->ty != Tpointer)
            t = t->mutableOf();

        t->accept(this);

        if ((t->ty == Tpointer || t->ty == Treference) && global.params.is64bit)
        {
            buf.writeByte('E');
        }

        buf.writeByte(cv_mod);
    }

    void mangleName(Dsymbol *sym, bool dont_use_back_reference = false)
    {
        //printf("mangleName('%s')\n", sym->toChars());
        const char *name = NULL;
        bool is_dmc_template = false;
        if (sym->isDtorDeclaration())
        {
            buf.writestring("?1");
            return;
        }
        if (TemplateInstance *ti = sym->isTemplateInstance())
        {
            VisualCPPMangler tmp((flags & IS_DMC) ? true : false);
            tmp.buf.writeByte('?');
            tmp.buf.writeByte('$');
            tmp.buf.writestring(ti->name->toChars());
            tmp.saved_idents[0] = ti->name->toChars();
            tmp.buf.writeByte('@');
            if (flags & IS_DMC)
            {
                tmp.mangleIdent(sym->parent, true);
                is_dmc_template = true;
            }

            bool is_var_arg = false;
            for (size_t i = 0; i < ti->tiargs->dim; i++)
            {
                RootObject *o = (*ti->tiargs)[i];

                TemplateParameter *tp = NULL;
                TemplateValueParameter *tv = NULL;
                TemplateTupleParameter *tt = NULL;
                if (!is_var_arg)
                {
                    TemplateDeclaration *td = ti->tempdecl->isTemplateDeclaration();
                    assert(td);
                    tp = (*td->parameters)[i];
                    tv = tp->isTemplateValueParameter();
                    tt = tp->isTemplateTupleParameter();
                }

                if (tt)
                {
                    is_var_arg = true;
                    tp = NULL;
                }
                if (tv)
                {
                    if (tv->valType->isintegral())
                    {

                        tmp.buf.writeByte('$');
                        tmp.buf.writeByte('0');

                        Expression *e = isExpression(o);
                        assert(e);

                        if (tv->valType->isunsigned())
                        {
                            tmp.mangleNumber(e->toUInteger());
                        }
                        else
                        {
                            sinteger_t val = e->toInteger();
                            if (val < 0)
                            {
                                val = -val;
                                tmp.buf.writeByte('?');
                            }
                            tmp.mangleNumber(val);
                        }
                    }
                    else
                    {
                        sym->error("Internal Compiler Error: C++ %s template value parameter is not supported", tv->valType->toChars());
                        assert(0);
                    }
                }
                else if (!tp || tp->isTemplateTypeParameter())
                {
                    Type *t = isType(o);
                    assert(t);
                    t->accept(&tmp);
                }
                else if (tp->isTemplateAliasParameter())
                {
                    Dsymbol *d = isDsymbol(o);
                    Expression *e = isExpression(o);
                    if (!d && !e)
                    {
                        sym->error("Internal Compiler Error: %s is unsupported parameter for C++ template", o->toChars());
                        assert(0);
                    }
                    if (d && d->isFuncDeclaration())
                    {
                        tmp.buf.writeByte('$');
                        tmp.buf.writeByte('1');
                        tmp.mangleFunction(d->isFuncDeclaration());
                    }
                    else if (e && e->op == TOKvar && ((VarExp*)e)->var->isVarDeclaration())
                    {
                        tmp.buf.writeByte('$');
                        if (flags & IS_DMC)
                            tmp.buf.writeByte('1');
                        else
                            tmp.buf.writeByte('E');
                        tmp.mangleVariable(((VarExp*)e)->var->isVarDeclaration());
                    }
                    else if (d && d->isTemplateDeclaration() && d->isTemplateDeclaration()->onemember)
                    {

                        Dsymbol *ds = d->isTemplateDeclaration()->onemember;
                        if (flags & IS_DMC)
                        {
                            tmp.buf.writeByte('V');
                        }
                        else
                        {
                            if (ds->isUnionDeclaration())
                            {
                                tmp.buf.writeByte('T');
                            }
                            else if (ds->isStructDeclaration())
                            {
                                tmp.buf.writeByte('U');
                            }
                            else if (ds->isClassDeclaration())
                            {
                                tmp.buf.writeByte('V');
                            }
                            else
                            {
                                sym->error("Internal Compiler Error: C++ templates support only integral value, type parameters, alias templates and alias function parameters");
                                assert(0);
                            }
                        }
                        tmp.mangleIdent(d);
                    }
                    else
                    {
                        sym->error("Internal Compiler Error: %s is unsupported parameter for C++ template: (%s)", o->toChars());
                        assert(0);
                    }

                }
                else
                {
                    sym->error("Internal Compiler Error: C++ templates support only integral value, type parameters, alias templates and alias function parameters");
                    assert(0);
                }
            }
            name = tmp.buf.extractString();
        }
        else
        {
            name = sym->ident->toChars();
        }
        assert(name);
        if (!is_dmc_template)
        {
            if (dont_use_back_reference)
            {
                saveIdent(name);
            }
            else
            {
                if (checkAndSaveIdent(name)) return;
            }
        }
        buf.writestring(name);
        buf.writeByte('@');
    }

    // returns true if name already saved
    bool checkAndSaveIdent(const char *name)
    {
        for (size_t i = 0; i < VC_SAVED_IDENT_CNT; i++)
        {
            if (!saved_idents[i]) // no saved same name
            {
                saved_idents[i] = name;
                break;
            }

            if (!strcmp(saved_idents[i], name)) // ok, we've found same name. use index instead of name
            {
                buf.writeByte(i + '0');
                return true;
            }
        }
        return false;
    }

    void saveIdent(const char *name)
    {
        for (size_t i = 0; i < VC_SAVED_IDENT_CNT; i++)
        {
            if (!saved_idents[i]) // no saved same name
            {
                saved_idents[i] = name;
                break;
            }

            if (!strcmp(saved_idents[i], name)) // ok, we've found same name. use index instead of name
            {
                return;
            }
        }
    }

    void mangleIdent(Dsymbol *sym, bool dont_use_back_reference = false)
    {
        // <qualified name> ::= <sub-name list> @
        // <sub-name list>  ::= <sub-name> <name parts>
        //                  ::= <sub-name>

        // <sub-name> ::= <identifier> @
        //            ::= ?$ <identifier> @ <template args> @
        //            :: <back reference>

        // <back reference> ::= 0-9

        // <template args> ::= <template arg> <template args>
        //                ::= <template arg>

        // <template arg>  ::= <type>
        //                ::= $0<encoded integral number>

        //printf("mangleIdent('%s')\n", sym->toChars());
        Dsymbol *p = sym;
        if (p->toParent() && p->toParent()->isTemplateInstance())
        {
            p = p->toParent();
        }
        while (p && !p->isModule())
        {
            mangleName(p, dont_use_back_reference);

            p = p->toParent();
            if (p->toParent() && p->toParent()->isTemplateInstance())
            {
                p = p->toParent();
            }
        }
        if (!dont_use_back_reference)
            buf.writeByte('@');
    }

    void mangleNumber(dinteger_t num)
    {
        if (!num) // 0 encoded as "A@"
        {
            buf.writeByte('A');
            buf.writeByte('@');
            return;
        }
        if (num <= 10) // 5 encoded as "4"
        {
            buf.writeByte((char)(num - 1 + '0'));
            return;
        }

        char buff[17];
        buff[16] = 0;
        size_t i = 16;
        while (num)
        {
            --i;
            buff[i] = num % 16 + 'A';
            num /=16;
        }
        buf.writestring(&buff[i]);
        buf.writeByte('@');
    }

    bool checkTypeSaved(Type *type)
    {
        if (flags & IS_NOT_TOP_TYPE) return false;
        if (flags & MANGLE_RETURN_TYPE) return false;
        for (size_t i = 0; i < VC_SAVED_TYPE_CNT; i++)
        {
            if (!saved_types[i]) // no saved same type
            {
                saved_types[i] = type;
                return false;
            }
            if (saved_types[i]->equals(type)) // ok, we've found same type. use index instead of type
            {
                buf.writeByte(i + '0');
                flags &= ~IS_NOT_TOP_TYPE;
                flags &= ~IGNORE_CONST;
                return true;
            }
        }
        return false;
    }

    void mangleModifier(Type *type)
    {
        if (flags & IGNORE_CONST) return;
        if (type->isImmutable() || type->isShared())
        {
            visit((Type*)type);
            return;
        }
        if (type->isConst())
        {
            if (flags & IS_NOT_TOP_TYPE)
                buf.writeByte('B'); // const
                else if ((flags & IS_DMC) && type->ty != Tpointer)
                    buf.writestring("_O");
        }
        else if (flags & IS_NOT_TOP_TYPE)
            buf.writeByte('A'); // mutable
    }

    void mangleArray(TypeSArray *type)
    {
        mangleModifier(type);
        size_t i=0;
        Type *cur = type;
        while (cur && cur->ty == Tsarray)
        {
            i++;
            cur = cur->nextOf();
        }
        buf.writeByte('Y');
        mangleNumber(i); // count of dimensions
        cur = type;
        while (cur && cur->ty == Tsarray) // sizes of dimensions
        {
            TypeSArray *sa = (TypeSArray*)cur;
            mangleNumber(sa->dim ? sa->dim->toInteger() : 0);
            cur = cur->nextOf();
        }
        flags |= IGNORE_CONST;
        cur->accept(this);
    }

    const char *mangleFunctionType(TypeFunction *type, bool needthis = false, bool noreturn = false)
    {
        VisualCPPMangler tmp(this);
        // Calling convention
        if (global.params.is64bit) // always Microsoft x64 calling convention
        {
            tmp.buf.writeByte('A');
        }
        else
        {
            switch (type->linkage)
            {
                case LINKc:
                    tmp.buf.writeByte('A');
                    break;
                case LINKcpp:
                    if (needthis && type->varargs != 1)
                        tmp.buf.writeByte('E'); // thiscall
                    else
                        tmp.buf.writeByte('A'); // cdecl
                    break;
                case LINKwindows:
                    tmp.buf.writeByte('G'); // stdcall
                    break;
                case LINKpascal:
                    tmp.buf.writeByte('C');
                    break;
                default:
                    tmp.visit((Type*)type);
                    break;
            }
        }

        tmp.flags &= ~IS_NOT_TOP_TYPE;
        if (noreturn)
        {
            tmp.buf.writeByte('@');
        }
        else
        {
            Type *rettype = type->next;
            if (type->isref)
                rettype = rettype->referenceTo();
            flags &= ~IGNORE_CONST;
            if (rettype->ty == Tstruct || rettype->ty == Tenum)
            {
                Identifier *id = rettype->toDsymbol(NULL)->ident;
                if (id != Id::__c_long_double &&
                    id != Id::__c_long &&
                    id != Id::__c_ulong)
                {
                    tmp.buf.writeByte('?');
                    tmp.buf.writeByte('A');
                }
            }
            tmp.flags |= MANGLE_RETURN_TYPE;
            rettype->accept(&tmp);
            tmp.flags &= ~MANGLE_RETURN_TYPE;
        }
        if (!type->parameters || !type->parameters->dim)
        {
            if (type->varargs == 1)
                tmp.buf.writeByte('Z');
            else
                tmp.buf.writeByte('X');
        }
        else
        {
            for (size_t i = 0; i < type->parameters->dim; ++i)
            {
                tmp.mangleParameter((*type->parameters)[i]);
            }
            if (type->varargs == 1)
            {
                tmp.buf.writeByte('Z');
            }
            else
            {
                tmp.buf.writeByte('@');
            }
        }

        tmp.buf.writeByte('Z');
        const char *ret = tmp.buf.extractString();
        memcpy(&saved_idents, &tmp.saved_idents, sizeof(const char*) * VC_SAVED_IDENT_CNT);
        memcpy(&saved_types, &tmp.saved_types, sizeof(Type*) * VC_SAVED_TYPE_CNT);
        return ret;
    }

    void mangleParameter(Parameter *p)
    {
        Type *t = p->type;
        if (p->storageClass & (STCout | STCref))
        {
            t = t->referenceTo();
        }
        else if (p->storageClass & STClazy)
        {
            // Mangle as delegate
            Type *td = new TypeFunction(NULL, t, 0, LINKd);
            td = new TypeDelegate(td);
            t = t->merge();
        }
        if (t->ty == Tsarray)
        {
            t->error(Loc(), "Internal Compiler Error: unable to pass static array to extern(C++) function.");
            t->error(Loc(), "Use pointer instead.");
            assert(0);
        }
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
        t->accept(this);
    }
};

char *toCppMangle(Dsymbol *s)
{
    VisualCPPMangler v(!global.params.mscoff);
    return v.mangleOf(s);
}

#else
#error "fix this"
#endif
