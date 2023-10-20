module semantic.imports;

import std.algorithm;
import std.typecons;

import dmd.frontend;
import dmd.dsymbol;
import dmd.astcodegen;
import dmd.common.outbuffer;

import support;

@("semantics - imported modules")
unittest
{
    initDMD();
    defaultImportPaths.each!addImport;

    auto t = parseModule!ASTCodegen("test.d", q{
        public import std.stdio;
	import std.file;
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    Tuple!(string, Visibility.Kind)[] imports;

    import std.stdio;
    t.module_.fullSemantic();

    auto vsym = t.module_.getImportVisibilities();

    foreach(i, sym; *t.module_.getImportedScopes())
    {
        if (auto im = sym.isModule())
        {
            if (im.md)
            {
                auto buf = im.md.toString();
                imports ~= tuple(buf.idup, vsym[i]);

                import core.stdc.stdlib : free;
                free(cast(void*)buf.ptr);
            }
        }
    }
    writeln(imports);
    assert(imports.any!(a => a == tuple("object", Visibility.Kind.private_))); // implicitly imported
    assert(imports.any!(a => a == tuple("std.stdio", Visibility.Kind.public_)));
    assert(imports.any!(a => a == tuple("std.file", Visibility.Kind.private_)));
    assert(!imports.any!`a[0] == "std.algorithm"`); // not imported
}
