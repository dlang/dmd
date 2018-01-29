module dmd.lambdacomp;

import core.stdc.stdio;
import core.stdc.string;

import dmd.declaration;
import dmd.denum;
import dmd.dsymbol;
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

enum ExpType
{
    None,
    EnumDecl,
    Arg
}

extern (C++) class SerializeVisitor : SemanticTimeTransitiveVisitor
{
    alias visit = SemanticTimeTransitiveVisitor.visit;
    OutBuffer buf;
    StringTable arg_hash;
    Scope* sc;
    ExpType et;
    Dsymbol d;

    this(Scope* sc)
    {
        this.sc = sc;
    }

    override void visit(FuncLiteralDeclaration fld)
    {
        if (fld.type.ty == Terror)
            return;

        TypeFunction tf = cast(TypeFunction)fld.type;
        uint dim = cast(uint)Parameter.dim(tf.parameters);
        buf.printf("%d:", dim);

        arg_hash._init(dim + 1);
        foreach (i; 0 .. dim)
        {
            auto fparam = Parameter.getNth(tf.parameters, i);
            if (fparam.ident !is null)
            {
                auto key = fparam.ident.toString().ptr;
                OutBuffer value;
                value.writestring("arg");
                value.print(i);
                arg_hash.insert(key, strlen(key), value.extractString);
                fparam.accept(this);
            }
        }

        CompoundStatement cs = fld.fbody.isCompoundStatement();
        Statement s = !cs ? fld.fbody : null;
        ReturnStatement rs = s ? s.isReturnStatement() : null;
        if (rs && rs.exp)
        {
            rs.exp.accept(this);
        }
    }

    override void visit(DotIdExp exp)
    {
        if (buf.offset == 0)
            return;

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

    override void visit(IdentifierExp exp)
    {
        if (buf.offset == 0)
            return;

        auto id = exp.ident.toChars;
        auto stringtable_value = arg_hash.lookup(id, strlen(id));
        if (stringtable_value)
        {
            const(char)* gen_id = cast(const(char)*)stringtable_value.ptrvalue;
            buf.writestring(gen_id);
            buf.writeByte('_');
            et = ExpType.Arg;
        }
        else
        {
            Dsymbol scopesym;
            Dsymbol s = sc.search(exp.loc, exp.ident, &scopesym);
            if (s)
            {
                if (auto v = s.isVarDeclaration)
                {
                    if (v.storage_class & STC.manifest)
                    {
                        v.getConstInitializer.accept(this);
                    }
                    else
                        buf.reset();
                }
                else if (auto em = s.isEnumDeclaration)
                {
                    d = em;
                    et = ExpType.EnumDecl;
                }
                else
                {
                    buf.reset();
                }
            }
        }
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

        exp.normalize();
        auto val = exp.value;
        buf.print(val);
        buf.writeByte('_');
    }

    override void visit(BinExp exp)
    {
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

    override void visit(TypeIdentifier t)
    {
        Dsymbol scopesym;
        Dsymbol s = sc.search(t.loc, t.ident, &scopesym);
        if (s && s.semanticRun == PASS.semantic3done)
        {
            OutBuffer mangledName;
            mangleToBuffer(s, &mangledName);
            buf.writestring(mangledName.peekSlice);
            buf.writeByte('_');
        }
        else
            buf.reset();
    }

    override void visit(TypeInstance t)
    {
        buf.reset();
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
}
