#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd:full" path="../.."
+/

void main()
{
    import dmd.frontend;

    import std.algorithm : each, canFind;
    import std.file : tempDir;
    import std.path : buildPath;
    import std.process : execute;

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

    // generate object file from module
    auto moduleDir = tempDir;
    auto objFile = "test.d";
    t.module_.writeModuleAsObject(moduleDir, objFile);

    // check whether codegen for 'foo' function was successful
    auto result = execute(["objdump", "-d", moduleDir.buildPath(objFile)]);
    assert(result.status == 0);
    assert(result.output.canFind("<_D4test3fooFZv>:"));
}

void writeModuleAsObject(M)(M m, string moduleDir, string moduleFile)
{
    import dmd.gluelayer : backend_init, backend_term, genObjFile, obj_start, obj_end;
    import dmd.inline : inlineScanModule;
    import dmd.lib : Library;
    import std.string : toStringz;

    backend_init();

    m.inlineScanModule();

    auto objName = m.srcfile.toChars();

    auto library = Library.factory();
    library.setFilename(moduleDir, moduleFile);

    // generate object file
    obj_start(objName);
    m.genObjFile(false);
    obj_end(library, objName);
    library.write();

    backend_term();
}
