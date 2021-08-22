/**
 * Do mangling for C++ linkage for Digital Mars C++ and Microsoft Visual C++.
 *
 * Copyright: Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors: Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/cppmanglewin.d, _cppmanglewin.d)
 * Documentation:  https://dlang.org/phobos/dmd_cppmanglewin.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/cppmanglewin.d
 */

module dmd.cppmanglewin;

import core.stdc.string;
import core.stdc.stdio;

import dmd.arraytypes;
import dmd.astenums;
import dmd.cppmangle : isPrimaryDtor, isCppOperator, CppOperator;
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
import dmd.mtype;
import dmd.root.outbuffer;
import dmd.root.rootobject;
import dmd.target;
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;

extern (C++):


const(char)* toCppMangleMSVC(Dsymbol s)
{
    scope VisualCPPMangler v = new VisualCPPMangler(!target.mscoff);
    return v.mangleOf(s);
}

const(char)* cppTypeInfoMangleMSVC(Dsymbol s)
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
private bool checkImmutableShared(Type type)
{
    if (type.isImmutable() || type.isShared())
    {
        error(Loc.initial, "Internal Compiler Error: `shared` or `immutable` types cannot be mapped to C++ (%s)", type.toChars());
        fatal();
        return true;
    }
    return false;
}
private final class VisualCPPMangler : Visitor
{
    enum VC_SAVED_TYPE_CNT = 10u;
    enum VC_SAVED_IDENT_CNT = 10u;

    alias visit = Visitor.visit;
    Identifier[VC_SAVED_IDENT_CNT] saved_idents;
    Type[VC_SAVED_TYPE_CNT] saved_types;

    // IS_NOT_TOP_TYPE: when we mangling one argument, we can call visit several times (for base types of arg type)
    // but we must save only arg type:
    // For example: if we have an int** argument, we should save "int**" but visit will be called for "int**", "int*", "int"
    // This flag is set up by the visit(NextType, ) function  and should be reset when the arg type output is finished.
    // MANGLE_RETURN_TYPE: return type shouldn't be saved and substituted in arguments
    // IGNORE_CONST: in some cases we should ignore CV-modifiers.
    // ESCAPE: toplevel const non-pointer types need a '$$C' escape in addition to a cv qualifier.

    enum Flags : int
    {
        IS_NOT_TOP_TYPE = 0x1,
        MANGLE_RETURN_TYPE = 0x2,
        IGNORE_CONST = 0x4,
        IS_DMC = 0x8,
        ESCAPE = 0x10,
    }

    alias IS_NOT_TOP_TYPE = Flags.IS_NOT_TOP_TYPE;
    alias MANGLE_RETURN_TYPE = Flags.MANGLE_RETURN_TYPE;
    alias IGNORE_CONST = Flags.IGNORE_CONST;
    alias IS_DMC = Flags.IS_DMC;
    alias ESCAPE = Flags.ESCAPE;

    int flags;
    OutBuffer buf;

    extern (D) this(VisualCPPMangler rvl)
    {
        flags |= (rvl.flags & IS_DMC);
        saved_idents[] = rvl.saved_idents[];
        saved_types[] = rvl.saved_types[];
    }

public:
    extern (D) this(bool isdmc)
    {
        if (isdmc)
        {
            flags |= IS_DMC;
        }
        saved_idents[] = null;
        saved_types[] = null;
    }

    override void visit(Type type)
    {
        if (checkImmutableShared(type))
            return;

        error(Loc.initial, "Internal Compiler Error: type `%s` cannot be mapped to C++\n", type.toChars());
        fatal(); //Fatal, because this error should be handled in frontend
    }

    override void visit(TypeNull type)
    {
        if (checkImmutableShared(type))
            return;
        if (checkTypeSaved(type))
            return;

        buf.writestring("$$T");
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    override void visit(TypeNoreturn type)
    {
        if (checkImmutableShared(type))
            return;
        if (checkTypeSaved(type))
            return;

        buf.writeByte('X');             // yes, mangle it like `void`
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    override void visit(TypeBasic type)
    {
        //printf("visit(TypeBasic); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkImmutableShared(type))
            return;

        if (type.isConst() && ((flags & IS_NOT_TOP_TYPE) || (flags & IS_DMC)))
        {
            if (checkTypeSaved(type))
                return;
        }
        if ((type.ty == Tbool) && checkTypeSaved(type)) // try to replace long name with number
        {
            return;
        }
        if (!(flags & IS_DMC))
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
            if (flags & IS_DMC)
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
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    override void visit(TypeVector type)
    {
        //printf("visit(TypeVector); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type))
            return;
        mangleModifier(type);
        buf.writestring("T__m128@@"); // may be better as __m128i or __m128d?
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    override void visit(TypeSArray type)
    {
        // This method can be called only for static variable type mangling.
        //printf("visit(TypeSArray); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type))
            return;
        // first dimension always mangled as const pointer
        if (flags & IS_DMC)
            buf.writeByte('Q');
        else
            buf.writeByte('P');
        flags |= IS_NOT_TOP_TYPE;
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
        //printf("visit(TypePointer); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkImmutableShared(type))
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
            flags &= ~IS_NOT_TOP_TYPE;
            flags &= ~IGNORE_CONST;
            return;
        }
        else if (type.next.ty == Tsarray)
        {
            if (checkTypeSaved(type))
                return;
            mangleModifier(type);
            if (type.isConst() || !(flags & IS_DMC))
                buf.writeByte('Q'); // const
            else
                buf.writeByte('P'); // mutable
            if (target.is64bit)
                buf.writeByte('E');
            flags |= IS_NOT_TOP_TYPE;
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
            if (target.is64bit)
                buf.writeByte('E');
            flags |= IS_NOT_TOP_TYPE;
            type.next.accept(this);
        }
    }

    override void visit(TypeReference type)
    {
        //printf("visit(TypeReference); type = %s\n", type.toChars());
        if (checkTypeSaved(type))
            return;

        if (checkImmutableShared(type))
            return;

        buf.writeByte('A'); // mutable
        if (target.is64bit)
            buf.writeByte('E');
        flags |= IS_NOT_TOP_TYPE;
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
        if ((flags & IS_DMC))
        {
            if (checkTypeSaved(type))
                return;
        }
        else
        {
            buf.writestring("$$A6");
        }
        buf.writestring(arg);
        flags &= ~(IS_NOT_TOP_TYPE | IGNORE_CONST);
    }

    override void visit(TypeStruct type)
    {
        if (checkTypeSaved(type))
            return;
        //printf("visit(TypeStruct); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        mangleModifier(type);
        const agg = type.sym.isStructDeclaration();
        if (type.sym.isUnionDeclaration())
            buf.writeByte('T');
        else
            buf.writeByte(agg.cppmangle == CPPMANGLE.asClass ? 'V' : 'U');
        mangleIdent(type.sym);
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    override void visit(TypeEnum type)
    {
        //printf("visit(TypeEnum); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
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
        else if (id == Id.__c_wchar_t)
        {
            c = (flags & IS_DMC) ? "_Y" : "_W";
        }

        if (c.length)
        {
            if (checkImmutableShared(type))
                return;

            if (type.isConst() && ((flags & IS_NOT_TOP_TYPE) || (flags & IS_DMC)))
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
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
    }

    // D class mangled as pointer to C++ class
    // const(Object) mangled as Object const* const
    override void visit(TypeClass type)
    {
        //printf("visit(TypeClass); is_not_top_type = %d\n", (int)(flags & IS_NOT_TOP_TYPE));
        if (checkTypeSaved(type))
            return;
        if (flags & IS_NOT_TOP_TYPE)
            mangleModifier(type);
        if (type.isConst())
            buf.writeByte('Q');
        else
            buf.writeByte('P');
        if (target.is64bit)
            buf.writeByte('E');
        flags |= IS_NOT_TOP_TYPE;
        mangleModifier(type);
        const cldecl = type.sym.isClassDeclaration();
        buf.writeByte(cldecl.cppmangle == CPPMANGLE.asStruct ? 'U' : 'V');
        mangleIdent(type.sym);
        flags &= ~IS_NOT_TOP_TYPE;
        flags &= ~IGNORE_CONST;
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

    void mangleVisibility(Declaration d, string privProtDef)
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
                mangleVisibility(d, "EMU");
            }
            else
            {
                mangleVisibility(d, "AIQ");
            }
            if (target.is64bit)
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
            mangleVisibility(d, "CKS");
        }
        else // top-level function
        {
            // <flags> ::= Y <calling convention flag>
            buf.writeByte('Y');
        }
        const(char)* args = mangleFunctionType(cast(TypeFunction)d.type, d.needThis(), d.isCtorDeclaration() || isPrimaryDtor(d));
        buf.writestring(args);
    }

    void mangleVariable(VarDeclaration d)
    {
        // <static variable mangle> ::= ? <qualified name> <protection flag> <const/volatile flag> <type>
        assert(d);
        // fake mangling for fields to fix https://issues.dlang.org/show_bug.cgi?id=16525
        if (!(d.storage_class & (STC.extern_ | STC.field | STC.gshared)))
        {
            d.error("Internal Compiler Error: C++ static non-__gshared non-extern variables not supported");
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
            mangleVisibility(d, "012");
        }
        Type t = d.type;

        if (checkImmutableShared(t))
            return;

        const cv_mod = t.isConst() ? 'B' : 'A';
        if (t.ty != Tpointer)
            t = t.mutableOf();
        t.accept(this);
        if ((t.ty == Tpointer || t.ty == Treference || t.ty == Tclass) && target.is64bit)
        {
            buf.writeByte('E');
        }
        buf.writeByte(cv_mod);
    }

    /**
     * Computes mangling for symbols with special mangling.
     * Params:
     *      sym = symbol to mangle
     * Returns:
     *      mangling for special symbols,
     *      null if not a special symbol
     */
    static string mangleSpecialName(Dsymbol sym)
    {
        string mangle;
        if (sym.isCtorDeclaration())
            mangle = "?0";
        else if (sym.isPrimaryDtor())
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
     *      ti                  = associated template instance of the operator
     *      symName             = symbol name
     *      firstTemplateArg    = index if the first argument of the template (because the corresponding c++ operator is not a template)
     * Returns:
     *      true if sym has no further mangling needed
     *      false otherwise
     */
    bool mangleOperator(TemplateInstance ti, ref const(char)[] symName, ref int firstTemplateArg)
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
            assert(ti.tiargs.dim >= 1);
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
        if (ti.tiargs.dim == 1)
        {
            buf.writestring(symName);
            return true;
        }
        firstTemplateArg = 1;
        return false;
    }

    /**
     * Mangles a template value
     *
     * Params:
     *      o               = expression that represents the value
     *      tv              = template value
     *      is_dmc_template = use DMC mangling
     */
    void manlgeTemplateValue(RootObject o,TemplateValueParameter tv, Dsymbol sym,bool is_dmc_template)
    {
        if (!tv.valType.isintegral())
        {
            sym.error("Internal Compiler Error: C++ %s template value parameter is not supported", tv.valType.toChars());
            fatal();
            return;
        }
        buf.writeByte('$');
        buf.writeByte('0');
        Expression e = isExpression(o);
        assert(e);
        if (tv.valType.isunsigned())
        {
            mangleNumber(e.toUInteger());
        }
        else if (is_dmc_template)
        {
            // NOTE: DMC mangles everything based on
            // unsigned int
            mangleNumber(e.toInteger());
        }
        else
        {
            sinteger_t val = e.toInteger();
            if (val < 0)
            {
                val = -val;
                buf.writeByte('?');
            }
            mangleNumber(val);
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
        else if (e && e.op == TOK.variable && (cast(VarExp)e).var.isVarDeclaration())
        {
            buf.writeByte('$');
            if (flags & IS_DMC)
                buf.writeByte('1');
            else
                buf.writeByte('E');
            mangleVariable((cast(VarExp)e).var.isVarDeclaration());
        }
        else if (d && d.isTemplateDeclaration() && d.isTemplateDeclaration().onemember)
        {
            Dsymbol ds = d.isTemplateDeclaration().onemember;
            if (flags & IS_DMC)
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
                    sym.error("Internal Compiler Error: C++ templates support only integral value, type parameters, alias templates and alias function parameters");
                    fatal();
                }
            }
            mangleIdent(d);
        }
        else
        {
            sym.error("Internal Compiler Error: `%s` is unsupported parameter for C++ template", o.toChars());
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
        flags |= ESCAPE;
        Type t = isType(o);
        assert(t);
        t.accept(this);
        flags &= ~ESCAPE;
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
                if (ag.mangleOverride)
                {
                    writeName(ag.mangleOverride.id);
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
        if (mangleOperator(ti,symName,firstTemplateArg))
            return;
        TemplateInstance actualti = ti;
        bool needNamespaces;
        if (auto ag = ti.aliasdecl ? ti.aliasdecl.isAggregateDeclaration() : null)
        {
            if (ag.mangleOverride)
            {
                if (ag.mangleOverride.agg)
                {
                    if (auto aggti = ag.mangleOverride.agg.isInstantiated())
                        actualti = aggti;
                    else
                    {
                        writeName(ag.mangleOverride.id);
                        if (sym.parent && !sym.parent.needThis())
                            for (auto ns = ag.mangleOverride.agg.toAlias().cppnamespace; ns !is null && ns.ident !is null; ns = ns.cppnamespace)
                                writeName(ns.ident);
                        return;
                    }
                    id = ag.mangleOverride.id;
                    symName = id.toString();
                    needNamespaces = true;
                }
                else
                {
                    writeName(ag.mangleOverride.id);
                    for (auto ns = ti.toAlias().cppnamespace; ns !is null && ns.ident !is null; ns = ns.cppnamespace)
                        writeName(ns.ident);
                    return;
                }
            }
        }

        scope VisualCPPMangler tmp = new VisualCPPMangler((flags & IS_DMC) ? true : false);
        tmp.buf.writeByte('?');
        tmp.buf.writeByte('$');
        tmp.buf.writestring(symName);
        tmp.saved_idents[0] = id;
        if (symName == id.toString())
            tmp.buf.writeByte('@');
        if (flags & IS_DMC)
        {
            tmp.mangleIdent(sym.parent, true);
            is_dmc_template = true;
        }
        bool is_var_arg = false;
        for (size_t i = firstTemplateArg; i < actualti.tiargs.dim; i++)
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
                tmp.manlgeTemplateValue(o, tv, actualti, is_dmc_template);
            }
            else
            if (!tp || tp.isTemplateTypeParameter())
            {
                tmp.mangleTemplateType(o);
            }
            else if (tp.isTemplateAliasParameter())
            {
                tmp.mangleTemplateAlias(o, actualti);
            }
            else
            {
                sym.error("Internal Compiler Error: C++ templates support only integral value, type parameters, alias templates and alias function parameters");
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
    bool checkAndSaveIdent(Identifier name)
    {
        foreach (i; 0 .. VC_SAVED_IDENT_CNT)
        {
            if (!saved_idents[i]) // no saved same name
            {
                saved_idents[i] = name;
                break;
            }
            if (saved_idents[i] == name) // ok, we've found same name. use index instead of name
            {
                buf.writeByte(i + '0');
                return true;
            }
        }
        return false;
    }

    void saveIdent(Identifier name)
    {
        foreach (i; 0 .. VC_SAVED_IDENT_CNT)
        {
            if (!saved_idents[i]) // no saved same name
            {
                saved_idents[i] = name;
                break;
            }
            if (saved_idents[i] == name) // ok, we've found same name. use index instead of name
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
            buf.writeByte(cast(char)(num - 1 + '0'));
            return;
        }
        char[17] buff;
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

    bool checkTypeSaved(Type type)
    {
        if (flags & IS_NOT_TOP_TYPE)
            return false;
        if (flags & MANGLE_RETURN_TYPE)
            return false;
        for (uint i = 0; i < VC_SAVED_TYPE_CNT; i++)
        {
            if (!saved_types[i]) // no saved same type
            {
                saved_types[i] = type;
                return false;
            }
            if (saved_types[i].equals(type)) // ok, we've found same type. use index instead of type
            {
                buf.writeByte(i + '0');
                flags &= ~IS_NOT_TOP_TYPE;
                flags &= ~IGNORE_CONST;
                return true;
            }
        }
        return false;
    }

    void mangleModifier(Type type)
    {
        if (flags & IGNORE_CONST)
            return;
        if (checkImmutableShared(type))
            return;

        if (type.isConst())
        {
            // Template parameters that are not pointers and are const need an $$C escape
            // in addition to 'B' (const).
            if ((flags & ESCAPE) && type.ty != Tpointer)
                buf.writestring("$$CB");
            else if (flags & IS_NOT_TOP_TYPE)
                buf.writeByte('B'); // const
            else if ((flags & IS_DMC) && type.ty != Tpointer)
                buf.writestring("_O");
        }
        else if (flags & IS_NOT_TOP_TYPE)
            buf.writeByte('A'); // mutable

        flags &= ~ESCAPE;
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
        mangleNumber(i); // count of dimensions
        cur = type;
        while (cur && cur.ty == Tsarray) // sizes of dimensions
        {
            TypeSArray sa = cast(TypeSArray)cur;
            mangleNumber(sa.dim ? sa.dim.toInteger() : 0);
            cur = cur.nextOf();
        }
        flags |= IGNORE_CONST;
        cur.accept(this);
    }

    const(char)* mangleFunctionType(TypeFunction type, bool needthis = false, bool noreturn = false)
    {
        scope VisualCPPMangler tmp = new VisualCPPMangler(this);
        // Calling convention
        if (target.is64bit) // always Microsoft x64 calling convention
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
            case LINK.system:
            case LINK.objc:
                tmp.visit(cast(Type)type);
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
            Type rettype = type.next;
            if (type.isref)
                rettype = rettype.referenceTo();
            flags &= ~IGNORE_CONST;
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
            tmp.flags |= MANGLE_RETURN_TYPE;
            rettype.accept(tmp);
            tmp.flags &= ~MANGLE_RETURN_TYPE;
        }
        if (!type.parameterList.parameters || !type.parameterList.parameters.dim)
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
                Type t = target.cpp.parameterType(p);
                if (t.ty == Tsarray)
                {
                    error(Loc.initial, "Internal Compiler Error: unable to pass static array to `extern(C++)` function.");
                    error(Loc.initial, "Use pointer instead.");
                    assert(0);
                }
                tmp.flags &= ~IS_NOT_TOP_TYPE;
                tmp.flags &= ~IGNORE_CONST;
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
