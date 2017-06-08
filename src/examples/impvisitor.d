module examples.impvisitor;

import ddmd.astbase;
import ddmd.permissivevisitor;
import ddmd.transitivevisitor;

import ddmd.tokens;
import ddmd.root.outbuffer;

import core.stdc.stdio;

class ImportVisitor2 : TransitiveVisitor
{
    alias visit = super.visit;

    override void visit(ASTBase.Import imp)
    {
        if (imp.isstatic)
            printf("static ");

        printf("import ");

        if (imp.packages && imp.packages.dim)
            foreach (const pid; *imp.packages)
                printf("%s.", pid.toChars());

        printf("%s", imp.id.toChars());

        if (imp.names.dim)
        {
            printf(" : ");
            foreach (const i, const name; imp.names)
            {
                if (i)
                    printf(", ");
                 printf("%s", name.toChars());
            }
        }

        printf(";");
        printf("\n");

    }
}

class ImportVisitor : PermissiveVisitor
{
    alias visit = super.visit;

    override void visit(ASTBase.Module m)
    {
        foreach (s; *m.members)
        {
            s.accept(this);
        }
    }

    override void visit(ASTBase.Import i)
    {
        printf("import %s", i.toChars());
    }

    override void visit(ASTBase.ImportStatement s)
    {
            foreach (imp; *s.imports)
            {
                imp.accept(this);
            }
    }
}
