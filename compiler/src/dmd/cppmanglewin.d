/**
 * Do mangling for C++ linkage for Digital Mars C++ and Microsoft Visual C++.
 *
 * Copyright: Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors: Walter Bright, https://www.digitalmars.com
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/cppmanglewin.d, _cppmanglewin.d)
 * Documentation:  https://dlang.org/phobos/dmd_cppmanglewin.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/cppmanglewin.d
 */

module dmd.cppmanglewin;

import core.stdc.stdio;

import dmd.arraytypes;
import dmd.astenums;
import dmd.cppmangle : isAggregateDtor, isCppOperator, CppOperator;
import dmd.dclass;
import dmd.declaration;
import dmd.denum : isSpecialEnumIdent;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.errors;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.location;
import dmd.mtype;
import dmd.common.outbuffer;
import dmd.rootobject;
import dmd.target;
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;

extern (C++):


const(char)* toCppMangleMSVC(Dsymbol s)
{
    scope VisualCPPMangler v = new VisualCPPMangler(false, s.loc);
    return v.mangleOf(s);
}

const(char)* cppTypeInfoMangleMSVC(Dsymbol s) @safe
{
    //printf("cppTypeInfoMangle(%s)\n", s.toChars());
    assert(0);
}

const(char)* toCppMangleDMC(Dsymbol s)
{
    scope VisualCPPMangler v = new VisualCPPMangler(true, s.loc);
    return v.mangleOf(s);
}

const(char)* cppTypeInfoMangleDMC(Dsymbol s) @safe
{
    //printf("cppTypeInfoMangle(%s)\n", s.toChars());
    assert(0);
}

/**
 * Issues an ICE and returns true if `type` is shared or immutable
 *
 * Params:
 *      type = type to check
 *
 * Returns:
 *      true if type is shared or immutable
 *      false otherwise
 */
private extern (D) bool checkImmutableShared(Type type, Loc loc)
{
    if (type.isImmutable() || type.isShared())
    {
        error(loc, "internal compiler error: `shared` or `immutable` types cannot be mapped to C++ (%s)", type.toChars());
        fatal();
        return true;
    }
    return false;
}

private final class VisualCPPMangler : Visitor
{
    alias visit = Visitor.visit;
    Identifier[10] saved_idents;
    Type[10] saved_types;
    Loc loc;               /// location for use in error messages

    bool isNotTopType;     /** When mangling one argument, we can call visit several times (for base types of arg type)
                            * but must save only arg type:
                            * For example: if we have an int** argument, we should save "int**" but visit will be called for "int**", "int*", "int"
                            * This flag is set up by the visit(NextType, ) function  and should be reset when the arg type output is finished.
                            */
    bool ignoreConst;      /// in some cases we should ignore CV-modifiers.
    bool escape;           /// toplevel const non-pointer types need a '$$C' escape in addition to a cv qualifier.
    bool mangleReturnType; /// return type shouldn't be saved and substituted in arguments
    bool isDmc;            /// Digital Mars C++ name mangling

    OutBuffer buf;

    extern (D) this(VisualCPPMangler rvl) scope @safe
    {
        saved_idents[] = rvl.saved_idents[];
        saved_types[]  = rvl.saved_types[];
        isDmc          = rvl.isDmc;
        loc            = rvl.loc;
    }

public:
    extern (D) this(bool isDmc, Loc loc) scope @safe
    {
        saved_idents[] = null;
        saved_types[] = null;
        this.isDmc = isDmc;
        this.loc = loc;
    }

    override void visit(Type type)
    {
        if (checkImmutableShared(type, loc))
            return;

        error(loc, "internal compiler error: type `%s` cannot be mapped to C++\n", type.toChars());
        fatal(); //Fatal, because this error should be handled in frontend
    }

    override void visit(TypeNull type)
    {
        if (checkImmutableShared(type, loc))
            return;
        if (checkTypeSaved(type))
            return;

        buf.writestring("$$T");
        isNotTopType = false;
        ignoreConst = false;
    }

    override void visit(TypeNoreturn type)
    {
        if (checkImmutableShared(type, loc))
            return;
        if (checkTypeSaved(type))
            return;

        buf.writeByte('X');             // yes, mangle it like `void`
        isNotTopType = false;
        ignoreConst = false;
    }

    override void visit(TypeBasic type)
    {
        //printf("visit(TypeBasic); is_not_top_type = %d\n", isNotTopType);
        if (checkImmutableShared(type, loc))
            return;

        if (type.isConst() && (isNotTopType || isDmc))
        {
            if (checkTypeSaved(type))
                return;
        }
        if ((type.ty == Tbool) && checkTypeSaved(type)) // try to replace long name with number
        {
            return;
        }
        if (!isDmc)
        {
            switch (type.ty)
            {
            case Tint64:
            case Tuns64:
            case Tint128:
            case Tuns128:
            case Tfloat80:
            case Twchar:
                if (checkTypeSaved(type))
                    return;
                break;

            default:
                break;
            }
        }
        mangleModifier(type);
        switch (type.ty)
        {
        case Tvoid:
            buf.writeByte('X');
            break;
        case Tint8:
            buf.writeByte('C');
            break;
        case Tuns8:
            buf.writeByte('E');
            break;
        case Tint16:
            buf.writeByte('F');
            break;
        case Tuns16:
            buf.writeByte('G');
            break;
        case Tint32:
            buf.writeByte('H');
            break;
        case Tuns32:
            buf.writeByte('I');
            break;
        case Tfloat32:
            buf.writeByte('M');
            break;
        case Tint64:
            buf.writestring("_J");
            break;
        case Tuns64:
            buf.writestring("_K");
            break;
        case Tint128:
            buf.writestring("_L");
            break;
        case Tuns128:
            buf.writestring("_M");
            break;
        case Tfloat64:
            buf.writeByte('N');
            break;
        case Tfloat80:
            if (isDmc)
                buf.writestring("_Z"); // DigitalMars long double
            else
                buf.writestring("_T"); // Intel long double
            break;
        case Tbool:
            buf.writestring("_N");
            break;
        case Tchar:
            buf.writeByte('D');
            break;
        case Twchar:
            buf.writestring("_S"); // Visual C++ char16_t (since C++11)
            break;
        case Tdchar:
            buf.writestring("_U"); // Visual C++ char32_t (since C++11)
            break;
        default:
            visit(cast(Type)type);
            return;
        }
        isNotTopType = false;
        ignoreConst = false;
    }

    override void visit(TypeVector type)
    {
        //printf("visit(TypeVector); is_not_top_type = %d\n", isNotTopType);
        if (checkTypeSaved(type))
            return;
        mangleModifier(type);
        buf.writestring("T__m128@@"); // may be better as __m128i or __m128d?
        isNotTopType = false;
        ignoreConst = false;
    }

    override void visit(TypeSArray type)
    {
        // This method can be called only for static variable type mangling.
        //printf("visit(TypeSArray); is_not_top_type = %d\n", isNotTopType);
        if (checkTypeSaved(type))
            return;
        // first dimension always mangled as const pointer
        if (isDmc)
            buf.writeByte('Q');
        else
            buf.writeByte('P');
        isNotTopType = true;
        assert(type.next);
        if (type.next.ty == Tsarray)
        {
            mangleArray(cast(TypeSArray)type.next);
        }
        else
        {
            type.next.accept(this);
        }
    }

    // attention: D int[1][2]* arr mapped to C++ int arr[][2][1]; (because it's more typical situation)
    // There is not way to map int C++ (*arr)[2][1] to D
    override void visit(TypePointer type)
    {
        //printf("visit(TypePointer); is_not_top_type = %d\n", isNotTopType);
        if (checkImmutableShared(type, loc))
            return;

        assert(type.next);
        if (type.next.ty == Tfunction)
        {
            const(char)* arg = mangleFunctionType(cast(TypeFunction)type.next); // compute args before checking to save; args should be saved before function type
            // If we've mangled this function early, previous call is meaningless.
            // However we should do it before checking to save types of function arguments before function type saving.
            // If this function was already mangled, types of all it arguments are save too, thus previous can't save
            // anything if function is saved.
            if (checkTypeSaved(type))
                return;
            if (type.isConst())
                buf.writeByte('Q'); // const
            else
                buf.writeByte('P'); // mutable
            buf.writeByte('6'); // pointer to a function
            buf.writestring(arg);
            isNotTopType = false;
            ignoreConst = false;
            return;
        }
        else if (type.next.ty == Tsarray)
        {
            if (checkTypeSaved(type))
                return;
            mangleModifier(type);
            if (type.isConst() || !isDmc)
                buf.writeByte('Q'); // const
            else
                buf.writeByte('P'); // mutable
            if (target.isLP64)
                buf.writeByte('E');
            isNotTopType = true;
            mangleArray(cast(TypeSArray)type.next);
            return;
        }
        else
        {
            if (checkTypeSaved(type))
                return;
            mangleModifier(type);
            if (type.isConst())
            {
                buf.writeByte('Q'); // const
            }
            else
            {
                buf.writeByte('P'); // mutable
            }
            if (target.isLP64)
                buf.writeByte('E');
            isNotTopType = true;
            type.next.accept(this);
        }
    }

    override void visit(TypeReference type)
    {
        //printf("visit(TypeReference); type = %s\n", type.toChars());
        if (checkTypeSaved(type))
            return;

        if (checkImmutableShared(type, loc))
            return;

        buf.writeByte('A'); // mutable
        if (target.isLP64)
            buf.writeByte('E');
        isNotTopType = true;
        assert(type.next);
        if (type.next.ty == Tsarray)
        {
            mangleArray(cast(TypeSArray)type.next);
        }
        else
        {
            type.next.accept(this);
        }
    }

    override void visit(TypeFunction type)
    {
        const(char)* arg = mangleFunctionType(type);
        if (isDmc)
        {
            if (checkTypeSaved(type))
                return;
        }
        else
        {
            buf.writestring("$$A6");
        }
        buf.writestring(arg);
        isNotTopType = false;
        ignoreConst = false;
    }

    override void visit(TypeStruct type)
    {
        if (checkTypeSaved(type))
            return;
        //printf("visit(TypeStruct); is_not_top_type = %d\n", isNotTopType);
        mangleModifier(type);
        const agg = type.sym.isStructDeclaration();
        if (type.sym.isUnionDeclaration())
            buf.writeByte('T');
        else
            buf.writeByte(agg.cppmangle == CPPMANGLE.asClass ? 'V' : 'U');
        mangleIdent(type.sym);
        isNotTopType = false;
        ignoreConst = false;
    }

    override void visit(TypeEnum type)
    {
        //printf("visit(TypeEnum); is_not_top_type = %d\n", cast(int)(flags & isNotTopType));
        const id = type.sym.ident;
        string c;
        if (id == Id.__c_long_double)
            c = "O"; // VC++ long double
        else if (id == Id.__c_long)
            c = "J"; // VC++ long
        else if (id == Id.__c_ulong)
            c = "K"; // VC++ unsigned long
        else if (id == Id.__c_longlong)
            c = "_J"; // VC++ long long
        else if (id == Id.__c_ulonglong)
            c = "_K"; // VC++ unsigned long long
        else if (id == Id.__c_char)
            c = "D";  // VC++ char
        else if (id == Id.__c_wchar_t)
        {
            c = isDmc ? "_Y" : "_W";
        }

        if (c.length)
        {
            if (checkImmutableShared(type, loc))
                return;

            if (type.isConst() && (isNotTopType || isDmc))
            {
                if (checkTypeSaved(type))
                    return;
            }
            mangleModifier(type);
            buf.writestring(c);
        }
        else
        {
            if (checkTypeSaved(type))
                return;
            mangleModifier(type);
            buf.writestring("W4");
            mangleIdent(type.sym);
        }
        isNotTopType = false;
        ignoreConst = false;
    }

    // D class mangled as pointer to C++ class
    // const(Object) mangled as Object const* const
    override void visit(TypeClass type)
    {
        //printf("visit(TypeClass); is_not_top_type = %d\n", isNotTopType);
        if (checkTypeSaved(type))
            return;
        if (isNotTopType)
            mangleModifier(type);
        if (type.isConst())
            buf.writeByte('Q');
        else
            buf.writeByte('P');
        if (target.isLP64)
            buf.writeByte('E');
        isNotTopType = true;
        mangleModifier(type);
        const cldecl = type.sym.isClassDeclaration();
        buf.writeByte(cldecl.cppmangle == CPPMANGLE.asStruct ? 'U' : 'V');
        mangleIdent(type.sym);
        isNotTopType = false;
        ignoreConst = false;
    }

    const(char)* mangleOf(Dsymbol s)
    {
        VarDeclaration vd = s.isVarDeclaration();
        FuncDeclaration fd = s.isFuncDeclaration();
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
        return buf.extractChars();
    }

private:
extern(D):

    void mangleFunction(FuncDeclaration d)
    {
        // <function mangle> ? <qualified name> <flags> <return type> <arg list>
        assert(d);
        buf.writeByte('?');
        mangleIdent(d);
        if (d.needThis()) // <flags> ::= <virtual/protection flag> <const/volatile flag> <calling convention flag>
        {
            // Pivate methods always non-virtual in D and it should be mangled as non-virtual in C++
            //printf("%s: isVirtualMethod = %d, isVirtual = %d, vtblIndex = %d, interfaceVirtual = %p\n",
                //d.toChars(), d.isVirtualMethod(), d.isVirtual(), cast(int)d.vtblIndex, d.interfaceVirtual);
            if ((d.isVirtual() && (d.vtblIndex != -1 || d.interfaceVirtual || d.overrideInterface())) || (d.isDtorDeclaration() && d.parent.isClassDeclaration() && !d.isFinal()))
            {
                mangleVisibility(buf, d, "EMU");
            }
            else
            {
                mangleVisibility(buf, d, "AIQ");
            }
            if (target.isLP64)
                buf.writeByte('E');
            if (d.type.isConst())
            {
                buf.writeByte('B');
            }
            else
            {
                buf.writeByte('A');
            }
        }
        else if (d.isMember2()) // static function
        {
            // <flags> ::= <virtual/protection flag> <calling convention flag>
            mangleVisibility(buf, d, "CKS");
        }
        else // top-level function
        {
            // <flags> ::= Y <calling convention flag>
            buf.writeByte('Y');
        }
        const(char)* args = mangleFunctionType(cast(TypeFunction)d.type, d.needThis(), d.isCtorDeclaration() || isAggregateDtor(d));
        buf.writestring(args);
    }

    void mangleVariable(VarDeclaration d)
    {
        // <static variable mangle> ::= ? <qualified name> <protection flag> <const/volatile flag> <type>
        assert(d);
        // fake mangling for fields to fix https://issues.dlang.org/show_bug.cgi?id=16525
        if (!(d.storage_class & (STC.extern_ | STC.field | STC.gshared)))
        {
            .error(d.loc, "%s `%s` internal compiler error: C++ static non-__gshared non-extern variables not supported", d.kind, d.toPrettyChars);
            fatal();
        }
        buf.writeByte('?');
        mangleIdent(d);
        assert((d.storage_class & STC.field) || !d.needThis());
        Dsymbol parent = d.toParent();
        while (parent && parent.isNspace())
        {
            parent = parent.toParent();
        }
        if (parent && parent.isModule()) // static member
        {
            buf.writeByte('3');
        }
        else
        {
            mangleVisibility(buf, d, "012");
        }
        Type t = d.type;

        if (checkImmutableShared(t, loc))
            return;

        const cv_mod = t.isConst() ? 'B' : 'A';
        if (t.ty != Tpointer)
            t = t.mutableOf();
        t.accept(this);
        if ((t.ty == Tpointer || t.ty == Treference || t.ty == Tclass) && target.isLP64)
        {
            buf.writeByte('E');
        }
        buf.writeByte(cv_mod);
    }

    /**
     * Mangles a template value
     *
     * Params:
     *      o               = expression that represents the value
     *      tv              = template value
     *      is_dmc_template = use DMC mangling
     */
    void mangleTemplateValue(RootObject o, TemplateValueParameter tv, Dsymbol sym, bool is_dmc_template)
    {
        if (!tv.valType.isintegral())
        {
            .error(sym.loc, "%s `%s` internal compiler error: C++ %s template value parameter is not supported", sym.kind, sym.toPrettyChars, tv.valType.toChars());
            fatal();
            return;
        }
        buf.writeByte('$');
        buf.writeByte('0');
        Expression e = isExpression(o);
        assert(e);
        if (tv.valType.isunsigned())
        {
            mangleNumber(buf, e.toUInteger());
        }
        else if (is_dmc_template)
        {
            // NOTE: DMC mangles everything based on
            // unsigned int
            mangleNumber(buf, e.toInteger());
        }
        else
        {
            sinteger_t val = e.toInteger();
            if (val < 0)
            {
                val = -val;
                buf.writeByte('?');
            }
            mangleNumber(buf, val);
        }
    }

    /**
     * Mangles a template alias parameter
     *
     * Params:
     *      o   = the alias value, a symbol or expression
     */
    void mangleTemplateAlias(RootObject o, Dsymbol sym)
    {
        Dsymbol d = isDsymbol(o);
        Expression e = isExpression(o);

        if (d && d.isFuncDeclaration())
        {
            buf.writeByte('$');
            buf.writeByte('1');
            mangleFunction(d.isFuncDeclaration());
        }
        else if (e && e.op == EXP.variable && (cast(VarExp)e).var.isVarDeclaration())
        {
            buf.writeByte('$');
            if (isDmc)
                buf.writeByte('1');
            else
                buf.writeByte('E');
            mangleVariable((cast(VarExp)e).var.isVarDeclaration());
        }
        else if (d && d.isTemplateDeclaration() && d.isTemplateDeclaration().onemember)
        {
            Dsymbol ds = d.isTemplateDeclaration().onemember;
            if (isDmc)
            {
                buf.writeByte('V');
            }
            else
            {
                if (ds.isUnionDeclaration())
                {
                    buf.writeByte('T');
                }
                else if (ds.isStructDeclaration())
                {
                    buf.writeByte('U');
                }
                else if (ds.isClassDeclaration())
                {
                    buf.writeByte('V');
                }
                else
                {
                    .error(sym.loc, "%s `%s` internal compiler error: C++ templates support only integral value, type parameters, alias templates and alias function parameters",
                        sym.kind, sym.toPrettyChars);
                    fatal();
                }
            }
            mangleIdent(d);
        }
        else
        {
            .error(sym.loc, "%s `%s` internal compiler error: `%s` is unsupported parameter for C++ template", sym.kind, sym.toPrettyChars, o.toChars());
            fatal();
        }
    }

    /**
     * Mangles a template alias parameter
     *
     * Params:
     *      o   = type
     */
    void mangleTemplateType(RootObject o)
    {
        escape = true;
        Type t = isType(o);
        assert(t);
        t.accept(this);
        escape = false;
    }

    /**
     * Mangles the name of a symbol
     *
     * Params:
     *      sym   = symbol to mangle
     *      dont_use_back_reference = dont use back referencing
     */
    void mangleName(Dsymbol sym, bool dont_use_back_reference)
    {
        //printf("mangleName('%s')\n", sym.toChars());
        bool is_dmc_template = false;

        if (string s = mangleSpecialName(sym))
        {
            buf.writestring(s);
            return;
        }

        void writeName(Identifier name)
        {
            assert(name);
            if (!is_dmc_template && dont_use_back_reference)
                saveIdent(name);
            else if (checkAndSaveIdent(name))
                return;

            buf.writestring(name.toString());
            buf.writeByte('@');
        }
        auto ti = sym.isTemplateInstance();
        if (!ti)
        {
            if (auto ag = sym.isAggregateDeclaration())
            {
                if (ag.pMangleOverride)
                {
                    writeName(ag.pMangleOverride.id);
                    return;
                }
            }
            writeName(sym.ident);
            return;
        }
        auto id = ti.tempdecl.ident;
        auto symName = id.toString();

        int firstTemplateArg = 0;

        // test for special symbols
        if (mangleOperator(buf, ti,symName,firstTemplateArg))
            return;
        TemplateInstance actualti = ti;
        bool needNamespaces;
        if (auto ag = ti.aliasdecl ? ti.aliasdecl.isAggregateDeclaration() : null)
        {
            if (ag.pMangleOverride)
            {
                if (ag.pMangleOverride.agg)
                {
                    if (auto aggti = ag.pMangleOverride.agg.isInstantiated())
                        actualti = aggti;
                    else
                    {
                        writeName(ag.pMangleOverride.id);
                        if (sym.parent && !sym.parent.needThis())
                            for (auto ns = ag.pMangleOverride.agg.toAlias().cppnamespace; ns !is null && ns.ident !is null; ns = ns.cppnamespace)
                                writeName(ns.ident);
                        return;
                    }
                    id = ag.pMangleOverride.id;
                    symName = id.toString();
                    needNamespaces = true;
                }
                else
                {
                    writeName(ag.pMangleOverride.id);
                    for (auto ns = ti.toAlias().cppnamespace; ns !is null && ns.ident !is null; ns = ns.cppnamespace)
                        writeName(ns.ident);
                    return;
                }
            }
        }

        scope VisualCPPMangler tmp = new VisualCPPMangler(isDmc ? true : false, loc);
        tmp.buf.writeByte('?');
        tmp.buf.writeByte('$');
        tmp.buf.writestring(symName);
        tmp.saved_idents[0] = id;
        if (symName == id.toString())
            tmp.buf.writeByte('@');
        if (isDmc)
        {
            tmp.mangleIdent(sym.parent, true);
            is_dmc_template = true;
        }
        bool is_var_arg = false;
        for (size_t i = firstTemplateArg; i < actualti.tiargs.length; i++)
        {
            RootObject o = (*actualti.tiargs)[i];
            TemplateParameter tp = null;
            TemplateValueParameter tv = null;
            TemplateTupleParameter tt = null;
            if (!is_var_arg)
            {
                TemplateDeclaration td = actualti.tempdecl.isTemplateDeclaration();
                assert(td);
                tp = (*td.parameters)[i];
                tv = tp.isTemplateValueParameter();
                tt = tp.isTemplateTupleParameter();
            }
            if (tt)
            {
                is_var_arg = true;
                tp = null;
            }
            if (tv)
            {
                tmp.mangleTemplateValue(o, tv, actualti, is_dmc_template);
            }
            else if (!tp || tp.isTemplateTypeParameter())
            {
                Type t = isType(o);
                if (t is null)
                {
                    .error(actualti.loc, "%s `%s` internal compiler error: C++ `%s` template value parameter is not supported",
                        actualti.kind, actualti.toPrettyChars, o.toChars());
                    fatal();
                }
                tmp.mangleTemplateType(o);
            }
            else if (tp.isTemplateAliasParameter())
            {
                tmp.mangleTemplateAlias(o, actualti);
            }
            else
            {
                .error(sym.loc, "%s `%s` internal compiler error: C++ templates support only integral value, type parameters, alias templates and alias function parameters",
                    sym.kind, sym.toPrettyChars);
                fatal();
            }
        }

        writeName(Identifier.idPool(tmp.buf.extractSlice()));
        if (needNamespaces && actualti != ti)
        {
            for (auto ns = ti.toAlias().cppnamespace; ns !is null && ns.ident !is null; ns = ns.cppnamespace)
                writeName(ns.ident);
        }
    }

    // returns true if name already saved
    bool checkAndSaveIdent(Identifier name) @safe
    {
        foreach (i, ref id; saved_idents)
        {
            if (!id) // no saved same name
            {
                id = name;
                break;
            }
            if (id == name) // ok, we've found same name. use index instead of name
            {
                buf.writeByte(cast(uint)i + '0');
                return true;
            }
        }
        return false;
    }

    void saveIdent(Identifier name) @safe
    {
        foreach (ref id; saved_idents)
        {
            if (!id) // no saved same name
            {
                id = name;
                break;
            }
            if (id == name) // ok, we've found same name. use index instead of name
            {
                return;
            }
        }
    }

    void mangleIdent(Dsymbol sym, bool dont_use_back_reference = false)
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
        //printf("mangleIdent('%s')\n", sym.toChars());
        Dsymbol p = sym;
        if (p.toParent() && p.toParent().isTemplateInstance())
        {
            p = p.toParent();
        }
        while (p && !p.isModule())
        {
            mangleName(p, dont_use_back_reference);
            // Mangle our string namespaces as well
            for (auto ns = p.cppnamespace; ns !is null && ns.ident !is null; ns = ns.cppnamespace)
                mangleName(ns, dont_use_back_reference);

            p = p.toParent();
            if (p.toParent() && p.toParent().isTemplateInstance())
            {
                p = p.toParent();
            }
        }
        if (!dont_use_back_reference)
            buf.writeByte('@');
    }

    bool checkTypeSaved(Type type)
    {
        if (isNotTopType)
            return false;
        if (mangleReturnType)
            return false;
        foreach (i, ref ty; saved_types)
        {
            if (!ty) // no saved same type
            {
                ty = type;
                return false;
            }
            if (ty.equals(type)) // ok, we've found same type. use index instead of type
            {
                buf.writeByte(cast(uint)i + '0');
                isNotTopType = false;
                ignoreConst = false;
                return true;
            }
        }
        return false;
    }

    void mangleModifier(Type type)
    {
        if (ignoreConst)
            return;
        if (checkImmutableShared(type, loc))
            return;

        if (type.isConst())
        {
            // Template parameters that are not pointers and are const need an $$C escape
            // in addition to 'B' (const).
            if (escape && type.ty != Tpointer)
                buf.writestring("$$CB");
            else if (isNotTopType)
                buf.writeByte('B'); // const
            else if (isDmc && type.ty != Tpointer)
                buf.writestring("_O");
        }
        else if (isNotTopType)
            buf.writeByte('A'); // mutable

        escape = false;
    }

    void mangleArray(TypeSArray type)
    {
        mangleModifier(type);
        size_t i = 0;
        Type cur = type;
        while (cur && cur.ty == Tsarray)
        {
            i++;
            cur = cur.nextOf();
        }
        buf.writeByte('Y');
        mangleNumber(buf, i); // count of dimensions
        cur = type;
        while (cur && cur.ty == Tsarray) // sizes of dimensions
        {
            TypeSArray sa = cast(TypeSArray)cur;
            mangleNumber(buf, sa.dim ? sa.dim.toInteger() : 0);
            cur = cur.nextOf();
        }
        ignoreConst = true;
        cur.accept(this);
    }

    const(char)* mangleFunctionType(TypeFunction type, bool needthis = false, bool noreturn = false)
    {
        scope VisualCPPMangler tmp = new VisualCPPMangler(this);
        // Calling convention
        if (target.isLP64) // always Microsoft x64 calling convention
        {
            tmp.buf.writeByte('A');
        }
        else
        {
            final switch (type.linkage)
            {
            case LINK.c:
                tmp.buf.writeByte('A');
                break;
            case LINK.cpp:
                if (needthis && type.parameterList.varargs != VarArg.variadic)
                    tmp.buf.writeByte('E'); // thiscall
                else
                    tmp.buf.writeByte('A'); // cdecl
                break;
            case LINK.windows:
                tmp.buf.writeByte('G'); // stdcall
                break;
            case LINK.d:
            case LINK.default_:
            case LINK.objc:
                tmp.visit(cast(Type)type);
                break;
            case LINK.system:
                assert(0);
            }
        }
        tmp.isNotTopType = false;
        if (noreturn)
        {
            tmp.buf.writeByte('@');
        }
        else
        {
            Type rettype = type.next;
            if (type.isref)
                rettype = rettype.referenceTo();
            ignoreConst = false;
            if (rettype.ty == Tstruct)
            {
                tmp.buf.writeByte('?');
                tmp.buf.writeByte('A');
            }
            else if (rettype.ty == Tenum)
            {
                const id = rettype.toDsymbol(null).ident;
                if (!isSpecialEnumIdent(id))
                {
                    tmp.buf.writeByte('?');
                    tmp.buf.writeByte('A');
                }
            }
            tmp.mangleReturnType = true;
            rettype.accept(tmp);
            tmp.mangleReturnType = false;
        }
        if (!type.parameterList.parameters || !type.parameterList.parameters.length)
        {
            if (type.parameterList.varargs == VarArg.variadic)
                tmp.buf.writeByte('Z');
            else
                tmp.buf.writeByte('X');
        }
        else
        {
            foreach (n, p; type.parameterList)
            {
                Type t = p.type.merge2();
                if (p.isReference())
                    t = t.referenceTo();
                else if (p.isLazy())
                {
                    // Mangle as delegate
                    auto tf = new TypeFunction(ParameterList(), t, LINK.d);
                    auto td = new TypeDelegate(tf);
                    t = td.merge();
                }
                else if (Type cpptype = target.cpp.parameterType(t))
                    t = cpptype;
                if (t.ty == Tsarray)
                {
                    error(loc, "internal compiler error: unable to pass static array to `extern(C++)` function.");
                    errorSupplemental(loc, "Use pointer instead.");
                    assert(0);
                }
                tmp.isNotTopType = false;
                ignoreConst = false;
                t.accept(tmp);
            }

            if (type.parameterList.varargs == VarArg.variadic)
            {
                tmp.buf.writeByte('Z');
            }
            else
            {
                tmp.buf.writeByte('@');
            }
        }
        tmp.buf.writeByte('Z');
        const(char)* ret = tmp.buf.extractChars();
        saved_idents[] = tmp.saved_idents[];
        saved_types[] = tmp.saved_types[];
        return ret;
    }
}

private:
extern(D):

/**
 * Computes mangling for symbols with special mangling.
 * Params:
 *      sym = symbol to mangle
 * Returns:
 *      mangling for special symbols,
 *      null if not a special symbol
 */
string mangleSpecialName(Dsymbol sym)
{
    string mangle;
    if (sym.isCtorDeclaration())
        mangle = "?0";
    else if (sym.isAggregateDtor())
        mangle = "?1";
    else if (!sym.ident)
        return null;
    else if (sym.ident == Id.assign)
        mangle = "?4";
    else if (sym.ident == Id.eq)
        mangle = "?8";
    else if (sym.ident == Id.index)
        mangle = "?A";
    else if (sym.ident == Id.call)
        mangle = "?R";
    else if (sym.ident == Id.cppdtor)
        mangle = "?_G";
    else
        return null;

    return mangle;
}

/**
 * Mangles an operator, if any
 *
 * Params:
 *      buf                 = buffer to write mangling to
 *      ti                  = associated template instance of the operator
 *      symName             = symbol name
 *      firstTemplateArg    = index if the first argument of the template (because the corresponding c++ operator is not a template)
 * Returns:
 *      true if sym has no further mangling needed
 *      false otherwise
 */
bool mangleOperator(ref OutBuffer buf, TemplateInstance ti, ref const(char)[] symName, ref int firstTemplateArg)
{
    auto whichOp = isCppOperator(ti.name);
    final switch (whichOp)
    {
    case CppOperator.Unknown:
        return false;
    case CppOperator.Cast:
        buf.writestring("?B");
        return true;
    case CppOperator.Assign:
        symName = "?4";
        return false;
    case CppOperator.Eq:
        symName = "?8";
        return false;
    case CppOperator.Index:
        symName = "?A";
        return false;
    case CppOperator.Call:
        symName = "?R";
        return false;

    case CppOperator.Unary:
    case CppOperator.Binary:
    case CppOperator.OpAssign:
        TemplateDeclaration td = ti.tempdecl.isTemplateDeclaration();
        assert(td);
        assert(ti.tiargs.length >= 1);
        TemplateParameter tp = (*td.parameters)[0];
        TemplateValueParameter tv = tp.isTemplateValueParameter();
        if (!tv || !tv.valType.isString())
            return false; // expecting a string argument to operators!
        Expression exp = (*ti.tiargs)[0].isExpression();
        StringExp str = exp.toStringExp();
        switch (whichOp)
        {
        case CppOperator.Unary:
            switch (str.peekString())
            {
                case "*":   symName = "?D";     goto continue_template;
                case "++":  symName = "?E";     goto continue_template;
                case "--":  symName = "?F";     goto continue_template;
                case "-":   symName = "?G";     goto continue_template;
                case "+":   symName = "?H";     goto continue_template;
                case "~":   symName = "?S";     goto continue_template;
                default:    return false;
            }
        case CppOperator.Binary:
            switch (str.peekString())
            {
                case ">>":  symName = "?5";     goto continue_template;
                case "<<":  symName = "?6";     goto continue_template;
                case "*":   symName = "?D";     goto continue_template;
                case "-":   symName = "?G";     goto continue_template;
                case "+":   symName = "?H";     goto continue_template;
                case "&":   symName = "?I";     goto continue_template;
                case "/":   symName = "?K";     goto continue_template;
                case "%":   symName = "?L";     goto continue_template;
                case "^":   symName = "?T";     goto continue_template;
                case "|":   symName = "?U";     goto continue_template;
                default:    return false;
                }
        case CppOperator.OpAssign:
            switch (str.peekString())
            {
                case "*":   symName = "?X";     goto continue_template;
                case "+":   symName = "?Y";     goto continue_template;
                case "-":   symName = "?Z";     goto continue_template;
                case "/":   symName = "?_0";    goto continue_template;
                case "%":   symName = "?_1";    goto continue_template;
                case ">>":  symName = "?_2";    goto continue_template;
                case "<<":  symName = "?_3";    goto continue_template;
                case "&":   symName = "?_4";    goto continue_template;
                case "|":   symName = "?_5";    goto continue_template;
                case "^":   symName = "?_6";    goto continue_template;
                default:    return false;
            }
        default: assert(0);
        }
    }
    continue_template:
    if (ti.tiargs.length == 1)
    {
        buf.writestring(symName);
        return true;
    }
    firstTemplateArg = 1;
    return false;
}

/**********************************'
 */
void mangleNumber(ref OutBuffer buf, dinteger_t num)
{
    if (!num) // 0 encoded as "A@"
    {
        buf.writeByte('A');
        buf.writeByte('@');
        return;
    }
    if (num <= 10) // 5 encoded as "4"
    {
        buf.writeByte(cast(char)(num - 1 + '0'));
        return;
    }
    char[17] buff = void;
    buff[16] = 0;
    size_t i = 16;
    while (num)
    {
        --i;
        buff[i] = num % 16 + 'A';
        num /= 16;
    }
    buf.writestring(&buff[i]);
    buf.writeByte('@');
}

/*************************************
 */
void mangleVisibility(ref OutBuffer buf, Declaration d, string privProtDef)@safe
{
    switch (d.visibility.kind)
    {
        case Visibility.Kind.private_:
            buf.writeByte(privProtDef[0]);
            break;
        case Visibility.Kind.protected_:
            buf.writeByte(privProtDef[1]);
            break;
        default:
            buf.writeByte(privProtDef[2]);
            break;
    }
}
