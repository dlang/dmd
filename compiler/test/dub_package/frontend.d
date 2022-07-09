#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../.."
+/
import std.stdio;

// test frontend
void main()
{
    import dmd.frontend;
    import std.algorithm : each;

    initDMD;
    findImportPaths.each!addImport;

    auto t = parseModule("test.d", q{
        void foo()
        {
            foreach (i; 0..10) {}
        }
    });

    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    t.module_.fullSemantic;
    auto generated = t.module_.prettyPrint.toUnixLineEndings();

    auto expected =q{import object;
void foo()
{
    {
        int __key2 = 0;
        int __limit3 = 10;
        for (; __key2 < __limit3; __key2 += 1)
        {
            int i = __key2;
        }
    }
}
}.toUnixLineEndings();
    assert(expected == generated, generated);
}

/**
Converts Windows line endings (`\r\n`) to Unix line endings (`\n`).

This is required because this file is stored with Unix line endings but the
`prettyPrint` function outputs Windows line endings on Windows.
*/
string toUnixLineEndings(string str)
{
    import std.string : replace;
    return str.replace("\r\n", "\n");
}
