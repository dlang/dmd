#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../.."
+/
import std.stdio;

// add import paths
void addImports(T)(T path)
{
    import dmd.globals : global;
    import dmd.arraytypes : Strings;

    stderr.writefln("addImport: %s", path);

    Strings* res = new Strings();
    foreach (p; path)
    {
        import std.string : toStringz;
        Strings* a = new Strings();
        a.push(p.toStringz);
        res.append(a);
    }
    global.path = res;
}

// finds a dmd.conf and parses it for import paths
auto findImportPaths()
{
    import std.file : exists, getcwd;
    import std.string : fromStringz, toStringz;
    import std.path : buildPath, buildNormalizedPath, dirName;
    import std.process : env = environment, execute;
    import dmd.dinifile : findConfFile;
    import dmd.errors : fatal;
    import std.algorithm, std.range, std.regex;

    auto dmdEnv = env.get("DMD", "dmd");
    auto whichDMD = execute(["which", dmdEnv]);
    if (whichDMD.status != 0)
    {
        stderr.writeln("Can't find DMD.");
        fatal;
    }

    immutable dmdFilePath = whichDMD.output;
    string iniFile;

    if (dmdEnv.canFind("ldmd"))
    {
        immutable ldcConfig = "ldc2.conf";
        immutable binDir = dmdFilePath.dirName;
        // https://wiki.dlang.org/Using_LDC
        auto ldcConfigs = [
            getcwd.buildPath(ldcConfig),
            binDir.buildPath(ldcConfig),
            binDir.dirName.buildPath("etc", ldcConfig),
            "~/.ldc".buildPath(ldcConfig),
            binDir.buildPath("etc", ldcConfig),
            binDir.buildPath("etc", "ldc", ldcConfig),
            "/etc".buildPath(ldcConfig),
            "/etc/ldc".buildPath(ldcConfig),
        ].filter!exists;
        assert(!ldcConfigs.empty, "No ldc2.conf found");
        iniFile = ldcConfigs.front;
    }
    else
    {
        auto f = findConfFile(dmdFilePath.toStringz, "dmd.conf");
        iniFile = f.fromStringz.idup;
        assert(iniFile.exists, "No dmd.conf found.");
    }

    return File(iniFile, "r")
        .byLineCopy
        .map!(l => l.matchAll(`-I[^ "]+`.regex)
                    .joiner
                    .map!(a => a.drop(2)
                                .replace("%@P%", dmdFilePath.dirName)
                                .replace("%%ldcbinarypath%%", dmdFilePath.dirName)))
        .joiner
        .array
        .sort
        .uniq
        .map!buildNormalizedPath;
}

// test frontend
void main()
{
    import dmd.astcodegen : ASTCodegen;
    import dmd.dmodule : Module;
    import dmd.globals : global, Loc;
    import dmd.frontend : initDMD;
    import dmd.parse : Parser;
    import dmd.statement : Identifier;
    import dmd.tokens : TOKeof;
    import dmd.id : Id;

    initDMD;
    findImportPaths.addImports;

    auto parse(Module m, string code)
    {
        scope p = new Parser!ASTCodegen(m, code, false);
        p.nextToken; // skip the initial token
        auto members = p.parseModule;
        assert(!p.errors, "Parsing error occurred.");
        return members;
    }

    Identifier id = Identifier.idPool("test");
    auto m = new Module("test.d", id, 0, 0);
    m.members = parse(m, q{
        void foo()
        {
            foreach (i; 0..10) {}
        }
    });

    void semantic()
    {
        import dmd.dsymbolsem : dsymbolSemantic;
        import dmd.semantic2;
        import dmd.semantic3;

        m.importedFrom = m;
        m.importAll(null);
        m.dsymbolSemantic(null);
        m.semantic2(null);
        m.semantic3(null);
    }
    semantic();

    auto prettyPrint()
    {
        import dmd.root.outbuffer: OutBuffer;
        import dmd.hdrgen : HdrGenState, PrettyPrintVisitor;

        OutBuffer buf = { doindent: 1 };
        HdrGenState hgs = { fullDump: 1 };
        scope PrettyPrintVisitor ppv = new PrettyPrintVisitor(&buf, &hgs);
        m.accept(ppv);
        return buf;
    }
    auto buf = prettyPrint();

    auto expected =q{import object;
void foo()
{
    {
        int __key3 = 0;
        int __limit4 = 10;
        for (; __key3 < __limit4; __key3 += 1)
        {
            int i = __key3;
        }
    }
}
};
    import std.string : replace, fromStringz;
    auto generated = buf.extractData.fromStringz.replace("\t", "    ");
    assert(expected == generated, generated);
}
