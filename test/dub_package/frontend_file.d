#!/usr/bin/env dub
/+dub.sdl:
dependency "dmd" path="../.."
+/
import std.stdio;

// test frontend
void main()
{
    import dmd.frontend;
    import std.algorithm : canFind, each;
    import std.file : remove, tempDir, fwrite = write;
    import std.path : buildPath;

    initDMD;
    findImportPaths.each!addImport;

    auto fileName = tempDir.buildPath("d_frontend_test.d");
    scope(exit) fileName.remove;
    auto sourceCode = q{
        module foo;
        double average(int[] array)
        {
            immutable initialLength = array.length;
            double accumulator = 0.0;
            while (array.length)
            {
                // this could be also done with .front
                // with import std.array : front;
                accumulator += array[0];
                array = array[1 .. $];
            }
            return accumulator / initialLength;
        }
    };
    fileName.fwrite(sourceCode);

    auto t = fileName.parseModule;


    assert(!t.diagnostics.hasErrors);
    assert(!t.diagnostics.hasWarnings);

    t.module_.fullSemantic;
    auto generated = t.module_.prettyPrint;

    auto expected =q{module foo;
import object;
double average(int[] array)
{
    immutable immutable(uint) initialLength = array.length;
    double accumulator = 0.00000;
    for (; array.length;)
    {
        {
            accumulator += cast(double)array[0];
            array = array[1..__dollar];
        }
    }
    return accumulator / cast(double)initialLength;
}
};
    assert(generated.canFind(expected));
}
