import dshell;

import std.algorithm;
import std.file;
import std.process;
import std.regex;
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
    version(OSX)
    {
        writeln("Skipping dwarf.d for MacOS X.");
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


    double objdumpVersion;
    try
    {
        // output examples :
        // GNU objdump 2.15
        // GNU objdump 2.17.50 [FreeBSD] 2007-07-03
        // GNU objdump (GNU Binutils) 2.36.1
        string strVer = sysObjdump.output.split("\n")[0];
        writeln("Objdump version of the machine : ", strVer);

        auto cap = matchFirst(strVer, `[0-9]+\.[0-9]+`);
        assert(cap);
        objdumpVersion = cap.hit.to!double;
    }
    catch (ConvException ce)
    {
        // The conversion failed
        return DISABLED;
    }
    writeln("Parsed objdump version of the machine : ", objdumpVersion);

    // DWARF 3 (and 4) support has been implemented in version 2.20 (2.20.51.0.1)
    if(objdumpVersion < 2.20)
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
        string[string] requirements = getRequirements(path);

        try
        {
            if (objdumpVersion < requirements["MIN_OBJDUMP_VERSION"].to!double)
            {
                writeln("Warning: test " ~ path ~ " skipped.");
                continue ;
            }
        }
        catch(Exception e) { }


        string exe = OUTPUT_BASE ~ slash ~ filename;
        run("$DMD -m$MODEL -of" ~ exe ~ "$EXE -conf= -fPIE -g " ~ requirements["EXTRA_ARGS"]
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

string[string] getRequirements(string dfile)
{
    string[string] result;
    // Initialize to an empty string to prevent RangeViolation exceptions.
    foreach (req; ["EXTRA_ARGS", "MIN_OBJDUMP_VERSION"])
        result[req] = "";

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
                result[args[0]] = args[1].strip();
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
