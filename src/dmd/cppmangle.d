/**
 * Compiler implementation of the $(LINK2 http://www.dlang.org, D programming language)
 *
 * Do mangling for C++ linkage.
 * This is the POSIX side of the implementation.
 * It exports two functions to C++, `toCppMangleItanium` and `cppTypeInfoMangleItanium`.
 *
 * Copyright: Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors: Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/cppmangle.d, _cppmangle.d)
 * Documentation:  https://dlang.org/phobos/dmd_cppmangle.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/cppmangle.d
 *
 * References:
 *  Follows Itanium C++ ABI 1.86 section 5.1
 *  http://refspecs.linux-foundation.org/cxxabi-1.86.html#mangling
 *  which is where the grammar comments come from.
 *
 * Bugs:
 *  https://issues.dlang.org/query.cgi
 *  enter `C++, mangling` as the keywords.
 */

module dmd.cppmangle;

import core.stdc.string;
import core.stdc.stdio;

import dmd.arraytypes;
import dmd.declaration;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.errors;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.mtype;
import dmd.nspace;
import dmd.root.outbuffer;
import dmd.root.rootobject;
import dmd.target;
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;


// helper to check if an identifier is a C++ operator
enum CppOperator { Cast, Assign, Eq, Index, Call, Unary, Binary, OpAssign, Unknown }
package CppOperator isCppOperator(Identifier id)
{
    __gshared const(Identifier)[] operators = null;
    if (!operators)
        operators = [Id._cast, Id.assign, Id.eq, Id.index, Id.call, Id.opUnary, Id.opBinary, Id.opOpAssign];
    foreach (i, op; operators)
    {
        if (op == id)
            return cast(CppOperator)i;
    }
    return CppOperator.Unknown;
}

///
extern(C++) const(char)* toCppMangleItanium(Dsymbol s)
{
    //printf("toCppMangleItanium(%s)\n", s.toChars());
    OutBuffer buf;
    scope CppMangleVisitor v = new CppMangleVisitor(&buf, s.loc);
    v.mangleOf(s);
    return buf.extractString();
}

///
extern(C++) const(char)* cppTypeInfoMangleItanium(Dsymbol s)
{
    //printf("cppTypeInfoMangle(%s)\n", s.toChars());
    OutBuffer buf;
    buf.writestring("_ZTI");    // "TI" means typeinfo structure
    scope CppMangleVisitor v = new CppMangleVisitor(&buf, s.loc);
    v.cpp_mangle_name(s, false);
    return buf.extractString();
}

/******************************
 * Determine if sym is the 'primary' destructor, that is,
 * the most-aggregate destructor (the one that is defined as __xdtor)
 * Params:
 *      sym = Dsymbol
 * Returns:
 *      true if sym is the primary destructor for an aggregate
 */
bool isPrimaryDtor(const Dsymbol sym)
{
    const dtor = sym.isDtorDeclaration();
    if (!dtor)
        return false;
    const ad = dtor.isMember();
    assert(ad);
    return dtor == ad.primaryDtor;
}

private final class CppMangleVisitor : Visitor
{
    Objects components;         // array of components available for substitution
    OutBuffer* buf;             // append the mangling to buf[]
    Loc loc;                    // location for use in error messages

    /**
     * Constructor
     *
     * Params:
     *   buf = `OutBuffer` to write the mangling to
     *   loc = `Loc` of the symbol being mangled
     */
    this(OutBuffer* buf, Loc loc)
    {
        this.buf = buf;
        this.loc = loc;
    }

    /*****
     * Entry point. Append mangling to buf[]
     * Params:
     *  s = symbol to mangle
     */
    void mangleOf(Dsymbol s)
    {
        if (VarDeclaration vd = s.isVarDeclaration())
        {
            mangle_variable(vd, false);
        }
        else if (FuncDeclaration fd = s.isFuncDeclaration())
        {
            mangle_function(fd);
        }
        else
        {
            assert(0);
        }
    }

    /**
     * Write a seq-id from an index number, excluding the terminating '_'
     *
     * Params:
     *   idx = the index in a substitution list.
     *         Note that index 0 has no value, and `S0_` would be the
     *         substitution at index 1 in the list.
     *
     * See-Also:
     *  https://itanium-cxx-abi.github.io/cxx-abi/abi.html#mangle.seq-id
     */
    private void writeSequenceFromIndex(size_t idx)
    {
        if (idx)
        {
            void write_seq_id(size_t i)
            {
                if (i >= 36)
                {
                    write_seq_id(i / 36);
                    i %= 36;
                }
                i += (i < 10) ? '0' : 'A' - 10;
                buf.writeByte(cast(char)i);
            }

            write_seq_id(idx - 1);
        }
    }

    bool substitute(RootObject p)
    {
        //printf("substitute %s\n", p ? p.toChars() : null);
        auto i = find(p);
        if (i >= 0)
        {
            //printf("\tmatch\n");
            /* Sequence is S_, S0_, .., S9_, SA_, ..., SZ_, S10_, ...
             */
            buf.writeByte('S');
            writeSequenceFromIndex(i);
            buf.writeByte('_');
            return true;
        }
        return false;
    }

    /******
     * See if `p` exists in components[]
     *
     * Note that components can contain `null` entries,
     * as the index used in mangling is based on the index in the array.
     *
     * If called with an object whose dynamic type is `Nspace`,
     * calls the `find(Nspace)` overload.
     *
     * Returns:
     *  index if found, -1 if not
     */
    int find(RootObject p)
    {
        //printf("find %p %d %s\n", p, p.dyncast(), p ? p.toChars() : null);
        scope v = new ComponentVisitor(p);
        foreach (i, component; components)
        {
            if (component)
                component.visitObject(v);
            if (v.result)
                return cast(int)i;
        }
        return -1;
    }

    /*********************
     * Append p to components[]
     */
    void append(RootObject p)
    {
        //printf("append %p %d %s\n", p, p.dyncast(), p ? p.toChars() : "null");
        components.push(p);
    }

    /**
     * Write an identifier preceded by its length
     *
     * Params:
     *   ident = `Identifier` to write to `this.buf`
     */
    void writeIdentifier(const ref Identifier ident)
    {
        const name = ident.toString();
        this.buf.print(name.length);
        this.buf.writestring(name);
    }

    /************************
     * Determine if symbol is indeed the global ::std namespace.
     * Params:
     *  s = symbol to check
     * Returns:
     *  true if it is ::std
     */
    static bool isStd(Dsymbol s)
    {
        return (s &&
                s.ident == Id.std &&    // the right name
                s.isNspace() &&         // g++ disallows global "std" for other than a namespace
                !getQualifier(s));      // at global level
    }

    /******************************
     * Write the mangled representation of a template argument.
     * Params:
     *  ti  = the template instance
     *  arg = the template argument index
     */
    void template_arg(TemplateInstance ti, size_t arg)
    {
        TemplateDeclaration td = ti.tempdecl.isTemplateDeclaration();
        assert(td);
        TemplateParameter tp = (*td.parameters)[arg];
        RootObject o = (*ti.tiargs)[arg];

        if (tp.isTemplateTypeParameter())
        {
            Type t = isType(o);
            assert(t);
            t.accept(this);
        }
        else if (TemplateValueParameter tv = tp.isTemplateValueParameter())
        {
            // <expr-primary> ::= L <type> <value number> E  # integer literal
            if (tv.valType.isintegral())
            {
                Expression e = isExpression(o);
                assert(e);
                buf.writeByte('L');
                tv.valType.accept(this);
                auto val = e.toUInteger();
                if (!tv.valType.isunsigned() && cast(sinteger_t)val < 0)
                {
                    val = -val;
                    buf.writeByte('n');
                }
                buf.print(val);
                buf.writeByte('E');
            }
            else
            {
                ti.error("Internal Compiler Error: C++ `%s` template value parameter is not supported", tv.valType.toChars());
                fatal();
            }
        }
        else if (tp.isTemplateAliasParameter())
        {
            Dsymbol d = isDsymbol(o);
            Expression e = isExpression(o);
            if (d && d.isFuncDeclaration())
            {
                bool is_nested = d.toParent() &&
                    !d.toParent().isModule() &&
                    (cast(TypeFunction)d.isFuncDeclaration().type).linkage == LINK.cpp;
                if (is_nested)
                    buf.writeByte('X');
                buf.writeByte('L');
                mangle_function(d.isFuncDeclaration());
                buf.writeByte('E');
                if (is_nested)
                    buf.writeByte('E');
            }
            else if (e && e.op == TOK.variable && (cast(VarExp)e).var.isVarDeclaration())
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
                ti.error("Internal Compiler Error: C++ `%s` template alias parameter is not supported", o.toChars());
                fatal();
            }
        }
        else if (tp.isTemplateThisParameter())
        {
            ti.error("Internal Compiler Error: C++ `%s` template this parameter is not supported", o.toChars());
            fatal();
        }
        else
        {
            assert(0);
        }
    }

    /******************************
     * Write the mangled representation of the template arguments.
     * Params:
     *  ti = the template instance
     *  firstArg = index of the first template argument to mangle
     *             (used for operator overloading)
     * Returns:
     *  true if any arguments were written
     */
    bool template_args(TemplateInstance ti, int firstArg = 0)
    {
        /* <template-args> ::= I <template-arg>+ E
         */
        if (!ti || ti.tiargs.dim <= firstArg)   // could happen if std::basic_string is not a template
            return false;
        buf.writeByte('I');
        foreach (i; firstArg .. ti.tiargs.dim)
        {
            TemplateDeclaration td = ti.tempdecl.isTemplateDeclaration();
            assert(td);
            TemplateParameter tp = (*td.parameters)[i];

            /*
             * <template-arg> ::= <type>               # type or template
             *                ::= X <expression> E     # expression
             *                ::= <expr-primary>       # simple expressions
             *                ::= I <template-arg>* E  # argument pack
             */
            if (TemplateTupleParameter tt = tp.isTemplateTupleParameter())
            {
                buf.writeByte('I');     // argument pack

                // mangle the rest of the arguments as types
                foreach (j; i .. (*ti.tiargs).dim)
                {
                    Type t = isType((*ti.tiargs)[j]);
                    assert(t);
                    t.accept(this);
                }

                buf.writeByte('E');
                break;
            }

            template_arg(ti, i);
        }
        buf.writeByte('E');
        return true;
    }


    void source_name(Dsymbol s)
    {
        //printf("source_name(%s)\n", s.toChars());
        if (TemplateInstance ti = s.isTemplateInstance())
        {
            if (!substitute(ti.tempdecl))
            {
                append(ti.tempdecl);
                this.writeIdentifier(ti.tempdecl.toAlias().ident);
            }
            template_args(ti);
        }
        else
            this.writeIdentifier(s.ident);
    }

    /********
     * See if s is actually an instance of a template
     * Params:
     *  s = symbol
     * Returns:
     *  if s is instance of a template, return the instance, otherwise return s
     */
    Dsymbol getInstance(Dsymbol s)
    {
        Dsymbol p = s.toParent();
        if (p)
        {
            if (TemplateInstance ti = p.isTemplateInstance())
                return ti;
        }
        return s;
    }

    /********
     * Get qualifier for `s`, meaning the symbol
     * that s is in the symbol table of.
     * The module does not count as a qualifier, because C++
     * does not have modules.
     * Params:
     *  s = symbol that may have a qualifier
     *      s is rewritten to be TemplateInstance if s is one
     * Returns:
     *  qualifier, null if none
     */
    static Dsymbol getQualifier(Dsymbol s)
    {
        Dsymbol p = s.toParent();
        return (p && !p.isModule()) ? p : null;
    }

    // Detect type char
    static bool isChar(RootObject o)
    {
        Type t = isType(o);
        return (t && t.equals(Type.tchar));
    }

    // Detect type ::std::char_traits<char>
    static bool isChar_traits_char(RootObject o)
    {
        return isIdent_char(Id.char_traits, o);
    }

    // Detect type ::std::allocator<char>
    static bool isAllocator_char(RootObject o)
    {
        return isIdent_char(Id.allocator, o);
    }

    // Detect type ::std::ident<char>
    static bool isIdent_char(Identifier ident, RootObject o)
    {
        Type t = isType(o);
        if (!t || t.ty != Tstruct)
            return false;
        Dsymbol s = (cast(TypeStruct)t).toDsymbol(null);
        if (s.ident != ident)
            return false;
        Dsymbol p = s.toParent();
        if (!p)
            return false;
        TemplateInstance ti = p.isTemplateInstance();
        if (!ti)
            return false;
        Dsymbol q = getQualifier(ti);
        return isStd(q) && ti.tiargs.dim == 1 && isChar((*ti.tiargs)[0]);
    }

    /***
     * Detect template args <char, ::std::char_traits<char>>
     * and write st if found.
     * Returns:
     *  true if found
     */
    bool char_std_char_traits_char(TemplateInstance ti, string st)
    {
        if (ti.tiargs.dim == 2 &&
            isChar((*ti.tiargs)[0]) &&
            isChar_traits_char((*ti.tiargs)[1]))
        {
            buf.writestring(st.ptr);
            return true;
        }
        return false;
    }


    void prefix_name(Dsymbol s)
    {
        //printf("prefix_name(%s)\n", s.toChars());
        if (substitute(s))
            return;

        auto si = getInstance(s);
        Dsymbol p = getQualifier(si);
        if (p)
        {
            if (isStd(p))
            {
                bool needsTa;
                auto ti = si.isTemplateInstance();
                if (this.writeStdSubstitution(ti, needsTa))
                {
                    if (needsTa)
                    {
                        template_args(ti);
                        append(ti);
                    }
                    return;
                }
                buf.writestring("St");
            }
            else
                prefix_name(p);
        }
        source_name(si);
        if (!isStd(si))
            /* Do this after the source_name() call to keep components[]
             * in the right order.
             * https://issues.dlang.org/show_bug.cgi?id=17947
             */
            append(si);
    }

    /**
     * Write common substitution for standard types, such as std::allocator
     *
     * This function assumes that the symbol `ti` is in the namespace `std`.
     *
     * Params:
     *   ti = Template instance to consider
     *   needsTa = If this function returns `true`, this value indicates
     *             if additional template argument mangling is needed
     *
     * Returns:
     *   `true` if a special std symbol was found
     */
    bool writeStdSubstitution(TemplateInstance ti, out bool needsTa)
    {
        if (!ti)
            return false;

        if (ti.name == Id.allocator)
        {
            buf.writestring("Sa");
            needsTa = true;
            return true;
        }
        if (ti.name == Id.basic_string)
        {
            // ::std::basic_string<char, ::std::char_traits<char>, ::std::allocator<char>>
            if (ti.tiargs.dim == 3 &&
                isChar((*ti.tiargs)[0]) &&
                isChar_traits_char((*ti.tiargs)[1]) &&
                isAllocator_char((*ti.tiargs)[2]))

            {
                buf.writestring("Ss");
                return true;
            }
            buf.writestring("Sb");      // ::std::basic_string
            needsTa = true;
            return true;
        }

        // ::std::basic_istream<char, ::std::char_traits<char>>
        if (ti.name == Id.basic_istream &&
            char_std_char_traits_char(ti, "Si"))
            return true;

        // ::std::basic_ostream<char, ::std::char_traits<char>>
        if (ti.name == Id.basic_ostream &&
            char_std_char_traits_char(ti, "So"))
            return true;

        // ::std::basic_iostream<char, ::std::char_traits<char>>
        if (ti.name == Id.basic_iostream &&
            char_std_char_traits_char(ti, "Sd"))
            return true;

        return false;
    }


    void cpp_mangle_name(Dsymbol s, bool qualified)
    {
        //printf("cpp_mangle_name(%s, %d)\n", s.toChars(), qualified);
        Dsymbol p = s.toParent();
        Dsymbol se = s;
        bool write_prefix = true;
        if (p && p.isTemplateInstance())
        {
            se = p;
            if (find(p.isTemplateInstance().tempdecl) >= 0)
                write_prefix = false;
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
            if (isStd(p) && !qualified)
            {
                TemplateInstance ti = se.isTemplateInstance();
                if (s.ident == Id.allocator)
                {
                    buf.writestring("Sa"); // "Sa" is short for ::std::allocator
                    template_args(ti);
                }
                else if (s.ident == Id.basic_string)
                {
                    // ::std::basic_string<char, ::std::char_traits<char>, ::std::allocator<char>>
                    if (ti.tiargs.dim == 3 &&
                        isChar((*ti.tiargs)[0]) &&
                        isChar_traits_char((*ti.tiargs)[1]) &&
                        isAllocator_char((*ti.tiargs)[2]))

                    {
                        buf.writestring("Ss");
                        return;
                    }
                    buf.writestring("Sb");      // ::std::basic_string
                    template_args(ti);
                }
                else
                {
                    // ::std::basic_istream<char, ::std::char_traits<char>>
                    if (s.ident == Id.basic_istream)
                    {
                        if (char_std_char_traits_char(ti, "Si"))
                            return;
                    }
                    else if (s.ident == Id.basic_ostream)
                    {
                        if (char_std_char_traits_char(ti, "So"))
                            return;
                    }
                    else if (s.ident == Id.basic_iostream)
                    {
                        if (char_std_char_traits_char(ti, "Sd"))
                            return;
                    }
                    buf.writestring("St");
                    source_name(se);
                }
            }
            else
            {
                buf.writeByte('N');
                if (write_prefix)
                {
                    if (isStd(p))
                        buf.writestring("St");
                    else
                        prefix_name(p);
                }
                source_name(se);
                buf.writeByte('E');
            }
        }
        else
            source_name(se);
        append(s);
    }

    void CV_qualifiers(Type t)
    {
        // CV-qualifiers are 'r': restrict, 'V': volatile, 'K': const
        if (t.isConst())
            buf.writeByte('K');
    }

    void mangle_variable(VarDeclaration d, bool is_temp_arg_ref)
    {
        // fake mangling for fields to fix https://issues.dlang.org/show_bug.cgi?id=16525
        if (!(d.storage_class & (STC.extern_ | STC.field | STC.gshared)))
        {
            d.error("Internal Compiler Error: C++ static non-`__gshared` non-`extern` variables not supported");
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
         *            ::= <data name>
         *            ::= <special-name>
         */
        TypeFunction tf = cast(TypeFunction)d.type;
        buf.writestring("_Z");

        if (TemplateDeclaration ftd = getFuncTemplateDecl(d))
        {
            /* It's an instance of a function template
             */
            TemplateInstance ti = d.parent.isTemplateInstance();
            assert(ti);
            this.mangleTemplatedFunction(d, tf, ftd, ti);
        }
        else
        {
            Dsymbol p = d.toParent();
            if (p && !p.isModule() && tf.linkage == LINK.cpp)
            {
                this.mangleNestedFuncPrefix(tf, p);

                if (d.isCtorDeclaration())
                    buf.writestring("C1");
                else if (d.isPrimaryDtor())
                    buf.writestring("D1");
                else if (d.ident && d.ident == Id.assign)
                    buf.writestring("aS");
                else if (d.ident && d.ident == Id.eq)
                    buf.writestring("eq");
                else if (d.ident && d.ident == Id.index)
                    buf.writestring("ix");
                else if (d.ident && d.ident == Id.call)
                    buf.writestring("cl");
                else
                    source_name(d);
                buf.writeByte('E');
            }
            else
            {
                source_name(d);
            }
        }

        if (tf.linkage == LINK.cpp) //Template args accept extern "C" symbols with special mangling
        {
            assert(tf.ty == Tfunction);
            mangleFunctionParameters(tf.parameters, tf.varargs);
        }
    }

    /**
     * Mangles a function template to C++
     *
     * Params:
     *   d = Function declaration
     *   tf = Function type (casted d.type)
     *   ftd = Template declaration (ti.templdecl)
     *   ti = Template instance (d.parent)
     */
    void mangleTemplatedFunction(FuncDeclaration d, TypeFunction tf,
                                 TemplateDeclaration ftd, TemplateInstance ti)
    {
        Dsymbol p = ti.toParent();
        // Check if this function is *not* nested
        if (!p || p.isModule() || tf.linkage != LINK.cpp)
        {
            source_name(ti);
            headOfType(tf.nextOf());  // mangle return type
            return;
        }

        // It's a nested function (e.g. a member of an aggregate)
        this.mangleNestedFuncPrefix(tf, p);

        if (d.isCtorDeclaration())
        {
            buf.writestring("C1");
        }
        else if (d.isPrimaryDtor())
        {
            buf.writestring("D1");
        }
        else
        {
            int firstTemplateArg = 0;
            bool appendReturnType = true;
            bool isConvertFunc = false;
            string symName;

            // test for special symbols
            CppOperator whichOp = isCppOperator(ti.name);
            final switch (whichOp)
            {
            case CppOperator.Unknown:
                break;
            case CppOperator.Cast:
                symName = "cv";
                firstTemplateArg = 1;
                isConvertFunc = true;
                appendReturnType = false;
                break;
            case CppOperator.Assign:
                symName = "aS";
                break;
            case CppOperator.Eq:
                symName = "eq";
                break;
            case CppOperator.Index:
                symName = "ix";
                break;
            case CppOperator.Call:
                symName = "cl";
                break;
            case CppOperator.Unary:
            case CppOperator.Binary:
            case CppOperator.OpAssign:
                TemplateDeclaration td = ti.tempdecl.isTemplateDeclaration();
                assert(td);
                assert(ti.tiargs.dim >= 1);
                TemplateParameter tp = (*td.parameters)[0];
                TemplateValueParameter tv = tp.isTemplateValueParameter();
                if (!tv || !tv.valType.isString())
                    break; // expecting a string argument to operators!
                Expression exp = (*ti.tiargs)[0].isExpression();
                StringExp str = exp.toStringExp();
                switch (whichOp)
                {
                case CppOperator.Unary:
                    switch (str.peekSlice())
                    {
                    case "*":   symName = "de"; goto continue_template;
                    case "++":  symName = "pp"; goto continue_template;
                    case "--":  symName = "mm"; goto continue_template;
                    case "-":   symName = "ng"; goto continue_template;
                    case "+":   symName = "ps"; goto continue_template;
                    case "~":   symName = "co"; goto continue_template;
                    default:    break;
                    }
                    break;
                case CppOperator.Binary:
                    switch (str.peekSlice())
                    {
                    case ">>":  symName = "rs"; goto continue_template;
                    case "<<":  symName = "ls"; goto continue_template;
                    case "*":   symName = "ml"; goto continue_template;
                    case "-":   symName = "mi"; goto continue_template;
                    case "+":   symName = "pl"; goto continue_template;
                    case "&":   symName = "an"; goto continue_template;
                    case "/":   symName = "dv"; goto continue_template;
                    case "%":   symName = "rm"; goto continue_template;
                    case "^":   symName = "eo"; goto continue_template;
                    case "|":   symName = "or"; goto continue_template;
                    default:    break;
                    }
                    break;
                case CppOperator.OpAssign:
                    switch (str.peekSlice())
                    {
                    case "*":   symName = "mL"; goto continue_template;
                    case "+":   symName = "pL"; goto continue_template;
                    case "-":   symName = "mI"; goto continue_template;
                    case "/":   symName = "dV"; goto continue_template;
                    case "%":   symName = "rM"; goto continue_template;
                    case ">>":  symName = "rS"; goto continue_template;
                    case "<<":  symName = "lS"; goto continue_template;
                    case "&":   symName = "aN"; goto continue_template;
                    case "|":   symName = "oR"; goto continue_template;
                    case "^":   symName = "eO"; goto continue_template;
                    default:    break;
                    }
                    break;
                default:
                    assert(0);
                continue_template:
                    firstTemplateArg = 1;
                    break;
                }
                break;
            }
            if (symName.length == 0)
                source_name(ti);
            else
            {
                buf.writestring(symName);
                if (isConvertFunc)
                    template_arg(ti, 0);
                appendReturnType = template_args(ti, firstTemplateArg) && appendReturnType;
            }
            buf.writeByte('E');
            if (appendReturnType)
                headOfType(tf.nextOf());  // mangle return type
        }
    }


    void mangleFunctionParameters(Parameters* parameters, int varargs)
    {
        int numparams = 0;

        int paramsCppMangleDg(size_t n, Parameter fparam)
        {
            Type t = Target.cppParameterType(fparam);
            if (t.ty == Tsarray)
            {
                // Static arrays in D are passed by value; no counterpart in C++
                .error(loc, "Internal Compiler Error: unable to pass static array `%s` to extern(C++) function, use pointer instead",
                    t.toChars());
                fatal();
            }
            headOfType(t);
            ++numparams;
            return 0;
        }

        if (parameters)
            Parameter._foreach(parameters, &paramsCppMangleDg);
        if (varargs)
            buf.writeByte('z');
        else if (!numparams)
            buf.writeByte('v'); // encode (void) parameters
    }

    /****** The rest is type mangling ************/

    void error(Type t)
    {
        const(char)* p;
        if (t.isImmutable())
            p = "`immutable` ";
        else if (t.isShared())
            p = "`shared` ";
        else
            p = "";
        .error(loc, "Internal Compiler Error: %stype `%s` can not be mapped to C++\n", p, t.toChars());
        fatal(); //Fatal, because this error should be handled in frontend
    }

    /****************************
     * Mangle a type,
     * treating it as a Head followed by a Tail.
     * Params:
     *  t = Head of a type
     */
    void headOfType(Type t)
    {
        if (t.ty == Tclass)
        {
            mangleTypeClass(cast(TypeClass)t, true);
        }
        else
        {
            // For value types, strip const/immutable/shared from the head of the type
            t.mutableOf().unSharedOf().accept(this);
        }
    }

    /******
     * Write out 1 or 2 character basic type mangling.
     * Handle const and substitutions.
     * Params:
     *  t = type to mangle
     *  p = if not 0, then character prefix
     *  c = mangling character
     */
    void writeBasicType(Type t, char p, char c)
    {
        if (p || t.isConst())
        {
            if (substitute(t))
                return;
            else
                append(t);
        }
        CV_qualifiers(t);
        if (p)
            buf.writeByte(p);
        buf.writeByte(c);
    }


    /****************
     * Write structs and enums.
     * Params:
     *  t = TypeStruct or TypeEnum
     */
    void doSymbol(Type t)
    {
        if (substitute(t))
            return;
        CV_qualifiers(t);

        // Handle any target-specific struct types.
        if (auto tm = Target.cppTypeMangle(t))
        {
            buf.writestring(tm);
        }
        else
        {
            Dsymbol s = t.toDsymbol(null);
            Dsymbol p = s.toParent();
            if (p && p.isTemplateInstance())
            {
                 /* https://issues.dlang.org/show_bug.cgi?id=17947
                  * Substitute the template instance symbol, not the struct/enum symbol
                  */
                if (substitute(p))
                    return;
            }
            if (!substitute(s))
            {
                cpp_mangle_name(s, false);
            }
        }
        if (t.isConst())
            append(t);
    }



    /************************
     * Mangle a class type.
     * If it's the head, treat the initial pointer as a value type.
     * Params:
     *  t = class type
     *  head = true for head of a type
     */
    void mangleTypeClass(TypeClass t, bool head)
    {
        if (t.isImmutable() || t.isShared())
            return error(t);

        /* Mangle as a <pointer to><struct>
         */
        if (substitute(t))
            return;
        if (!head)
            CV_qualifiers(t);
        buf.writeByte('P');

        CV_qualifiers(t);

        {
            Dsymbol s = t.toDsymbol(null);
            Dsymbol p = s.toParent();
            if (p && p.isTemplateInstance())
            {
                 /* https://issues.dlang.org/show_bug.cgi?id=17947
                  * Substitute the template instance symbol, not the class symbol
                  */
                if (substitute(p))
                    return;
            }
        }

        if (!substitute(t.sym))
        {
            cpp_mangle_name(t.sym, false);
        }
        if (t.isConst())
            append(null);  // C++ would have an extra type here
        append(t);
    }

    /**
     * Mangle the prefix of a nested (e.g. member) function
     *
     * Params:
     *   tf = Type of the nested function
     *   parent = Parent in which the function is nested
     */
    void mangleNestedFuncPrefix(TypeFunction tf, Dsymbol parent)
    {
        /* <nested-name> ::= N [<CV-qualifiers>] <prefix> <unqualified-name> E
         *               ::= N [<CV-qualifiers>] <template-prefix> <template-args> E
         */
        buf.writeByte('N');
        CV_qualifiers(tf);

        /* <prefix> ::= <prefix> <unqualified-name>
         *          ::= <template-prefix> <template-args>
         *          ::= <template-param>
         *          ::= # empty
         *          ::= <substitution>
         *          ::= <prefix> <data-member-prefix>
         */
        prefix_name(parent);
    }

extern(C++):

    alias visit = Visitor.visit;

    override void visit(Type t)
    {
        error(t);
    }

    override void visit(TypeNull t)
    {
        if (t.isImmutable() || t.isShared())
            return error(t);

        writeBasicType(t, 'D', 'n');
    }

    override void visit(TypeBasic t)
    {
        if (t.isImmutable() || t.isShared())
            return error(t);

        /* <builtin-type>:
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
         * Dd       64 bit IEEE 754r decimal floating point
         * De       128 bit IEEE 754r decimal floating point
         * Df       32 bit IEEE 754r decimal floating point
         * Dh       16 bit IEEE 754r half-precision floating point
         * Di       char32_t
         * Ds       char16_t
         * u <source-name>  # vendor extended type
         */
        char c;
        char p = 0;
        switch (t.ty)
        {
            case Tvoid:                 c = 'v';        break;
            case Tint8:                 c = 'a';        break;
            case Tuns8:                 c = 'h';        break;
            case Tint16:                c = 's';        break;
            case Tuns16:                c = 't';        break;
            case Tint32:                c = 'i';        break;
            case Tuns32:                c = 'j';        break;
            case Tfloat32:              c = 'f';        break;
            case Tint64:
                c = Target.c_longsize == 8 ? 'l' : 'x';
                break;
            case Tuns64:
                c = Target.c_longsize == 8 ? 'm' : 'y';
                break;
            case Tint128:                c = 'n';       break;
            case Tuns128:                c = 'o';       break;
            case Tfloat64:               c = 'd';       break;
            case Tfloat80:               c = 'e';       break;
            case Tbool:                  c = 'b';       break;
            case Tchar:                  c = 'c';       break;
            case Twchar:                 c = 't';       break;  // unsigned short (perhaps use 'Ds' ?
            case Tdchar:                 c = 'w';       break;  // wchar_t (UTF-32) (perhaps use 'Di' ?
            case Timaginary32:  p = 'G'; c = 'f';       break;  // 'G' means imaginary
            case Timaginary64:  p = 'G'; c = 'd';       break;
            case Timaginary80:  p = 'G'; c = 'e';       break;
            case Tcomplex32:    p = 'C'; c = 'f';       break;  // 'C' means complex
            case Tcomplex64:    p = 'C'; c = 'd';       break;
            case Tcomplex80:    p = 'C'; c = 'e';       break;

            default:
                // Handle any target-specific basic types.
                if (auto tm = Target.cppTypeMangle(t))
                {
                    if (substitute(t))
                        return;
                    else
                        append(t);
                    CV_qualifiers(t);
                    buf.writestring(tm);
                    return;
                }
                return error(t);
        }
        writeBasicType(t, p, c);
    }

    override void visit(TypeVector t)
    {
        if (t.isImmutable() || t.isShared())
            return error(t);

        if (substitute(t))
            return;
        append(t);
        CV_qualifiers(t);

        // Handle any target-specific vector types.
        if (auto tm = Target.cppTypeMangle(t))
        {
            buf.writestring(tm);
        }
        else
        {
            assert(t.basetype && t.basetype.ty == Tsarray);
            assert((cast(TypeSArray)t.basetype).dim);
            version (none)
            {
                buf.writestring("Dv");
                buf.print((cast(TypeSArray *)t.basetype).dim.toInteger()); // -- Gnu ABI v.4
                buf.writeByte('_');
            }
            else
                buf.writestring("U8__vector"); //-- Gnu ABI v.3
            t.basetype.nextOf().accept(this);
        }
    }

    override void visit(TypeSArray t)
    {
        if (t.isImmutable() || t.isShared())
            return error(t);

        if (!substitute(t))
            append(t);
        CV_qualifiers(t);
        buf.writeByte('A');
        buf.print(t.dim ? t.dim.toInteger() : 0);
        buf.writeByte('_');
        t.next.accept(this);
    }

    override void visit(TypePointer t)
    {
        if (t.isImmutable() || t.isShared())
            return error(t);

        if (substitute(t))
            return;
        CV_qualifiers(t);
        buf.writeByte('P');
        t.next.accept(this);
        append(t);
    }

    override void visit(TypeReference t)
    {
        //printf("TypeReference %s\n", t.toChars());
        if (substitute(t))
            return;
        buf.writeByte('R');
        t.next.accept(this);
        append(t);
    }

    override void visit(TypeFunction t)
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
            We should use Type.equals on these, and use different
            TypeFunctions for non-static member functions, and non-static
            member functions of different classes.
         */
        if (substitute(t))
            return;
        buf.writeByte('F');
        if (t.linkage == LINK.c)
            buf.writeByte('Y');
        Type tn = t.next;
        if (t.isref)
            tn = tn.referenceTo();
        tn.accept(this);
        mangleFunctionParameters(t.parameters, t.varargs);
        buf.writeByte('E');
        append(t);
    }

    override void visit(TypeStruct t)
    {
        if (t.isImmutable() || t.isShared())
            return error(t);

        /* __c_long and __c_ulong get special mangling
         */
        const id = t.sym.ident;
        //printf("struct id = '%s'\n", id.toChars());
        if (id == Id.__c_long)
            return writeBasicType(t, 0, 'l');
        else if (id == Id.__c_ulong)
            return writeBasicType(t, 0, 'm');

        //printf("TypeStruct %s\n", t.toChars());
        doSymbol(t);
    }

    override void visit(TypeEnum t)
    {
        if (t.isImmutable() || t.isShared())
            return error(t);

        /* __c_(u)long(long) get special mangling
         */
        const id = t.sym.ident;
        //printf("enum id = '%s'\n", id.toChars());
        if (id == Id.__c_long)
            return writeBasicType(t, 0, 'l');
        else if (id == Id.__c_ulong)
            return writeBasicType(t, 0, 'm');
        else if (id == Id.__c_longlong)
            return writeBasicType(t, 0, 'x');
        else if (id == Id.__c_ulonglong)
            return writeBasicType(t, 0, 'y');

        doSymbol(t);
    }

    override void visit(TypeClass t)
    {
        mangleTypeClass(t, false);
    }
}

/// Helper code to visit `RootObject`, as it doesn't define `accept`,
/// only its direct subtypes do.
private void visitObject (V : Visitor) (RootObject o, V this_)
{
    assert(o !is null);
    if (Type ta = isType(o))
        ta.accept(this_);
    else if (Expression ea = isExpression(o))
        ea.accept(this_);
    else if (Dsymbol sa = isDsymbol(o))
        sa.accept(this_);
    else if (TemplateParameter t = isTemplateParameter(o))
        t.accept(this_);
    else if (Tuple t = isTuple(o))
        this_.visit(t);
    else {
        assert(0, o.toString());
    }
}

/// Helper class to compare entries in components
private extern(C++) final class ComponentVisitor : Visitor
{
    /// Only one of the following is not `null`, it's always
    /// the most specialized type, set from the ctor
    private Nspace namespace;

    /// Least specialized type
    private RootObject object;

    /// Set to the result of the comparison
    private bool result;

    public this(RootObject base)
    {
        switch (base.dyncast())
        {
        case DYNCAST.dsymbol:
            if (auto ns = (cast(Dsymbol)base).isNspace())
                this.namespace = ns;
            else
                goto default;
            break;

        default:
            this.object = base;
        }
    }

    /// Introduce base class overloads
    alias visit = Visitor.visit;

    /// Least specialized overload of each direct child of `RootObject`
    public override void visit(Dsymbol o)
    {
        this.result = this.object && this.object == o;
    }

    /// Ditto
    public override void visit(Expression o)
    {
        this.result = this.object && this.object == o;
    }

    /// Ditto
    public void visit(Tuple o)
    {
        this.result = this.object && this.object == o;
    }

    /// Ditto
    public override void visit(Type o)
    {
        this.result = this.object && this.object == o;
    }

    /// Ditto
    public override void visit(TemplateParameter o)
    {
        this.result = this.object && this.object == o;
    }

    /**
     * Overload which accepts a Namespace
     *
     * It is very common for large C++ projects to have multiple files sharing
     * the same `namespace`. If any D project adopts the same approach
     * (e.g. separating data structures from functions), it will lead to two
     * `Nspace` objects being instantiated, with different addresses.
     * At the same time, we cannot compare just any Dsymbol via identifier,
     * because it messes with templates.
     *
     * See_Also:
     *  https://issues.dlang.org/show_bug.cgi?id=18922
     *
     * Params:
     *   ns = C++ namespace to do substitution for
     *
     * Returns:
     *  Index of the entry, if found, or `-1` otherwise
     */
    public override void visit(Nspace ns)
    {
        this.result = this.namespace && this.namespace.equals(ns);
    }
}
