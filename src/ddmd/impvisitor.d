module ddmd.impvisitor;

import ddmd.astbase;
import ddmd.permissivevisitor;
import ddmd.tokens;
import ddmd.root.outbuffer;

import core.stdc.stdio;

class ImportVisitor : PermissiveVisitor
{
    alias visit = super.visit;
    OutBuffer* buf;

    this(OutBuffer* buf)
    {
        this.buf = buf;
    }

    void visitModuleMembers(ASTBase.Dsymbols* members)
    {
        foreach (s; *members)
        {
            s.accept(this);
        }
    }

    override void visit(ASTBase.Import i)
    {
        buf.printf("%s", i.toChars());
    }

    override void visit(ASTBase.ImportStatement s)
    {
            foreach (imp; *s.imports)
            {
                imp.accept(this);
            }
    }

    override void visit(ASTBase.FuncDeclaration fd)
    {
        fd.fbody.accept(this);
    }

    override void visit(ASTBase.ClassDeclaration cd)
    {
        foreach (mem; *cd.members)
        {
            mem.accept(this);
        }
    }

    override void visit(ASTBase.StructDeclaration sd)
    {
        foreach (mem; *sd.members)
        {
            mem.accept(this);
        }
    }

    override void visit(ASTBase.CompoundStatement s)
    {
        foreach (sx; *s.statements)
        {
            sx.accept(this);
        }
    }

    override void visit(ASTBase.ExpStatement s)
    {
        if (s.exp && s.exp.op == TOKdeclaration)
            (cast(ASTBase.DeclarationExp)s.exp).declaration.accept(this);
    }

    override void visit(ASTBase.IfStatement s)
    {
        if (s.ifbody)
            s.ifbody.accept(this);
        if (s.elsebody)
            s.elsebody.accept(this);
    }

    override void visit(ASTBase.ScopeStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(ASTBase.WhileStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.DoStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.ForStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.ForeachStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.SwitchStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.CaseStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(ASTBase.DefaultStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(ASTBase.SynchronizedStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.WithStatement s)
    {
        if (s._body)
            s._body.accept(this);
    }

    override void visit(ASTBase.TryCatchStatement s)
    {
        if (s._body)
            s._body.accept(this);

        foreach (c; *s.catches)
        {
            visit(c);
        }
    }

    void visit(ASTBase.Catch c)
    {
        if (c.handler)
            c.handler.accept(this);
    }

    override void visit(ASTBase.TryFinallyStatement s)
    {
        s._body.accept(this);
        s.finalbody.accept(this);
    }

    override void visit(ASTBase.OnScopeStatement s)
    {
        s.statement.accept(this);
    }

    override void visit(ASTBase.LabelStatement s)
    {
         if (s.statement)
            s.statement.accept(this);
    }
}
