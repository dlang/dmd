import dshell;

import std.algorithm;
import std.file;
import std.process;

int main()
{
    version(DigitalMars) { }
    else
    {
        writeln("Skipping dwarf.d for non-DMD compilers.");
        return DISABLED;
    }

    version(Windows)
    {
        writeln("Skipping dwarf.d for Windows.");
        return DISABLED;
    }

    version(Windows)
        immutable slash = "\\";
    else
        immutable slash = "/";


    // If the Unix system doesn't have objdump, disable the tests
    auto sysHasObjdump = executeShell("objdump --help");
    if (sysHasObjdump.status)
        return DISABLED;

    immutable extra_dwarf_dir = EXTRA_FILES ~ slash ~ "dwarf" ~ slash;
    bool failed;

    // test them all
    foreach (string path; dirEntries(extra_dwarf_dir, SpanMode.shallow))
    {
        if (!isFile(path) || extension(path) != ".d")
            continue;

        // retrieve the filename without the extension
        auto filename = baseName(stripExtension(path));


        string exe = OUTPUT_BASE ~ slash ~ filename;
        run("$DMD -m$MODEL -of" ~ exe ~ "$EXE -conf= -fPIE -g"
            ~ " -I" ~ extra_dwarf_dir ~ " " ~ path);

        // Write objdump result to a file
        auto objdump = exe ~ ".objdump";

        auto objdump_file = File(objdump, "w");
        run("objdump -W " ~ exe, objdump_file);
        objdump_file.close();

        // Objdump excepted results
        string excepted_results_file = extra_dwarf_dir ~ "excepted_results"
            ~ slash ~ filename ~ ".txt";

        if (!exists(excepted_results_file))
            assert(0, "DWARF tests must have a .txt file in the `excepted_results`"
                ~ " folder which contains the DWARF dump info");

        // Read file result as a string
        auto result = cast(string)readText(objdump);

        string failmsg;

        foreach (line; File(excepted_results_file).byLine)
        {
            if (!canFind(result, line))
            {
                failmsg ~= filename ~ ": Couln't find `" ~ line
                    ~ "` in the DWARF dump info.\n";
                failed = true;
            }
        }

        if (failmsg)
        {
            // Writes the result into stdout for the CI machines.
            writeln(result);
            write(failmsg);
        }
    }

    return failed;
}

