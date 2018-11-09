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
    import std.format : format;
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
    auto generated = t.module_.prettyPrint.toUnixLineEndings();

    // For some reason the floating point number in the pretty printed code  is
    // different on Windows and on Posix. It might be due to different C
    // standard libraries that are most likely used to convert the floating
    // point number to a string.
    version (Windows)
        enum accumulator = "0.000000";
    else
        enum accumulator = "0.00000";

    enum expected =q{module foo;
import object;
double average(int[] array)
{
    immutable immutable(uint) initialLength = array.length;
    double accumulator = %s;
    for (; array.length;)
    {
        {
            accumulator += cast(double)array[0];
            array = array[1..__dollar];
        }
    }
    return accumulator / cast(double)initialLength;
}
}.format(accumulator);

    assert(generated.canFind(expected));
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
