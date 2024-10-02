import core.stdc.stdio;

import dmd.cond;
import dmd.dimport;
import dmd.dmodule;
import dmd.dtemplate;
import dmd.errors;
import dmd.visitor;
import dmd.attrib;

void checkUnusedImports(Module m)
{
    auto v = new UnusedImportVisitor();
    m.accept(v);
}

extern(C++) class UnusedImportVisitor : SemanticTimeTransitiveVisitor
{
    alias visit = typeof(super).visit;

    // skip template declarations as it is tricky or even
    // impossible in same cases to know whether the import
    // is accessed or not. Issuing warning for specific
    // template instances is easier and less error prone.
    override void visit(TemplateDeclaration ) {}
    override void visit(ConditionalDeclaration) {}
    override void visit(TemplateInstance ti) { printf("ti = %s\n", ti.toChars()); }

    override void visit(Import imp)
    {
        if (!imp.used && !imp.isstatic)
        {
            string s;
            foreach (const packageId; imp.packages)
                    s ~= packageId.toString() ~ ".";
            s ~= imp.id.toString() ~ '\0';

            warning(imp.loc, "Import `%s` is unused", s.ptr);
        }
    }
}
