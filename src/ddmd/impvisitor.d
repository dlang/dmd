module ddmd.impvisitor;

import ddmd.astbasevisitor;
import ddmd.tokens;
import ddmd.root.outbuffer;

import core.stdc.stdio;

class ImportVisitor(AST) : PermissiveVisitor!AST
{
    alias visit = PermissiveVisitor!AST.visit;
    OutBuffer* buf;

    this(OutBuffer* buf)
    {
        this.buf = buf;
    }

    void visitModuleMembers(AST.Dsymbols* members)
    {
        foreach (s; *members)
        {
            s.accept(this);
        }
    }

    override void visit(AST.Import i)
    {
        buf.printf("%s", i.toChars());
    }

    override void visit(AST.ImportStatement s)
    {
            foreach (imp; *s.imports)
            {
                imp.accept(this);
            }
    }

    override void visit(AST.FuncDeclaration fd)
    {
        fd.fbody.accept(this);
    }

    override void visit(AST.ClassDeclaration cd)
    {
        foreach (mem; *cd.members)
        {
            mem.accept(this);
        }
    }

    override void visit(AST.StructDeclaration sd)
    {
        foreach (mem; *sd.members)
        {
            mem.accept(this);
        }
    }

    override void visit(AST.CompoundStatement s)
    {
        foreach (sx; *s.statements)
        {
            sx.accept(this);
        }
    }

    override void visit(AST.ExpStatement s)
    {
        if (s.exp && s.exp.op == TOKdeclaration)
            (cast(AST.DeclarationExp)s.exp).declaration.accept(this);
    }

    override void visit(AST.IfStatement s)
    {
        if (s.ifbody)
            s.ifbody.accept(this);
        if (s.elsebody)
            s.elsebody.accept(this);
    }

    override void visit(AST.ScopeStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(AST.WhileStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(AST.DoStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(AST.ForStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(AST.ForeachStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(AST.SwitchStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(AST.CaseStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(AST.DefaultStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(AST.SynchronizedStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(AST.WithStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(AST.TryCatchStatement s)
    {
        if (s._body)
            s._body.accept(this);

        foreach (c; *s.catches)
        {
            visit(c);
        }
    }

    void visit(AST.Catch c)
    {
        if (c.handler)
            c.handler.accept(this);
    }

    override void visit(AST.TryFinallyStatement s)
    {
        s._body.accept(this);
        s.finalbody.accept(this);
    }

    override void visit(AST.OnScopeStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(AST.LabelStatement s)
    {
         if (s.statement)
            s.statement.accept(this);
    }
}
