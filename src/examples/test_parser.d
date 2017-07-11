import std.stdio;
import std.file;

import ddmd.parse;
import ddmd.astbase;
import ddmd.astcodegen;

import examples.impvisitor;
import ddmd.transitivevisitor;

import ddmd.id;
import ddmd.globals;
import ddmd.identifier;

import core.memory;

void main()
{

    GC.disable();
    string path = "../../phobos/std/";
    string regex = "*.d";

    alias AST = ASTBase;

    auto dFiles = dirEntries(path, regex, SpanMode.depth);
    foreach (f; dFiles)
    {
        string fn = f.name;
        //writeln("Processing ", fn);

        Id.initialize();
        global._init();
        global.params.isLinux = true;
        global.params.is64bit = (size_t.sizeof == 8);
        global.params.useUnitTests = true;
        AST.Type._init();

        auto id = Identifier.idPool(fn);
        auto m = new AST.Module(&(fn.dup)[0], id, false, false);
        auto input = readText(fn);

        auto m1 = new ASTCodegen.Module(&(fn.dup)[0], id, false, false);

        writeln("Starting parsing with ASTBase");
        scope p = new Parser!AST(m, input, false);
        p.nextToken();
        m.members = p.parseModule();

        scope vis = new TransitiveVisitor!AST();
        m.accept(vis);

        writeln("Finished parsing with ASTBase");
        writeln("===================================================");
        writeln("Starting parsing with ASTCodegen");

        scope pc = new Parser!ASTCodegen(m1, input, false);
        pc.nextToken();
        m1.members = pc.parseModule();

        scope vis2 = new TransitiveVisitor!ASTCodegen();
        m1.accept(vis2);

        //writeln("Finished!");
    }
}
