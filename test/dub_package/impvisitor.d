#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../.."
+/

import dmd.permissivevisitor;
import dmd.transitivevisitor;

import dmd.tokens;
import dmd.common.outbuffer;

import core.stdc.stdio;

extern(C++) class ImportVisitor2(AST) : ParseTimeTransitiveVisitor!AST
{
    alias visit = ParseTimeTransitiveVisitor!AST.visit;

    override void visit(AST.Import imp)
    {
        if (imp.isstatic)
            printf("static ");

        printf("import ");

        foreach (const pid; imp.packages)
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

void main()
{
    import std.stdio;
    import std.string : toStringz;
    import std.file;
    import std.path : buildPath, dirName;

    import dmd.parse;
    import dmd.astbase;

    import dmd.id;
    import dmd.globals;
    import dmd.identifier;
    import dmd.target;

    import core.memory;

    GC.disable();
    string path = __FILE_FULL_PATH__.dirName.buildPath("../../../phobos/std/");
    string regex = "*.d";

    auto dFiles = dirEntries(path, regex, SpanMode.depth);
    foreach (f; dFiles)
    {
        string fn = f.name;
        //writeln("Processing ", fn);

        Id.initialize();
        global._init();
        target.os = Target.OS.linux;
        target.is64bit = (size_t.sizeof == 8);
        global.params.useUnitTests = true;
        ASTBase.Type._init();

        auto id = Identifier.idPool(fn);
        auto m = new ASTBase.Module(fn.toStringz, id, false, false);
        auto file = File(fn, "rb");
        // Create a buffer with four '\0' past the end for lexer
        auto input = cast(char[]) new ubyte[cast(size_t) file.size() + 4];
        input = file.rawRead(input);

        //writeln("Started parsing...");
        scope p = new Parser!ASTBase(m, input, false);
        p.nextToken();
        m.members = p.parseModule();
        //writeln("Finished parsing. Starting transitive visitor");

        scope vis = new ImportVisitor2!ASTBase();
        m.accept(vis);

        //writeln("Finished!");
    }
}
