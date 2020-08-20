module dmd.unused;

import core.stdc.stdio;

import dmd.dmodule;
import dmd.arraytypes;
import dmd.errors;
import dmd.declaration;

void printUnusedSymbolStats(ref Modules modules)
{
    static void checkModule(Module m)
    {
        if (!m.members)
            return;
        foreach (const memb; *(m.members)) // top-level members
        {
            if (const ad = cast(const AliasDeclaration)memb)
                if (!ad.isReferenced) // TODO: exclude private functions
                {
                    if (ad._import)
                        ad.loc.warning("unused imported alias %s", ad.toChars());
                    else
                        ad.loc.warning("unused alias %s", ad.toChars());
                }
        }
    }

    foreach (m; modules)
        checkModule(m);
}
