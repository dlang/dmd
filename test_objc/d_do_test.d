module d_do_test;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.process;
import std.random;
import std.stdio;
import std.string;
import core.sys.posix.sys.wait;

void usage()
{
    write("d_do_test <input_dir> <test_name> <test_extension>\n"
          "\n"
          "   input_dir: one of: compilable, fail_compilation, runnable\n"
          "   test_name: basename of test case to run\n"
          "   test_extension: one of: d, html, or sh\n"
          "\n"
          "   example: d_do_test runnable pi d\n"
          "\n"
          "   relevant environment variables:\n"
          "      ARGS:        set to execute all combinations of\n"
          "      DMD:         compiler to use, ex: ../src/dmd\n"
          "      OS:          win32, linux, freebsd, osx\n"
          "      RESULTS_DIR: base directory for test results\n"
          "   windows vs non-windows portability env vars:\n"
          "      DSEP:        \\\\ or /\n"
          "      SEP:         \\ or /\n"
          "      OBJ:        .obj or .o\n"
          "      EXE:        .exe or <null>\n");
}

enum TestMode
{
    COMPILE,
    FAIL_COMPILE,
    RUN
}

struct TestArgs
{
    TestMode mode;

    bool     compileSeparately;
    string   executeArgs;
    string[] sources;
    string   permuteArgs;
    string   postScript;
    string   requiredArgs;
}

struct EnvData
{
    string all_args;
    string dmd;
    string results_dir;
    string sep;
    string dsep;
    string obj;
    string exe;
    string os;
    string model;
}

bool findTestParameter(string file, string token, ref string result)
{
    auto tokenStart = std.string.indexOf(file, token);
    if (tokenStart == -1) return false;

    auto lineEndR = std.string.indexOf(file[tokenStart .. $], "\r");
    auto lineEndN = std.string.indexOf(file[tokenStart .. $], "\n");
    auto lineEnd  = lineEndR == -1 ?
        (lineEndN == -1 ? file.length : lineEndN) :
        (lineEndN == -1 ? lineEndR    : min(lineEndR, lineEndN));

    //writeln("found ", token, " in line: ", file.length, ", ", tokenStart, ", ", tokenStart+lineEnd);
    //writeln("found ", token, " in line: '", file[tokenStart .. tokenStart+lineEnd], "'");

    result = strip(file[tokenStart+token.length .. tokenStart+lineEnd]);
    // skips the :, if present
    if (result.length > 0 && result[0] == ':')
        result = strip(result[1 .. $]);

    //writeln("arg: '", result, "'");

    return true;
}

void gatherTestParameters(ref TestArgs testArgs, string input_dir, string input_file, const ref EnvData envData)
{
    string file = cast(string)std.file.read(input_file);

    if (findTestParameter(file, "REQUIRED_ARGS", testArgs.requiredArgs) &&
        testArgs.requiredArgs.length > 0)
    {
        testArgs.requiredArgs ~= " ";
    }

    if (! findTestParameter(file, "PERMUTE_ARGS", testArgs.permuteArgs))
    {
        if (testArgs.mode != TestMode.FAIL_COMPILE)
            testArgs.permuteArgs = envData.all_args;

        string unittestJunk;
        if(!findTestParameter(file, "unittest", unittestJunk))
            testArgs.permuteArgs = replace(testArgs.permuteArgs, "-unittest", "");
    }

    // win32 doesn't support pic, nor does freebsd/64 currently
    if (envData.os == "win32" || envData.os == "freebsd")
    {
        auto index = std.string.indexOf(testArgs.permuteArgs, "-fPIC");
        if (index != -1)
            testArgs.permuteArgs = testArgs.permuteArgs[0 .. index] ~ testArgs.permuteArgs[index+5 .. $];
    }

    // clean up extra spaces
    testArgs.permuteArgs = strip(replace(testArgs.permuteArgs, "  ", " "));

    findTestParameter(file, "EXECUTE_ARGS", testArgs.executeArgs);

    string extraSourcesStr;
    findTestParameter(file, "EXTRA_SOURCES", extraSourcesStr);
    testArgs.sources = [input_file];
    // prepend input_dir to each extra source file
    foreach(s; split(extraSourcesStr, " "))
        testArgs.sources ~= input_dir ~ "/" ~ s;

    // swap / with $SEP
    if (envData.sep && envData.sep != "/")
        foreach (ref s; testArgs.sources)
            s = replace(s, "/", to!string(envData.sep));
    //writeln ("sources: ", testArgs.sources);

    string compileSeparatelyStr;
    testArgs.compileSeparately = findTestParameter(file, "COMPILE_SEPARATELY", compileSeparatelyStr);

    if (findTestParameter(file, "POST_SCRIPT", testArgs.postScript))
        testArgs.postScript = replace(testArgs.postScript, "/", to!string(envData.sep));
}

string[] combinations(string argstr)
{
    string[] results;
    string[] args = split(argstr, " ");
    long combinations = 1 << args.length;
    for (size_t i = 0; i < combinations; i++)
    {
        string r;
        bool printed = false;

        for (size_t j = 0; j < args.length; j++)
        {
            if (i & 1 << j)
            {
                if (printed)
                    r ~= " ";
                r ~= args[j];
                printed = true;
            }
        }

        results ~= r;
    }

    return results;
}

string genTempFilename()
{
    auto a = appender!string();
    foreach (ref e; 0 .. 8)
    {
        formattedWrite(a, "%x", rndGen.front);
        rndGen.popFront();
    }

    return a.data;
}

int system(string command)
{
    if (!command) return std.c.process.system(null);
    const commandz = toStringz(command);
    auto status = std.c.process.system(commandz);
    if (status == -1) return status;
    version (Windows) status <<= 8;
    return status;
}

version(Windows)
{
    extern (D) bool WIFEXITED( int status )    { return ( status & 0x7F ) == 0; }
    extern (D) int  WEXITSTATUS( int status )  { return ( status & 0xFF00 ) >> 8; }
    extern (D) int  WTERMSIG( int status )     { return status & 0x7F; }
    extern (D) bool WIFSIGNALED( int status )
    {
        return ( cast(byte) ( ( status & 0x7F ) + 1 ) >> 1 ) > 0;
    }
}

void execute(ref File f, string command, bool expectpass)
{
    auto filename = genTempFilename();
    scope(exit) if (std.file.exists(filename)) std.file.remove(filename);

    f.writeln(command);
    auto rc = system(command ~ " > " ~ filename ~ " 2>&1");

    f.write(readText(filename));

    if (WIFSIGNALED(rc))
    {
        auto value = WTERMSIG(rc);
        enforce(0 == value, "caught signal: " ~ to!string(value));
    }
    else if (WIFEXITED(rc))
    {
        auto value = WEXITSTATUS(rc);
        if (expectpass)
            enforce(0 == value, "expected rc == 0, exited with rc == " ~ to!string(value));
        else
            enforce(1 == value, "expected rc == 1, but exited with rc == " ~ to!string(value));
    }
}

int main(string[] args)
{
    if (args.length != 4)
    {
        usage();
        return 1;
    }

    string input_dir      = args[1];
    string test_name      = args[2];
    string test_extension = args[3];

    EnvData envData;
    envData.all_args      = getenv("ARGS");
    envData.results_dir   = getenv("RESULTS_DIR");
    envData.sep           = getenv("SEP");
    envData.dsep          = getenv("DSEP");
    envData.obj           = getenv("OBJ");
    envData.exe           = getenv("EXE");
    envData.os            = getenv("OS");
    envData.dmd           = replace(getenv("DMD"), "/", envData.sep);
    envData.model         = getenv("MODEL");

    string input_file     = input_dir ~ envData.sep ~ test_name ~ "." ~ test_extension;
    string output_dir     = envData.results_dir ~ envData.sep ~ input_dir;
    string output_file    = envData.results_dir ~ envData.sep ~ input_dir ~ envData.sep ~ test_name ~ "." ~ test_extension ~ ".out";
    string test_app_dmd_base = output_dir ~ envData.sep ~ test_name ~ "_";

    TestArgs testArgs;

    switch (input_dir)
    {
        case "compilable":       testArgs.mode = TestMode.COMPILE;      break;
        case "fail_compilation": testArgs.mode = TestMode.FAIL_COMPILE; break;
        case "runnable":         testArgs.mode = TestMode.RUN;          break;
        default:
            writeln("input_dir must be one of 'compilable', 'fail_compilation', or 'runnable'");
            return 1;
    }

    gatherTestParameters(testArgs, input_dir, input_file, envData);

    writefln(" ... %-30s %s%s(%s)",
            input_file,
            testArgs.requiredArgs,
            (testArgs.requiredArgs ? " " : ""),
            testArgs.permuteArgs);

    if (std.file.exists(output_file))
        std.file.remove(output_file);

    auto f = File(output_file, "a");

    foreach(i, c; combinations(testArgs.permuteArgs))
    {
        string[] toCleanup;

        string test_app_dmd = test_app_dmd_base ~ to!string(i) ~ envData.exe;

        try
        {
            if (!testArgs.compileSeparately)
            {
                string objfile = output_dir ~ envData.sep ~ test_name ~ "_" ~ to!string(i) ~ envData.obj;
                toCleanup ~= objfile;

                if (testArgs.mode == TestMode.RUN)
                    toCleanup ~= test_app_dmd;

                string command = format("%s -m%s -I%s %s %s -od%s -of%s %s%s", envData.dmd, envData.model, input_dir,
                        testArgs.requiredArgs, c, output_dir,
                        (testArgs.mode == TestMode.RUN ? test_app_dmd : objfile),
                        (testArgs.mode == TestMode.RUN ? "" : "-c "),
                        join(testArgs.sources, " "));
                version(Windows) command ~= " -map nul.map";
                execute(f, command, testArgs.mode != TestMode.FAIL_COMPILE);
            }
            else
            {
                foreach (filename; testArgs.sources)
                {
                    string newo= envData.results_dir ~ envData.sep ~
                        replace(replace(filename, ".d", envData.obj), envData.sep~"imports"~envData.sep, envData.sep);
                    toCleanup ~= newo;

                    string command = format("%s -m%s -I%s %s %s -od%s -c %s", envData.dmd, envData.model, input_dir,
                        testArgs.requiredArgs, c, output_dir, filename);
                    execute(f, command, testArgs.mode != TestMode.FAIL_COMPILE);
                }

                if (testArgs.mode == TestMode.RUN)
                {
                    // link .o's into an executable
                    string command = format("%s -m%s -od%s -of%s %s", envData.dmd, envData.model, output_dir, test_app_dmd, join(toCleanup, " "));
                    version(Windows) command ~= " -map nul.map";

                    // add after building the command so that before now, it's purely the .o's involved
                    toCleanup ~= test_app_dmd;

                    execute(f, command, true);
                }
            }

            if (testArgs.mode == TestMode.RUN)
            {
                string command = test_app_dmd;
                if (testArgs.executeArgs) command ~= " " ~ testArgs.executeArgs;

                execute(f, command, true);
            }

            if (testArgs.postScript)
            {
                f.write("Executing post-test script: ");
                version (Windows) testArgs.postScript = "bash " ~ testArgs.postScript;
                execute(f, testArgs.postScript, true);
            }

            // cleanup
            foreach (file; toCleanup)
                collectException(std.file.remove(file));

            f.writeln();
        }
        catch(Exception e)
        {
            f.writeln();
            f.writeln("==============================");
            f.writeln("Test failed: ", e.msg);
            f.close();

            writeln("Test failed.  The logged output:");
            if (std.file.exists(output_file))
            {
                writeln(cast(string) std.file.read(output_file));
                std.file.remove(output_file);
            }
            return 1;
        }
    }

    return 0;
}

