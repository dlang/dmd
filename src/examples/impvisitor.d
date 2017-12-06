module examples.impvisitor;

import ddmd.permissivevisitor;
import ddmd.transitivevisitor;

import ddmd.tokens;
import ddmd.root.outbuffer;

import core.stdc.stdio;

extern(C++) class ImportVisitor2(AST) : TransitiveVisitor!AST
{
    alias visit = TransitiveVisitor!AST.visit;

    override void visit(AST.Import imp)
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

extern(C++) class ImportVisitor(AST) : PermissiveVisitor!AST
{
    alias visit = PermissiveVisitor!AST.visit;

    override void visit(AST.Module m)
    {
        foreach (s; *m.members)
        {
            s.accept(this);
        }
    }

    override void visit(AST.Import i)
    {
        printf("import %s", i.toChars());
    }

    override void visit(AST.ImportStatement s)
    {
            foreach (imp; *s.imports)
            {
                imp.accept(this);
            }
    }
}
