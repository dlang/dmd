/***
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * This modules implements the serialization of a lambda function. The serialization
 * is computed by visiting the abstract syntax subtree of the given lambda function.
 * The serialization is a string which contains the type of the parameters and the
 * string represantation of the lambda expression.
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/lamdbacomp.d, _lambdacomp.d)
 * Documentation:  https://dlang.org/phobos/dmd_lambdacomp.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/lambdacomp.d
 */

module dmd.lambdacomp;

import core.stdc.stdio;
import core.stdc.string;

import dmd.declaration;
import dmd.denum;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.expression;
import dmd.func;
import dmd.dmangle;
import dmd.mtype;
import dmd.root.outbuffer;
import dmd.root.stringtable;
import dmd.dscope;
import dmd.statement;
import dmd.tokens;
import dmd.visitor;

enum LOG = false;

/**
 * The type of the visited expression.
 */
private enum ExpType
{
    None,
    EnumDecl,
    Arg
}

/**
 * Compares 2 lambda functions described by their serialization.
 *
 * Params:
 *  l1 = first lambda to be compared
 *  l2 = second lambda to be compared
 *  sc = the scope where the lambdas are compared
 *
 * Returns:
 *  `true` if the 2 lambda functions are equal, `false` otherwise
 */
bool isSameFuncLiteral(FuncLiteralDeclaration l1, FuncLiteralDeclaration l2, Scope* sc)
{
    if (auto ser1 = getSerialization(l1, sc))
    {
        //printf("l1 serialization: %s\n", &ser1[0]);
        if (auto ser2 = getSerialization(l2, sc))
        {
            //printf("l2 serialization: %s\n", &ser2[0]);
            if (ser1 == ser2)
                return true;
        }
    }
    return false;
}

/**
 * Computes the string representation of a
 * lambda function described by the subtree starting from a
 * $(REF dmd, func, FuncLiteralDeclaration).
 *
 * Limitations: only IntegerExps, Enums and function
 * arguments are supported in the lambda function body. The
 * arguments may be of any type (basic types, user defined types),
 * except template instantiations. If a function call, a local
 * variable or a template instance is encountered, the
 * serialization is dropped and the function is considered
 * uncomparable.
 *
 * Params:
 *  fld = the starting AST node for the lambda function
 *  sc = the scope in which the lambda function is located
 *
 * Returns:
 *  The serielization of `fld`.
 */
private string getSerialization(FuncLiteralDeclaration fld, Scope* sc)
{
    scope serVisitor = new SerializeVisitor(fld.parent._scope);
    fld.accept(serVisitor);
    const len = serVisitor.buf.offset;
    if (len == 0)
        return null;

    return cast(string)serVisitor.buf.extractChars()[0 .. len];
}

private extern (C++) class SerializeVisitor : SemanticTimeTransitiveVisitor
{
private:
    StringTable arg_hash;
    Scope* sc;
    ExpType et;
    Dsymbol d;

public:
    OutBuffer buf;
    alias visit = SemanticTimeTransitiveVisitor.visit;

    this(Scope* sc)
    {
        this.sc = sc;
    }

    /**
     * Entrypoint of the SerializeVisitor.
     *
     * Params:
     *     fld = the lambda function for which the serialization is computed
     */
    override void visit(FuncLiteralDeclaration fld)
    {
        assert(fld.type.ty != Terror);
        static if (LOG)
            printf("FuncLiteralDeclaration: %s\n", fld.toChars());

        TypeFunction tf = cast(TypeFunction)fld.type;
        uint dim = cast(uint)Parameter.dim(tf.parameterList.parameters);
        // Start the serialization by printing the number of
        // arguments the lambda has.
        buf.printf("%d:", dim);

        arg_hash._init(dim + 1);
        // For each argument
        foreach (i; 0 .. dim)
        {
            auto fparam = tf.parameterList[i];
            if (fparam.ident !is null)
            {
                // the variable name is introduced into a hashtable
                // where the key is the user defined name and the
                // value is the cannonically name (arg0, arg1 ...)
                auto key = fparam.ident.toString();
                OutBuffer value;
                value.writestring("arg");
                value.print(i);
                arg_hash.insert(key, value.extractChars);
                // and the type of the variable is serialized.
                fparam.accept(this);
            }
        }

        // Now the function body can be serialized.
        ReturnStatement rs = fld.fbody.endsWithReturnStatement();
        if (rs && rs.exp)
        {
            rs.exp.accept(this);
        }
        else
        {
            buf.offset = 0;
        }
    }

    override void visit(DotIdExp exp)
    {
        static if (LOG)
            printf("DotIdExp: %s\n", exp.toChars());
        if (buf.offset == 0)
            return;

        // First we need to see what kind of expression e1 is.
        // It might an enum member (enum.value)  or the field of
        // an argument (argX.value) if the argument is an aggregate
        // type. This is reported through the et variable.
        exp.e1.accept(this);
        if (buf.offset == 0)
            return;

        if (et == ExpType.EnumDecl)
        {
            Dsymbol s = d.search(exp.loc, exp.ident);
            if (s)
            {
                if (auto em = s.isEnumMember())
                {
                    em.value.accept(this);
                }
                et = ExpType.None;
                d = null;
            }
        }

        else if (et == ExpType.Arg)
        {
            buf.setsize(buf.offset -1);
            buf.writeByte('.');
            buf.writestring(exp.ident.toString());
            buf.writeByte('_');
        }
    }

    bool checkArgument(const(char)* id)
    {
        // The identifier may be an argument
        auto stringtable_value = arg_hash.lookup(id, strlen(id));
        if (stringtable_value)
        {
            // In which case we need to update the serialization accordingly
            const(char)* gen_id = cast(const(char)*)stringtable_value.ptrvalue;
            buf.writestring(gen_id);
            buf.writeByte('_');
            et = ExpType.Arg;
            return true;
        }
        return false;
    }

    override void visit(IdentifierExp exp)
    {
        static if (LOG)
            printf("IdentifierExp: %s\n", exp.toChars());

        if (buf.offset == 0)
            return;

        auto id = exp.ident.toChars();

        // If it's not an argument
        if (!checkArgument(id))
        {
            // we must check what the identifier expression is.
            Dsymbol scopesym;
            Dsymbol s = sc.search(exp.loc, exp.ident, &scopesym);
            if (s)
            {
                auto v = s.isVarDeclaration();
                // If it's a VarDeclaration, it must be a manifest constant
                if (v && (v.storage_class & STC.manifest))
                {
                    v.getConstInitializer.accept(this);
                }
                else if (auto em = s.isEnumDeclaration())
                {
                    d = em;
                    et = ExpType.EnumDecl;
                }
                else if (auto fd = s.isFuncDeclaration())
                {
                    writeMangledName(fd);
                }
                // For anything else, the function is deemed uncomparable
                else
                {
                    buf.reset();
                }
            }
            // If it's an unknown symbol, consider the function incomparable
            else
            {
                buf.reset();
            }
        }
    }

    override void visit(DotVarExp exp)
    {
        static if (LOG)
            printf("DotVarExp: %s, var: %s, e1: %s\n", exp.toChars(),
                    exp.var.toChars(), exp.e1.toChars());

        exp.e1.accept(this);
        if (buf.offset == 0)
            return;

        buf.setsize(buf.offset -1);
        buf.writeByte('.');
        buf.writestring(exp.var.toChars());
        buf.writeByte('_');
    }

    override void visit(VarExp exp)
    {
        static if (LOG)
            printf("VarExp: %s, var: %s\n", exp.toChars(), exp.var.toChars());

        if (buf.offset == 0)
            return;

        auto id = exp.var.ident.toChars();
        if (!checkArgument(id))
        {
            buf.offset = 0;
        }
    }

    // serialize function calls
    override void visit(CallExp exp)
    {
        static if (LOG)
            printf("CallExp: %s\n", exp.toChars());

        if (buf.offset == 0)
            return;

        if (!exp.f)
        {
            exp.e1.accept(this);
        }
        else
        {
            writeMangledName(exp.f);
        }

        buf.writeByte('(');
        foreach (arg; *(exp.arguments))
        {
            arg.accept(this);
        }
        buf.writeByte(')');
    }

    override void visit(UnaExp exp)
    {
        if (buf.offset == 0)
            return;

        buf.writeByte('(');
        buf.writestring(Token.toString(exp.op));
        exp.e1.accept(this);
        if (buf.offset != 0)
            buf.writestring(")_");
    }

    override void visit(IntegerExp exp)
    {
        if (buf.offset == 0)
            return;

        buf.print(exp.toInteger());
        buf.writeByte('_');
    }

    override void visit(RealExp exp)
    {
        if (buf.offset == 0)
            return;

        buf.writestring(exp.toChars());
        buf.writeByte('_');
    }

    override void visit(BinExp exp)
    {
        static if (LOG)
            printf("BinExp: %s\n", exp.toChars());

        if (buf.offset == 0)
            return;

        buf.writeByte('(');
        buf.writestring(Token.toChars(exp.op));

        exp.e1.accept(this);
        if (buf.offset == 0)
            return;

        exp.e2.accept(this);
        if (buf.offset == 0)
            return;

        buf.writeByte(')');
    }

    override void visit(TypeBasic t)
    {
        buf.writestring(t.dstring);
        buf.writeByte('_');
    }

    void writeMangledName(Dsymbol s)
    {
        if (s)
        {
            OutBuffer mangledName;
            mangleToBuffer(s, &mangledName);
            buf.writestring(mangledName.peekSlice);
            buf.writeByte('_');
        }
        else
            buf.reset();
    }

    private bool checkTemplateInstance(T)(T t)
        if (is(T == TypeStruct) || is(T == TypeClass))
    {
        if (t.sym.parent && t.sym.parent.isTemplateInstance())
        {
            buf.reset();
            return true;
        }
        return false;
    }

    override void visit(TypeStruct t)
    {
        static if (LOG)
            printf("TypeStruct: %s\n", t.toChars);

        if (!checkTemplateInstance!TypeStruct(t))
            writeMangledName(t.sym);
    }

    override void visit(TypeClass t)
    {
        static if (LOG)
            printf("TypeClass: %s\n", t.toChars());

        if (!checkTemplateInstance!TypeClass(t))
            writeMangledName(t.sym);
    }

    override void visit(Parameter p)
    {
        if (p.type.ty == Tident
            && (cast(TypeIdentifier)p.type).ident.toString().length > 3
            && strncmp((cast(TypeIdentifier)p.type).ident.toChars(), "__T", 3) == 0)
        {
            buf.writestring("none_");
        }
        else
            visitType(p.type);
    }

    override void visit(StructLiteralExp e) {
        static if (LOG)
            printf("StructLiteralExp: %s\n", e.toChars);

        auto ty = cast(TypeStruct)e.stype;
        if (ty)
        {
            writeMangledName(ty.sym);
            auto dim = e.elements.dim;
            foreach (i; 0..dim)
            {
                auto elem = (*e.elements)[i];
                if (elem)
                    elem.accept(this);
                else
                    buf.writestring("null_");
            }
        }
        else
            buf.reset();
    }

    override void visit(ArrayLiteralExp) { buf.reset(); }
    override void visit(AssocArrayLiteralExp) { buf.reset(); }
    override void visit(CompileExp) { buf.reset(); }
    override void visit(ComplexExp) { buf.reset(); }
    override void visit(DeclarationExp) { buf.reset(); }
    override void visit(DefaultInitExp) { buf.reset(); }
    override void visit(DsymbolExp) { buf.reset(); }
    override void visit(ErrorExp) { buf.reset(); }
    override void visit(FuncExp) { buf.reset(); }
    override void visit(HaltExp) { buf.reset(); }
    override void visit(IntervalExp) { buf.reset(); }
    override void visit(IsExp) { buf.reset(); }
    override void visit(NewAnonClassExp) { buf.reset(); }
    override void visit(NewExp) { buf.reset(); }
    override void visit(NullExp) { buf.reset(); }
    override void visit(ObjcClassReferenceExp) { buf.reset(); }
    override void visit(OverExp) { buf.reset(); }
    override void visit(ScopeExp) { buf.reset(); }
    override void visit(StringExp) { buf.reset(); }
    override void visit(SymbolExp) { buf.reset(); }
    override void visit(TemplateExp) { buf.reset(); }
    override void visit(ThisExp) { buf.reset(); }
    override void visit(TraitsExp) { buf.reset(); }
    override void visit(TupleExp) { buf.reset(); }
    override void visit(TypeExp) { buf.reset(); }
    override void visit(TypeidExp) { buf.reset(); }
    override void visit(VoidInitExp) { buf.reset(); }
}
