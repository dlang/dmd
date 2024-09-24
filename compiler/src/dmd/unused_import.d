import core.stdc.stdio;

import dmd.dimport : Import;
import dmd.dmodule : Module;
import dmd.errors : warning;
import dmd.visitor : SemanticTimeTransitiveVisitor;

void checkUnusedImports(Module m)
{
    auto v = new UnusedImportVisitor();
    m.accept(v);
}

extern(C++) class UnusedImportVisitor : SemanticTimeTransitiveVisitor
{
    alias visit = typeof(super).visit;

    override void visit(Import imp)
    {
        if (!imp.used)
        {
            string s;
            foreach (const packageId; imp.packages)
                    s ~= packageId.toString() ~ ".";
            s ~= imp.id.toString() ~ '\0';

            warning(imp.loc, "Import `%s` is unused", s.ptr);
        }
    }
}
