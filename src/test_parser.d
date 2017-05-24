import std.stdio;
import std.file;

import ddmd.parse;
import ddmd.astbase;

import ddmd.id;
import ddmd.globals;

void main()
{
    string path = "../../phobos/std/";
    string regex = "*.d";

    auto dFiles = dirEntries(path, regex, SpanMode.depth);
    foreach (d; dFiles)
    {
        writeln("Processing:", d.name);

        Id.initialize();
        global._init();
        global.params.isLinux = true;
        global.params.is64bit = (size_t.sizeof == 8);
        ASTBase.Type._init();

        string content = readText(d.name);

        scope p = new Parser!ASTBase(null, content, false);
        p.nextToken();
        p.parseModule();

        writeln("Finished!");
    }
}
