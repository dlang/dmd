module runbench;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.exception;
import std.file;
import std.format;
import std.process;
import std.path;
import std.random;
import std.regex;
import std.stdio;
import std.string;
import core.sys.posix.sys.wait;

void usage()
{
    write("runbench [<test_regex>] [arguments to pass to test]\n"
          "\n"
          "   test_regex: regex of test cases to run\n"
          "\n"
          "   example: runbench pi 100\n"
          "\n"
          "   relevant environment variables:\n"
          "      ARGS:          arguments always passed to the compiler\n"
          "      DMD:           compiler to use, ex: ../src/dmd\n"
          "      CC:            C++ compiler to use, ex: dmc, g++\n"
          "      OS:            win32, win64, linux, freebsd, osx\n"
          "      RESULTS_DIR:   base directory for test results\n"
          "   windows vs non-windows portability env vars:\n"
          "      DSEP:          \\\\ or /\n"
          "      SEP:           \\ or /\n"
          "      OBJ:          .obj or .o\n"
          "      EXE:          .exe or <null>\n");
}

struct TestArgs
{
    bool     compileSeparately;
    string   executeArgs;
    string[] sources;
    string[] cppSources;
    string   compileOutput;
    string   postScript;
    string   requiredArgs;
    string   requiredArgsForLink;
    // reason for disabling the test (if empty, the test is not disabled)
    string   disabled_reason;
    @property bool disabled() { return disabled_reason != ""; }
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
    string compiler;
    string ccompiler;
    string model;
    string required_args;
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

    string result2;
    if (findTestParameter(file[tokenStart+lineEnd..$], token, result2))
        result ~= " " ~ result2;

    return true;
}

bool findOutputParameter(string file, string token, out string result, string sep)
{
    bool found = false;

    while (true)
    {
        auto istart = std.string.indexOf(file, token);
        if (istart == -1)
            break;
        found = true;

        // skips the :, if present
        if (file[istart] == ':') ++istart;

        enum embed_sep = "---";

        auto n = std.string.indexOf(file[istart .. $], embed_sep);
        enforce(n != -1, "invalid TEST_OUTPUT format");
        istart += n + embed_sep.length;
        while (file[istart] == '-') ++istart;
        if (file[istart] == '\r') ++istart;
        if (file[istart] == '\n') ++istart;

        auto iend = std.string.indexOf(file[istart .. $], embed_sep);
        enforce(iend != -1, "invalid TEST_OUTPUT format");
        iend += istart;

        result ~= file[istart .. iend];

        while (file[iend] == '-') ++iend;
        file = file[iend .. $];
    }

    if (found)
    {
        result = std.string.strip(result);
        result = result.unifyNewLine().unifyDirSep(sep);
        result = result ? result : ""; // keep non-null
    }
    return found;
}

void replaceResultsDir(ref string arguments, const ref EnvData envData)
{
    // Bash would expand this automatically on Posix, but we need to manually
    // perform the replacement for Windows compatibility.
    arguments = replace(arguments, "${RESULTS_DIR}", envData.results_dir);
}

void gatherTestParameters(ref TestArgs testArgs, string input_dir, string input_file, const ref EnvData envData)
{
    string input_path = buildPath(input_dir, input_file);
    string file = cast(string)std.file.read(input_path);

    findTestParameter(file, "REQUIRED_ARGS", testArgs.requiredArgs);
    if(envData.required_args.length)
        testArgs.requiredArgs ~= " " ~ envData.required_args;
    replaceResultsDir(testArgs.requiredArgs, envData);

    findTestParameter(file, "EXECUTE_ARGS", testArgs.executeArgs);
    replaceResultsDir(testArgs.executeArgs, envData);

    string extraSourcesStr;
    findTestParameter(file, "EXTRA_SOURCES", extraSourcesStr);
    testArgs.sources = [input_path];
    // prepend input_dir to each extra source file
    foreach(s; split(extraSourcesStr))
        testArgs.sources ~= input_dir ~ "/" ~ s;

    string extraCppSourcesStr;
    findTestParameter(file, "EXTRA_CPP_SOURCES", extraCppSourcesStr);
    testArgs.cppSources = [];
    // prepend input_dir to each extra source file
    foreach(s; split(extraCppSourcesStr))
        testArgs.cppSources ~= s;

    // swap / with $SEP
    if (envData.sep && envData.sep != "/")
        foreach (ref s; testArgs.sources)
            s = replace(s, "/", to!string(envData.sep));
    //writeln ("sources: ", testArgs.sources);

    // COMPILE_SEPARATELY can take optional compiler switches when link .o files
    testArgs.compileSeparately = findTestParameter(file, "COMPILE_SEPARATELY", testArgs.requiredArgsForLink);

    findTestParameter(file, "DISABLED", testArgs.disabled_reason);

    findOutputParameter(file, "TEST_OUTPUT", testArgs.compileOutput, envData.sep);

    if (findTestParameter(file, "POST_SCRIPT", testArgs.postScript))
        testArgs.postScript = replace(testArgs.postScript, "/", to!string(envData.sep));
}

string genTempFilename(string result_path)
{
    auto a = appender!string();
    a.put(result_path);
    foreach (ref e; 0 .. 8)
    {
        formattedWrite(a, "%x", rndGen.front);
        rndGen.popFront();
    }

    return a.data;
}

int system(string command)
{
    import std.c.process;

    if (command.empty) return std.c.process.system(null);
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

void removeIfExists(in char[] filename)
{
    if (std.file.exists(filename))
        std.file.remove(filename);
}

string execute(ref File f, string command, bool expectpass, string result_path)
{
    auto filename = genTempFilename(result_path);
    scope(exit) removeIfExists(filename);

    auto rc = system(command ~ " > " ~ filename ~ " 2>&1");

    string output = readText(filename);
    f.writeln(command);
    f.write(output);

    if (WIFSIGNALED(rc))
    {
        auto value = WTERMSIG(rc);
        enforceEx!Error(0 == value, "caught signal: " ~ to!string(value));
    }
    else if (WIFEXITED(rc))
    {
        auto value = WEXITSTATUS(rc);
        if (expectpass)
            enforce(0 == value, "expected rc == 0, exited with rc == " ~ to!string(value));
        else
            enforce(1 == value, "expected rc == 1, but exited with rc == " ~ to!string(value));
    }

    return output;
}

string unifyNewLine(string str)
{
    return std.regex.replace(str, regex(`\r\n|\r|\n`, "g"), "\n");
}

string unifyDirSep(string str, string sep)
{
    return std.regex.replace(str, regex(`(?<=\w\w*)/(?=\w[\w/]*\.di?\b)`, "g"), sep);
}
unittest
{
    assert(`fail_compilation/test.d(1) Error: dummy error message for 'test'`.unifyDirSep(`\`)
        == `fail_compilation\test.d(1) Error: dummy error message for 'test'`);
    assert(`fail_compilation/test.d(1) Error: at fail_compilation/test.d(2)`.unifyDirSep(`\`)
        == `fail_compilation\test.d(1) Error: at fail_compilation\test.d(2)`);

    assert(`fail_compilation/test.d(1) Error: at fail_compilation/imports/test.d(2)`.unifyDirSep(`\`)
        == `fail_compilation\test.d(1) Error: at fail_compilation\imports\test.d(2)`);
    assert(`fail_compilation/diag.d(2): Error: fail_compilation/imports/fail.d must be imported`.unifyDirSep(`\`)
        == `fail_compilation\diag.d(2): Error: fail_compilation\imports\fail.d must be imported`);
}

int main(string[] args)
{
    string pattern = r".*\.d";
    if (args.length > 1)
    {
        if (args[1] == "-unittest")
            return 0;
        if (args[1].startsWith("-"))
        {
            usage();
            return 1;
        }
        pattern = args[1];
	}

    // provide some sensible defaults
    version(Windows) enum isWindows = true; else enum isWindows = false;
    EnvData envData;
    envData.results_dir = environment.get("RESULTS_DIR", "results");
    envData.sep = environment.get("SEP", isWindows ? r"\" : "/");
    envData.dsep = environment.get("DSEP", isWindows ? r"\\" : "/");
    envData.obj = environment.get("OBJ", isWindows ? ".obj" : ".o");
    envData.exe = environment.get("EXE", isWindows ? ".exe" : "");
    envData.os = environment.get("OS", isWindows ? "win32" : "");
    envData.dmd = replace(environment.get("DMD", "dmd"), "/", envData.sep);
    envData.compiler = "dmd"; //should be replaced for other compilers
    envData.ccompiler = environment.get("CC");
    envData.model = environment.get("MODEL", envData.os == "win32" ? "32" : "64");
    envData.required_args = environment.get("ARGS", "-O -release -inline");

    if (std.file.exists("../src/gc/config.d"))
        envData.required_args ~= " -version=initGCFromEnvironment ../src/gc/config.d";

    if (envData.ccompiler.empty)
    {
        switch (envData.os)
        {
            case "win32": envData.ccompiler = "dmc"; break;
            case "win64": envData.ccompiler = `\"Program Files (x86)"\"Microsoft Visual Studio 10.0"\VC\bin\amd64\cl.exe`; break;
            default:      envData.ccompiler = "g++"; break;
        }
    }

    string[] sources;
    auto re = regex(pattern, "g");
    auto self = buildPath(".", "runbench.d");
    foreach(DirEntry src; dirEntries(".", SpanMode.depth))
    {
        if (src.isFile && !match(src.name, re).empty &&
            endsWith(src.name, ".d") && src.name != self)
        {
            sources ~= src.name;
        }
    }

    int rc = 0;
    string test_args = args.length > 2 ? join(args[2..$], " ") : "";
    foreach(tst; sources)
        if (auto res = runTest(envData, tst, test_args))
            rc = res;

    return rc;
}

int runTest(const ref EnvData envData, string tst, string test_args)
{
    tst = tst.replace("/", envData.sep);
    string test_name      = tst.stripExtension;
    string result_path    = envData.results_dir ~ envData.sep;
    string input_file     = baseName(tst);
    string input_dir      = dirName(test_name);
    string output_dir     = result_path ~ input_dir;
    string output_file    = result_path ~ input_dir ~ envData.sep ~ input_file ~ ".out";
    string test_app_dmd_base = output_dir ~ envData.sep ~ baseName(test_name) /*~ "_"*/;

    if (!std.file.exists(output_dir))
        std.file.mkdirRecurse(output_dir);

    TestArgs testArgs;

    gatherTestParameters(testArgs, input_dir, input_file, envData);

    //prepare cpp extra sources
    if (testArgs.cppSources.length)
    {
        switch (envData.compiler)
        {
            case "dmd":
                if(envData.os != "win32" && envData.os != "win64")
                    testArgs.requiredArgs ~= " -L-lstdc++";
                break;
            case "ldc":
                testArgs.requiredArgs ~= " -L-lstdc++";
                break;
            case "gdc":
                testArgs.requiredArgs ~= "-Xlinker -lstdc++";
                break;
            default:
                writeln("unknown compiler: "~envData.compiler);
                return 1;
        }
        foreach (cur; testArgs.cppSources)
        {
            auto curSrc = input_dir ~ envData.sep ~"extra-files" ~ envData.sep ~ cur;
            auto curObj = output_dir ~ envData.sep ~ cur ~ envData.obj;
            string command = envData.ccompiler;
            if (envData.compiler == "dmd")
            {
                if (envData.os == "win32")
                {
                    command ~= " -c "~curSrc~" -o"~curObj;
                }
                else if (envData.os == "win64")
                {
                    command ~= ` /c /nologo `~curSrc~` /Fo`~curObj;
                }
                else
                {
                    command ~= " -m"~envData.model~" -c "~curSrc~" -o "~curObj;
                }
            }
            else
            {
                command ~= " -m"~envData.model~" -c "~curSrc~" -o "~curObj;
            }

            auto rc = system(command);
            if(rc)
            {
                writeln("failed to execute '"~command~"'");
                return 1;
            }
            testArgs.sources ~= curObj;
        }
    }
    writef(" . %-16s ", input_file);
    fflush(core.stdc.stdio.stdout);

    if (testArgs.disabled)
    {
        writefln("!!! [DISABLED: %s]", testArgs.disabled_reason);
        return 0;
    }

    removeIfExists(output_file);

    auto f = File(output_file, "a");

    //foreach(i, c; combinations(testArgs.permuteArgs))
    {
        string c = "";
        string test_app_dmd = test_app_dmd_base /*~ to!string(i)*/ ~ envData.exe;

        try
        {
            string[] toCleanup;

            auto thisRunName = genTempFilename(result_path);
            auto fThisRun = File(thisRunName, "w");
            scope(exit)
            {
                fThisRun.close();
                f.write(readText(thisRunName));
                f.writeln();
                removeIfExists(thisRunName);
            }

            string compile_output;
            if (!testArgs.compileSeparately)
            {
                string objfile = output_dir ~ envData.sep ~ baseName(test_name) /*~ "_" ~ to!string(i)*/ ~ envData.obj;
                toCleanup ~= objfile;

                string command = format("%s -m%s -I%s %s %s -od%s -of%s %s", envData.dmd, envData.model, input_dir,
                                        testArgs.requiredArgs, c, output_dir,
                                        test_app_dmd, join(testArgs.sources, " "));
                version(Windows) command ~= " -map nul.map";

                compile_output = execute(fThisRun, command, true, result_path);
            }
            else
            {
                foreach (filename; testArgs.sources)
                {
                    string newo= result_path ~ replace(replace(filename, ".d", envData.obj), envData.sep~"imports"~envData.sep, envData.sep);
                    toCleanup ~= newo;

                    string command = format("%s -m%s -I%s %s %s -od%s -c %s", envData.dmd, envData.model, input_dir,
                                            testArgs.requiredArgs, c, output_dir, filename);
                    compile_output ~= execute(fThisRun, command, true, result_path);
                }

                //if (testArgs.mode == TestMode.RUN)
                {
                    // link .o's into an executable
                    string command = format("%s -m%s %s %s -od%s -of%s %s", envData.dmd, envData.model, envData.required_args,
                                            testArgs.requiredArgsForLink, output_dir, test_app_dmd, join(toCleanup, " "));
                    version(Windows) command ~= " -map nul.map";

                    execute(fThisRun, command, true, result_path);
                }
            }

            compile_output = std.regex.replace(compile_output, regex(`^DMD v2\.[0-9]+.* DEBUG$`, "m"), "");
            compile_output = std.string.strip(compile_output);
            compile_output = compile_output.unifyNewLine();

            auto m = std.regex.match(compile_output, `Internal error: .*$`);
            enforce(!m, m.hit);

            if (testArgs.compileOutput !is null)
            {
                enforce(compile_output == testArgs.compileOutput,
                        "\nexpected:\n----\n"~testArgs.compileOutput~"\n----\nactual:\n----\n"~compile_output~"\n----\n");
            }

            //if (testArgs.mode == TestMode.RUN)
            {
                toCleanup ~= test_app_dmd;
                version(Windows)
                    if (envData.model == "64")
                    {
                        toCleanup ~= test_app_dmd_base /*~ to!string(i)*/ ~ ".ilk";
                        toCleanup ~= test_app_dmd_base /*~ to!string(i)*/ ~ ".pdb";
                    }

                string command = test_app_dmd;
                if (!test_args.empty)
                    command ~= " " ~ test_args;
                else if (!testArgs.executeArgs.empty)
                    command ~= " " ~ testArgs.executeArgs;

                removeIfExists("gcx.log");

                StopWatch sw;
                sw.start();
                string output = execute(fThisRun, command, true, result_path);
                sw.stop();
                fThisRun.writeln("Execution took ", sw.peek().to!("seconds",double), " s");

                bool inlog = false;
                string search = "maxPoolMemory = ";
                auto pos = output.indexOf(search);
                if (pos < 0)
                    if (std.file.exists("gcx.log"))
                    {
                        output = cast(string) std.file.read("gcx.log");
                        output = output.unifyNewLine();
                        pos = output.indexOf("maxPoolMemory = ");
                        inlog = pos >= 0;

                        fThisRun.writeln(output);
                    }
                string memtxt;
                if (pos >= 0)
                {
                    auto pos2 = output.indexOf('\n', pos);
                    if (pos2 < 0)
                        pos2 = output.length;
                    memtxt = strip(output[pos..pos2]);
                    if (inlog)
                        fThisRun.writeln(memtxt);
                }
                std.stdio.writef("%6.3f s", sw.peek().to!("seconds",double));
                if (!memtxt.empty)
                    std.stdio.write(", ", memtxt);
                std.stdio.writeln;
            }

            fThisRun.close();

            if (!testArgs.postScript.empty)
            {
                f.write("Executing post-test script: ");
                string prefix = "";
                version (Windows) prefix = "bash ";
                execute(f, prefix ~ testArgs.postScript ~ " " ~ thisRunName, true, result_path);
            }

            foreach (file; toCleanup) collectException(std.file.remove(file));
        }
        catch(Exception e)
        {
            // it failed but it was disabled, exit as if it was successful
            if (testArgs.disabled)
                return 0;

            f.writeln();
            f.writeln("==============================");
            f.writeln("Test failed: ", e.msg);
            f.close();

            writeln("Test failed.  The logged output:");
            writeln(cast(string)std.file.read(output_file));
            std.file.remove(output_file);
            return 1;
        }
    }

    // it was disabled but it passed! print an informational message
    if (testArgs.disabled)
        writefln(" !!! %-30s DISABLED but PASSES!", input_file);

    return 0;
}
