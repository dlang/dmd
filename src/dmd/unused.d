module dmd.unused;

import core.stdc.stdio;

import dmd.dsymbol;
import dmd.dmodule;
import dmd.arraytypes;
import dmd.errors;
import dmd.declaration;

void printUnusedSymbolStats(const ref Modules modules)
{
    static void checkMember(const Dsymbol member)
    {
        if (const ad = cast(const AliasDeclaration)member)
        {
            if (!ad.isReferenced) // TODO: exclude private functions
            {
                if (ad._import)
                    ad.loc.warning("unused imported alias %s", ad.toChars());
                else
                    ad.loc.warning("unused alias %s", ad.toChars());
            }
            else
            {
                if (ad._import)
                    ad.loc.warning("used imported alias %s", ad.toChars());
                else
                    ad.loc.warning("used alias %s", ad.toChars());
            }
        }
    }
    static void checkModule(const Module m)
    {
        if (!m.members)
            return;
        foreach (const member; *(m.members)) // top-level members
        {
            checkMember(member);
        }
    }

    foreach (const m; modules)
        checkModule(m);
}
