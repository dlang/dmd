/**
 * Compiler implementation of the $(LINK2 http://www.dlang.org, D programming language)
 *
 * Copyright: Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors: Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/cppmangle.d, _cppmangle.d)
 */

module ddmd.cppmangle;

// Online documentation: https://dlang.org/phobos/ddmd_cppmangle.html

import core.stdc.string;
import core.stdc.stdio;

import ddmd.arraytypes;
import ddmd.declaration;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.mtype;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.target;
import ddmd.tokens;
import ddmd.typesem;
import ddmd.visitor;

/* Do mangling for C++ linkage.
 * Follows Itanium C++ ABI 1.86 section 5.1
 * http://refspecs.linux-foundation.org/cxxabi-1.86.html#mangling
 */

extern (C++):

extern (C++) const(char)* toCppMangleItanium(Dsymbol s)
{
    //printf("toCppMangleItanium(%s)\n", s.toChars());
    scope CppMangleVisitor v = new CppMangleVisitor();
    return v.mangleOf(s);
}

extern (C++) const(char)* cppTypeInfoMangleItanium(Dsymbol s)
{
    //printf("cppTypeInfoMangle(%s)\n", s.toChars());
    scope CppMangleVisitor v = new CppMangleVisitor();
    return v.mangle_typeinfo(s);
}

private final class CppMangleVisitor : Visitor
{
    alias visit = super.visit;
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
            buf.writeByte(cast(char)(i + '0'));
        else if (i < 36)
            buf.writeByte(cast(char)(i - 10 + 'A'));
        else
            assert(0);
    }

    bool substitute(RootObject p)
    {
        //printf("substitute %s\n", p ? p.toChars() : null);
        if (components_on)
            for (size_t i = 0; i < components.dim; i++)
            {
                //printf("    component[%d] = %s\n", i, components[i] ? components[i].toChars() : null);
                if (p == components[i])
                {
                    //printf("\tmatch\n");
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

    bool exist(RootObject p)
    {
        //printf("exist %s\n", p ? p.toChars() : null);
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

    void store(RootObject p)
    {
        //printf("store %s\n", p ? p.toChars() : "null");
        if (components_on)
            components.push(p);
    }

    void source_name(Dsymbol s, bool skipname = false)
    {
        //printf("source_name(%s)\n", s.toChars());
        TemplateInstance ti = s.isTemplateInstance();
        if (ti)
        {
            if (!skipname && !substitute(ti.tempdecl))
            {
                store(ti.tempdecl);
                const(char)* name = ti.tempdecl.toAlias().ident.toChars();
                buf.printf("%d%s", strlen(name), name);
            }
            buf.writeByte('I');
            bool is_var_arg = false;
            for (size_t i = 0; i < ti.tiargs.dim; i++)
            {
                RootObject o = cast(RootObject)(*ti.tiargs)[i];
                TemplateParameter tp = null;
                TemplateValueParameter tv = null;
                TemplateTupleParameter tt = null;
                if (!is_var_arg)
                {
                    TemplateDeclaration td = ti.tempdecl.isTemplateDeclaration();
                    assert(td);
                    tp = (*td.parameters)[i];
                    tv = tp.isTemplateValueParameter();
                    tt = tp.isTemplateTupleParameter();
                }
                /*
                 *           <template-arg> ::= <type>            # type or template
                 *                          ::= <expr-primary>   # simple expressions
                 */
                if (tt)
                {
                    buf.writeByte('I');
                    is_var_arg = true;
                    tp = null;
                }
                if (tv)
                {
                    // <expr-primary> ::= L <type> <value number> E                   # integer literal
                    if (tv.valType.isintegral())
                    {
                        Expression e = isExpression(o);
                        assert(e);
                        buf.writeByte('L');
                        tv.valType.accept(this);
                        if (tv.valType.isunsigned())
                        {
                            buf.printf("%llu", e.toUInteger());
                        }
                        else
                        {
                            sinteger_t val = e.toInteger();
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
                        s.error("Internal Compiler Error: C++ %s template value parameter is not supported", tv.valType.toChars());
                        fatal();
                    }
                }
                else if (!tp || tp.isTemplateTypeParameter())
                {
                    Type t = isType(o);
                    assert(t);
                    t.accept(this);
                }
                else if (tp.isTemplateAliasParameter())
                {
                    Dsymbol d = isDsymbol(o);
                    Expression e = isExpression(o);
                    if (!d && !e)
                    {
                        s.error("Internal Compiler Error: %s is unsupported parameter for C++ template: (%s)", o.toChars());
                        fatal();
                    }
                    if (d && d.isFuncDeclaration())
                    {
                        bool is_nested = d.toParent() && !d.toParent().isModule() && (cast(TypeFunction)d.isFuncDeclaration().type).linkage == LINKcpp;
                        if (is_nested)
                            buf.writeByte('X');
                        buf.writeByte('L');
                        mangle_function(d.isFuncDeclaration());
                        buf.writeByte('E');
                        if (is_nested)
                            buf.writeByte('E');
                    }
                    else if (e && e.op == TOKvar && (cast(VarExp)e).var.isVarDeclaration())
                    {
                        VarDeclaration vd = (cast(VarExp)e).var.isVarDeclaration();
                        buf.writeByte('L');
                        mangle_variable(vd, true);
                        buf.writeByte('E');
                    }
                    else if (d && d.isTemplateDeclaration() && d.isTemplateDeclaration().onemember)
                    {
                        if (!substitute(d))
                        {
                            cpp_mangle_name(d, false);
                        }
                    }
                    else
                    {
                        s.error("Internal Compiler Error: %s is unsupported parameter for C++ template", o.toChars());
                        fatal();
                    }
                }
                else
                {
                    s.error("Internal Compiler Error: C++ templates support only integral value, type parameters, alias templates and alias function parameters");
                    fatal();
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
            const(char)* name = s.ident.toChars();
            buf.printf("%d%s", strlen(name), name);
        }
    }

    void prefix_name(Dsymbol s)
    {
        //printf("prefix_name(%s)\n", s.toChars());
        if (!substitute(s))
        {
            Dsymbol p = s.toParent();
            if (p && p.isTemplateInstance())
            {
                s = p;
                if (exist(p.isTemplateInstance().tempdecl))
                {
                    p = null;
                }
                else
                {
                    p = p.toParent();
                }
            }
            if (p && !p.isModule())
            {
                if (p.ident == Id.std && is_initial_qualifier(p))
                    buf.writestring("St");
                else
                    prefix_name(p);
            }
            if (!(s.ident == Id.std && is_initial_qualifier(s)))
                store(s);
            source_name(s);
        }
    }

    /* Is s the initial qualifier?
     */
    bool is_initial_qualifier(Dsymbol s)
    {
        Dsymbol p = s.toParent();
        if (p && p.isTemplateInstance())
        {
            if (exist(p.isTemplateInstance().tempdecl))
            {
                return true;
            }
            p = p.toParent();
        }
        return !p || p.isModule();
    }

    void cpp_mangle_name(Dsymbol s, bool qualified)
    {
        //printf("cpp_mangle_name(%s, %d)\n", s.toChars(), qualified);
        Dsymbol p = s.toParent();
        Dsymbol se = s;
        bool dont_write_prefix = false;
        if (p && p.isTemplateInstance())
        {
            se = p;
            if (exist(p.isTemplateInstance().tempdecl))
                dont_write_prefix = true;
            p = p.toParent();
        }
        if (p && !p.isModule())
        {
            /* The N..E is not required if:
             * 1. the parent is 'std'
             * 2. 'std' is the initial qualifier
             * 3. there is no CV-qualifier or a ref-qualifier for a member function
             * ABI 5.1.8
             */
            if (p.ident == Id.std && is_initial_qualifier(p) && !qualified)
            {
                if (s.ident == Id.allocator)
                {
                    buf.writestring("Sa"); // "Sa" is short for ::std::allocator
                    source_name(se, true);
                }
                else if (s.ident == Id.basic_string)
                {
                    components_on = false; // turn off substitutions
                    buf.writestring("Sb"); // "Sb" is short for ::std::basic_string
                    size_t off = buf.offset;
                    source_name(se, true);
                    components_on = true;
                    // Replace ::std::basic_string < char, ::std::char_traits<char>, ::std::allocator<char> >
                    // with Ss
                    //printf("xx: '%.*s'\n", (int)(buf.offset - off), buf.data + off);
                    if (buf.offset - off >= 26 && memcmp(buf.data + off, "IcSt11char_traitsIcESaIcEE".ptr, 26) == 0)
                    {
                        buf.remove(off - 2, 28);
                        buf.insert(off - 2, "Ss");
                        return;
                    }
                    buf.setsize(off);
                    source_name(se, true);
                }
                else if (s.ident == Id.basic_istream || s.ident == Id.basic_ostream || s.ident == Id.basic_iostream)
                {
                    /* Replace
                     * ::std::basic_istream<char,  std::char_traits<char> > with Si
                     * ::std::basic_ostream<char,  std::char_traits<char> > with So
                     * ::std::basic_iostream<char, std::char_traits<char> > with Sd
                     */
                    size_t off = buf.offset;
                    components_on = false; // turn off substitutions
                    source_name(se, true);
                    components_on = true;
                    //printf("xx: '%.*s'\n", (int)(buf.offset - off), buf.data + off);
                    if (buf.offset - off >= 21 && memcmp(buf.data + off, "IcSt11char_traitsIcEE".ptr, 21) == 0)
                    {
                        buf.remove(off, 21);
                        char[2] mbuf;
                        mbuf[0] = 'S';
                        mbuf[1] = 'i';
                        if (s.ident == Id.basic_ostream)
                            mbuf[1] = 'o';
                        else if (s.ident == Id.basic_iostream)
                            mbuf[1] = 'd';
                        buf.insert(off, mbuf[]);
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

    void mangle_variable(VarDeclaration d, bool is_temp_arg_ref)
    {
        // fake mangling for fields to fix https://issues.dlang.org/show_bug.cgi?id=16525
        if (!(d.storage_class & (STCextern | STCfield | STCgshared)))
        {
            d.error("Internal Compiler Error: C++ static non- __gshared non-extern variables not supported");
            fatal();
        }
        Dsymbol p = d.toParent();
        if (p && !p.isModule()) //for example: char Namespace1::beta[6] should be mangled as "_ZN10Namespace14betaE"
        {
            buf.writestring("_ZN");
            prefix_name(p);
            source_name(d);
            buf.writeByte('E');
        }
        else //char beta[6] should mangle as "beta"
        {
            if (!is_temp_arg_ref)
            {
                buf.writestring(d.ident.toChars());
            }
            else
            {
                buf.writestring("_Z");
                source_name(d);
            }
        }
    }

    void mangle_function(FuncDeclaration d)
    {
        //printf("mangle_function(%s)\n", d.toChars());
        /*
         * <mangled-name> ::= _Z <encoding>
         * <encoding> ::= <function name> <bare-function-type>
         *         ::= <data name>
         *         ::= <special-name>
         */
        TypeFunction tf = cast(TypeFunction)d.type;
        buf.writestring("_Z");
        Dsymbol p = d.toParent();
        TemplateDeclaration ftd = getFuncTemplateDecl(d);

        if (p && !p.isModule() && tf.linkage == LINKcpp && !ftd)
        {
            buf.writeByte('N');
            if (d.type.isConst())
                buf.writeByte('K');
            prefix_name(p);
            // See ABI 5.1.8 Compression
            // Replace ::std::allocator with Sa
            if (buf.offset >= 17 && memcmp(buf.data, "_ZN3std9allocator".ptr, 17) == 0)
            {
                buf.remove(3, 14);
                buf.insert(3, "Sa");
            }
            // Replace ::std::basic_string with Sb
            if (buf.offset >= 21 && memcmp(buf.data, "_ZN3std12basic_string".ptr, 21) == 0)
            {
                buf.remove(3, 18);
                buf.insert(3, "Sb");
            }
            // Replace ::std with St
            if (buf.offset >= 7 && memcmp(buf.data, "_ZN3std".ptr, 7) == 0)
            {
                buf.remove(3, 4);
                buf.insert(3, "St");
            }
            if (buf.offset >= 8 && memcmp(buf.data, "_ZNK3std".ptr, 8) == 0)
            {
                buf.remove(4, 4);
                buf.insert(4, "St");
            }
            if (d.isDtorDeclaration())
            {
                buf.writestring("D1");
            }
            else
            {
                source_name(d);
            }
            buf.writeByte('E');
        }
        else if (ftd)
        {
            source_name(p);
            this.is_top_level = true;
            tf.nextOf().accept(this);
            this.is_top_level = false;
        }
        else
        {
            source_name(d);
        }
        if (tf.linkage == LINKcpp) //Template args accept extern "C" symbols with special mangling
        {
            assert(tf.ty == Tfunction);
            argsCppMangle(tf.parameters, tf.varargs);
        }
    }

    void argsCppMangle(Parameters* parameters, int varargs)
    {
        int paramsCppMangleDg(size_t n, Parameter fparam)
        {
            Type t = fparam.type.merge2();
            if (fparam.storageClass & (STCout | STCref))
                t = t.referenceTo();
            else if (fparam.storageClass & STClazy)
            {
                // Mangle as delegate
                Type td = new TypeFunction(null, t, 0, LINKd);
                td = new TypeDelegate(td);
                t = merge(t);
            }
            if (t.ty == Tsarray)
            {
                // Mangle static arrays as pointers
                t.error(Loc(), "Internal Compiler Error: unable to pass static array to extern(C++) function.");
                t.error(Loc(), "Use pointer instead.");
                fatal();
                //t = t.nextOf().pointerTo();
            }
            /* If it is a basic, enum or struct type,
             * then don't mark it const
             */
            this.is_top_level = true;
            if ((t.ty == Tenum || t.ty == Tstruct || t.ty == Tpointer || t.isTypeBasic()) && t.isConst())
                t.mutableOf().accept(this);
            else
                t.accept(this);
            this.is_top_level = false;
            return 0;
        }

        if (parameters)
            Parameter._foreach(parameters, &paramsCppMangleDg);
        if (varargs)
            buf.writestring("z");
        else if (!parameters || !parameters.dim)
            buf.writeByte('v'); // encode ( ) parameters
    }

public:
    extern (D) this()
    {
        this.components_on = true;
    }

    const(char)* mangleOf(Dsymbol s)
    {
        VarDeclaration vd = s.isVarDeclaration();
        FuncDeclaration fd = s.isFuncDeclaration();
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
        Target.prefixName(&buf, LINKcpp);
        return buf.extractString();
    }

    override void visit(Type t)
    {
        if (t.isImmutable() || t.isShared())
        {
            t.error(Loc(), "Internal Compiler Error: shared or immutable types can not be mapped to C++ (%s)", t.toChars());
        }
        else
        {
            t.error(Loc(), "Internal Compiler Error: type %s can not be mapped to C++\n", t.toChars());
        }
        fatal(); //Fatal, because this error should be handled in frontend
    }

    override void visit(TypeBasic t)
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
        switch (t.ty)
        {
        case Tvoid:
            c = 'v';
            break;
        case Tint8:
            c = 'a';
            break;
        case Tuns8:
            c = 'h';
            break;
        case Tint16:
            c = 's';
            break;
        case Tuns16:
            c = 't';
            break;
        case Tint32:
            c = 'i';
            break;
        case Tuns32:
            c = 'j';
            break;
        case Tfloat32:
            c = 'f';
            break;
        case Tint64:
            c = (Target.c_longsize == 8 ? 'l' : 'x');
            break;
        case Tuns64:
            c = (Target.c_longsize == 8 ? 'm' : 'y');
            break;
        case Tint128:
            c = 'n';
            break;
        case Tuns128:
            c = 'o';
            break;
        case Tfloat64:
            c = 'd';
            break;
        case Tfloat80:
            c = 'e';
            break;
        case Tbool:
            c = 'b';
            break;
        case Tchar:
            c = 'c';
            break;
        case Twchar:
            c = 't';
            break;
            // unsigned short
        case Tdchar:
            c = 'w';
            break;
            // wchar_t (UTF-32)
        case Timaginary32:
            p = 'G';
            c = 'f';
            break;
        case Timaginary64:
            p = 'G';
            c = 'd';
            break;
        case Timaginary80:
            p = 'G';
            c = 'e';
            break;
        case Tcomplex32:
            p = 'C';
            c = 'f';
            break;
        case Tcomplex64:
            p = 'C';
            c = 'd';
            break;
        case Tcomplex80:
            p = 'C';
            c = 'e';
            break;
        default:
            visit(cast(Type)t);
            return;
        }
        if (t.isImmutable() || t.isShared())
        {
            visit(cast(Type)t);
        }
        if (p || t.isConst())
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
        if (t.isConst())
            buf.writeByte('K');

        // Handle any target-specific basic types.
        if (auto tm = Target.cppTypeMangle(t))
        {
            buf.writestring(tm);
        }
        else
        {
            if (p)
                buf.writeByte(p);
            buf.writeByte(c);
        }
    }

    override void visit(TypeVector t)
    {
        is_top_level = false;
        if (substitute(t))
            return;
        store(t);
        if (t.isImmutable() || t.isShared())
        {
            visit(cast(Type)t);
        }
        if (t.isConst())
            buf.writeByte('K');

        // Handle any target-specific vector types.
        if (auto tm = Target.cppTypeMangle(t))
        {
            buf.writestring(tm);
        }
        else
        {
            assert(t.basetype && t.basetype.ty == Tsarray);
            assert((cast(TypeSArray)t.basetype).dim);
            //buf.printf("Dv%llu_", ((TypeSArray *)t.basetype).dim.toInteger());// -- Gnu ABI v.4
            buf.writestring("U8__vector"); //-- Gnu ABI v.3
            t.basetype.nextOf().accept(this);
        }
    }

    override void visit(TypeSArray t)
    {
        is_top_level = false;
        if (!substitute(t))
            store(t);
        if (t.isImmutable() || t.isShared())
        {
            visit(cast(Type)t);
        }
        if (t.isConst())
            buf.writeByte('K');
        buf.printf("A%llu_", t.dim ? t.dim.toInteger() : 0);
        t.next.accept(this);
    }

    override void visit(TypeDArray t)
    {
        visit(cast(Type)t);
    }

    override void visit(TypeAArray t)
    {
        visit(cast(Type)t);
    }

    override void visit(TypePointer t)
    {
        is_top_level = false;
        if (substitute(t))
            return;
        if (t.isImmutable() || t.isShared())
        {
            visit(cast(Type)t);
        }
        if (t.isConst())
            buf.writeByte('K');
        buf.writeByte('P');
        t.next.accept(this);
        store(t);
    }

    override void visit(TypeReference t)
    {
        is_top_level = false;
        if (substitute(t))
            return;
        buf.writeByte('R');
        t.next.accept(this);
        store(t);
    }

    override void visit(TypeFunction t)
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
            We should use Type.equals on these, and use different
            TypeFunctions for non-static member functions, and non-static
            member functions of different classes.
         */
        if (substitute(t))
            return;
        buf.writeByte('F');
        if (t.linkage == LINKc)
            buf.writeByte('Y');
        Type tn = t.next;
        if (t.isref)
            tn = tn.referenceTo();
        tn.accept(this);
        argsCppMangle(t.parameters, t.varargs);
        buf.writeByte('E');
        store(t);
    }

    override void visit(TypeDelegate t)
    {
        visit(cast(Type)t);
    }

    override void visit(TypeStruct t)
    {
        const id = t.sym.ident;
        //printf("struct id = '%s'\n", id.toChars());
        char c;
        if (id == Id.__c_long)
            c = 'l';
        else if (id == Id.__c_ulong)
            c = 'm';
        else
            c = 0;
        if (c)
        {
            if (t.isImmutable() || t.isShared())
            {
                visit(cast(Type)t);
            }
            if (t.isConst())
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
            if (t.isConst())
                buf.writeByte('K');
            buf.writeByte(c);
            return;
        }
        is_top_level = false;
        if (substitute(t))
            return;
        if (t.isImmutable() || t.isShared())
        {
            visit(cast(Type)t);
        }
        if (t.isConst())
            buf.writeByte('K');

        // Handle any target-specific struct types.
        if (auto tm = Target.cppTypeMangle(t))
        {
            buf.writestring(tm);
        }
        else
        {
            if (!substitute(t.sym))
            {
                cpp_mangle_name(t.sym, t.isConst());
            }
            if (t.isImmutable() || t.isShared())
            {
                visit(cast(Type)t);
            }
        }
        if (t.isConst())
            store(t);
    }

    override void visit(TypeEnum t)
    {
        is_top_level = false;
        if (substitute(t))
            return;
        if (t.isConst())
            buf.writeByte('K');
        if (!substitute(t.sym))
        {
            cpp_mangle_name(t.sym, t.isConst());
        }
        if (t.isImmutable() || t.isShared())
        {
            visit(cast(Type)t);
        }
        if (t.isConst())
            store(t);
    }

    override void visit(TypeClass t)
    {
        if (substitute(t))
            return;
        if (t.isImmutable() || t.isShared())
        {
            visit(cast(Type)t);
        }
        if (t.isConst() && !is_top_level)
            buf.writeByte('K');
        is_top_level = false;
        buf.writeByte('P');
        if (t.isConst())
            buf.writeByte('K');
        if (!substitute(t.sym))
        {
            cpp_mangle_name(t.sym, t.isConst());
        }
        if (t.isConst())
            store(null);
        store(t);
    }

    final const(char)* mangle_typeinfo(Dsymbol s)
    {
        buf.writestring("_ZTI");
        cpp_mangle_name(s, false);
        return buf.extractString();
    }
}
