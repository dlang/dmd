import std.stdio;
import std.file;

import ddmd.parse;
import ddmd.astbase;

import examples.impvisitor;

import ddmd.id;
import ddmd.globals;
import ddmd.identifier;

import core.memory;

void main()
{

    GC.disable();
    string path = "../../phobos/std/";
    string regex = "*.d";

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
        ASTBase.Type._init();

        auto id = Identifier.idPool(fn);
        auto m = new ASTBase.Module(&(fn.dup)[0], id, false, false);
        auto input = readText(fn);

        //writeln("Started parsing...");
        scope p = new Parser!ASTBase(m, input, false);
        p.nextToken();
        m.members = p.parseModule();
        //writeln("Finished parsing. Starting transitive visitor");

        scope vis = new ImportVisitor2();
        m.accept(vis);

        //writeln("Finished!");
    }
}
