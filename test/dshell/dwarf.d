import dshell;

import std.algorithm;
import std.file;
import std.process;

import std.conv;

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
    auto sysObjdump = executeShell("objdump --version");
    if (sysObjdump.status)
        return DISABLED;
    // DWARF 3 (and 4) support has been implemented in version 2.20 (2.20.51.0.1)
    try
    {
        if(sysObjdump.output.split("\n")[0][$ - 4 .. $].to!double < 2.20)
            return DISABLED;
    }
    catch (ConvException ce)
    {
        // The conversion failed, then it's definitively an old version (or a too new)
        return DISABLED;
    }

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
        run("$DMD -m$MODEL -of" ~ exe ~ "$EXE -conf= -fPIE -g " ~ getExtraArgs(path)
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

string getExtraArgs(string dfile)
{
    string result;
    bool begin;

    auto f = File(dfile, "r");

    foreach (line; f.byLine)
    {

        if (line.length < 2)
            continue;

        if (line.startsWith("/*"))
        {
            begin = true;
        }
        
        if (begin)
        {
            string[] args = line.split(":").to!(string[]);
            if (args.length == 2)
            {
                switch (args[0])
                {
                    case "EXTRA_ARGS":
                        result ~= args[1];
                        break;
                    default:
                        break;
                }
            }

            if (line.indexOf("*/") != -1)
            {
                break;
            }
        }
    }
    f.close();
    return result;
}
