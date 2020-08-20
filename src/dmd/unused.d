module dmd.unused;

import core.stdc.stdio;

import dmd.dmodule;
import dmd.arraytypes;
import dmd.errors;
import dmd.declaration;

void printUnusedSymbolStats(const ref Modules modules)
{
    // auto tab = Module.modules.tab;
    // printf("%ld\n", tab.length);

    // pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", typeof(tab));

    // foreach (const keyValue; tab.asRange)
    // {
    //     pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", typeof(keyValue.value));
    //     if (const ad = cast(const AliasDeclaration)keyValue.value)
    //     {
    //         ad.loc.warning("ad:%s", keyValue.value.toChars());
    //     }
    // }

    foreach (const m; modules)
    {
        m.loc.warning("module:%s\n", m.toChars());
        if (m.decldefs)
        {
            printf("decldefs:%p\n", m.decldefs);
            foreach (const decl; *(m.decldefs))           // top-level declarations
            {
                pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", typeof(decl));
                decl.loc.warning("decl:%s\n", decl.toChars());
            }
        }
    }
}
