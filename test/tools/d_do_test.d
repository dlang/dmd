#!/usr/bin/env rdmd
module d_do_test;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.process;
import std.random;
import std.range : chain;
import std.regex;
import std.path;
import std.stdio;
import std.string;
import core.sys.posix.sys.wait;

const scriptDir = __FILE_FULL_PATH__.dirName.dirName;

version(Win32)
{
    extern(C) int putenv(const char*);
}

void usage()
{
    write("d_do_test <test_file>\n"
          ~ "\n"
          ~ "   Note: this program is normally called through the Makefile, it"
          ~ "         is not meant to be called directly by the user.\n"
          ~ "\n"
          ~ "   example: d_do_test runnable/pi.d\n"
          ~ "\n"
          ~ "   relevant environment variables:\n"
          ~ "      ARGS:          set to execute all combinations of\n"
          ~ "      REQUIRED_ARGS: arguments always passed to the compiler\n"
          ~ "      DMD:           compiler to use, ex: ../src/dmd (required)\n"
          ~ "      CC:            C++ compiler to use, ex: dmc, g++\n"
          ~ "      OS:            win32, win64, linux, freebsd, osx, netbsd, dragonflybsd\n"
          ~ "      RESULTS_DIR:   base directory for test results\n"
          ~ "      MODEL:         32 or 64 (required)\n"
          ~ "      AUTO_UPDATE:   set to 1 to auto-update mismatching test output\n"
          ~ "\n"
          ~ "   windows vs non-windows portability env vars:\n"
          ~ "      DSEP:          \\\\ or /\n"
          ~ "      SEP:           \\ or / (required)\n"
          ~ "      OBJ:          .obj or .o (required)\n"
          ~ "      EXE:          .exe or <null> (required)\n");
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
    bool     link;
    string   executeArgs;
    string   dflags;
    string[] sources;
    string[] compiledImports;
    string[] cppSources;
    string[] objcSources;
    string   permuteArgs;
    string[] argSets;
    string   compileOutput;
    string   gdbScript;
    string   gdbMatch;
    string   postScript;
    string   requiredArgs;
    string   requiredArgsForLink;
    // reason for disabling the test (if empty, the test is not disabled)
    string[] disabledPlatforms;
    bool     disabled;
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
    bool dobjc;
    bool coverage_build;
    bool autoUpdate;
    bool usingMicrosoftCompiler;
}

bool findTestParameter(const ref EnvData envData, string file, string token, ref string result, string multiLineDelimiter = " ")
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
    // filter by OS specific setting (os1 os2 ...)
    if (result.length > 0 && result[0] == '(')
    {
        auto close = std.string.indexOf(result, ")");
        if (close >= 0)
        {
            string[] oss = split(result[1 .. close], " ");
            if (oss.canFind(envData.os))
                result = result[close + 1..$];
            else
                result = null;
        }
    }
    // skips the :, if present
    if (result.length > 0 && result[0] == ':')
        result = strip(result[1 .. $]);

    //writeln("arg: '", result, "'");

    string result2;
    if (findTestParameter(envData, file[tokenStart+lineEnd..$], token, result2, multiLineDelimiter))
    {
        if(result2.length > 0)
            result ~= multiLineDelimiter ~ result2;
    }

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

        enforce(n != -1, "invalid "~token~" format");
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

bool gatherTestParameters(ref TestArgs testArgs, string input_dir, string input_file, const ref EnvData envData)
{
    string file = cast(string)std.file.read(input_file);

    findTestParameter(envData, file, "DFLAGS", testArgs.dflags);

    findTestParameter(envData, file, "REQUIRED_ARGS", testArgs.requiredArgs);
    if (envData.required_args.length)
    {
        if (testArgs.requiredArgs.length)
            testArgs.requiredArgs ~= " " ~ envData.required_args;
        else
            testArgs.requiredArgs = envData.required_args;
    }
    replaceResultsDir(testArgs.requiredArgs, envData);

    if (! findTestParameter(envData, file, "PERMUTE_ARGS", testArgs.permuteArgs))
    {
        if (testArgs.mode == TestMode.RUN)
            testArgs.permuteArgs = envData.all_args;

        string unittestJunk;
        if(!findTestParameter(envData, file, "unittest", unittestJunk))
            testArgs.permuteArgs = replace(testArgs.permuteArgs, "-unittest", "");
    }
    replaceResultsDir(testArgs.permuteArgs, envData);

    // remove permute args enforced as required anyway
    if (testArgs.requiredArgs.length && testArgs.permuteArgs.length)
    {
        const required = split(testArgs.requiredArgs);
        const newPermuteArgs = split(testArgs.permuteArgs)
            .filter!(a => !required.canFind(a))
            .join(" ");
        testArgs.permuteArgs = newPermuteArgs;
    }

    {
        string argSetsStr;
        findTestParameter(envData, file, "ARG_SETS", argSetsStr, ";");
        foreach(s; split(argSetsStr, ";"))
        {
            replaceResultsDir(s, envData);
            testArgs.argSets ~= s;
        }
    }

    // win(32|64) doesn't support pic
    if (envData.os == "win32" || envData.os == "win64")
    {
        auto index = std.string.indexOf(testArgs.permuteArgs, "-fPIC");
        if (index != -1)
            testArgs.permuteArgs = testArgs.permuteArgs[0 .. index] ~ testArgs.permuteArgs[index+5 .. $];
    }

    // clean up extra spaces
    testArgs.permuteArgs = strip(replace(testArgs.permuteArgs, "  ", " "));

    findTestParameter(envData, file, "EXECUTE_ARGS", testArgs.executeArgs);
    replaceResultsDir(testArgs.executeArgs, envData);

    string extraSourcesStr;
    findTestParameter(envData, file, "EXTRA_SOURCES", extraSourcesStr);
    testArgs.sources = [input_file];
    // prepend input_dir to each extra source file
    foreach(s; split(extraSourcesStr))
        testArgs.sources ~= input_dir ~ "/" ~ s;

    {
        string compiledImports;
        findTestParameter(envData, file, "COMPILED_IMPORTS", compiledImports);
        foreach(s; split(compiledImports))
            testArgs.compiledImports ~= input_dir ~ "/" ~ s;
    }

    string extraCppSourcesStr;
    findTestParameter(envData, file, "EXTRA_CPP_SOURCES", extraCppSourcesStr);
    testArgs.cppSources = [];
    // prepend input_dir to each extra source file
    foreach(s; split(extraCppSourcesStr))
        testArgs.cppSources ~= s;

    string extraObjcSourcesStr;
    auto objc = findTestParameter(envData, file, "EXTRA_OBJC_SOURCES", extraObjcSourcesStr);

    if (objc && !envData.dobjc)
        return false;

    testArgs.objcSources = [];
    // prepend input_dir to each extra source file
    foreach(s; split(extraObjcSourcesStr))
        testArgs.objcSources ~= s;

    // swap / with $SEP
    if (envData.sep && envData.sep != "/")
        foreach (ref s; testArgs.sources)
            s = replace(s, "/", to!string(envData.sep));
    //writeln ("sources: ", testArgs.sources);

    {
        string throwAway;
        testArgs.link = findTestParameter(envData, file, "LINK", throwAway);
    }

    // COMPILE_SEPARATELY can take optional compiler switches when link .o files
    testArgs.compileSeparately = findTestParameter(envData, file, "COMPILE_SEPARATELY", testArgs.requiredArgsForLink);

    string disabledPlatformsStr;
    findTestParameter(envData, file, "DISABLED", disabledPlatformsStr);
    testArgs.disabledPlatforms = split(disabledPlatformsStr);

    findOutputParameter(file, "TEST_OUTPUT", testArgs.compileOutput, envData.sep);

    findOutputParameter(file, "GDB_SCRIPT", testArgs.gdbScript, envData.sep);
    findTestParameter(envData, file, "GDB_MATCH", testArgs.gdbMatch);

    if (findTestParameter(envData, file, "POST_SCRIPT", testArgs.postScript))
        testArgs.postScript = replace(testArgs.postScript, "/", to!string(envData.sep));

    return true;
}

string[] combinations(string argstr)
{
    string[] results;
    string[] args = split(argstr);
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
    static import core.stdc.stdlib;
    if (!command) return core.stdc.stdlib.system(null);
    const commandz = toStringz(command);
    auto status = core.stdc.stdlib.system(commandz);
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

    return output;
}

string unifyNewLine(string str)
{
    return std.regex.replace(str, regex(`\r\n|\r|\n`, "g"), "\n");
}

string unifyDirSep(string str, string sep)
{
    return std.regex.replace(str, regex(`(?<=[-\w][-\w]*)/(?=[-\w][-\w/]*\.di?\b)`, "g"), sep);
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

bool collectExtraSources (in string input_dir, in string output_dir, in string[] extraSources, ref string[] sources, in EnvData envData, in string compiler)
{
    foreach (cur; extraSources)
    {
        auto curSrc = input_dir ~ envData.sep ~"extra-files" ~ envData.sep ~ cur;
        auto curObj = output_dir ~ envData.sep ~ cur ~ envData.obj;
        string command = compiler;
        if (envData.compiler == "dmd")
        {
            if (envData.usingMicrosoftCompiler)
            {
                command ~= ` /c /nologo `~curSrc~` /Fo`~curObj;
            }
            else if (envData.os == "win32")
            {
                command ~= " -c "~curSrc~" -o"~curObj;
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
            return false;
        }
        sources ~= curObj;
    }

    return true;
}

// compare output string to reference string, but ignore places
// marked by $n$ that contain compiler generated unique numbers
bool compareOutput(string output, string refoutput)
{
    import std.ascii : digits;
    import std.utf : byCodeUnit;
    for ( ; ; )
    {
        auto pos = refoutput.indexOf("$n$");
        if (pos < 0)
            return refoutput == output;
        if (output.length < pos)
            return false;
        if (refoutput[0..pos] != output[0..pos])
            return false;
        refoutput = refoutput[pos + 3 ..$];
        output = output[pos..$];
        auto p = output.byCodeUnit.countUntil!(e => !digits.canFind(e));
        output = output[p..$];
    }
}

string envGetRequired(in char[] name)
{
    auto value = environment.get(name);
    if(value is null)
    {
        writefln("Error: missing environment variable '%s', was this called this through the Makefile?",
            name);
        throw new SilentQuit();
    }
    return value;
}

class SilentQuit : Exception { this() { super(null); } }

class CompareException : Exception
{
    string expected;
    string actual;

    this(string expected, string actual) {
        string msg = "\nexpected:\n----\n" ~ expected ~
            "\n----\nactual:\n----\n" ~ actual ~ "\n----\n";
        super(msg);
        this.expected = expected;
        this.actual = actual;
    }
}

version(unittest) void main(){} else
int main(string[] args)
{
    try { return tryMain(args); }
    catch(SilentQuit) { return 1; }
}

int tryMain(string[] args)
{
    if (args.length != 2)
    {
        usage();
        return 1;
    }

    auto test_file = args[1];
    string input_dir = test_file.dirName();

    TestArgs testArgs;
    switch (input_dir)
    {
        case "compilable":              testArgs.mode = TestMode.COMPILE;      break;
        case "fail_compilation":        testArgs.mode = TestMode.FAIL_COMPILE; break;
        case "runnable":                testArgs.mode = TestMode.RUN;          break;
        default:
            writefln("Error: invalid test directory '%s', expected 'compilable', 'fail_compilation', or 'runnable'", input_dir);
            return 1;
    }

    string test_base_name = test_file.baseName();
    string test_name = test_base_name.stripExtension();

    if (test_base_name.extension() == ".sh")
        return runBashTest(input_dir, test_name);

    EnvData envData;
    envData.all_args      = environment.get("ARGS");
    envData.results_dir   = envGetRequired("RESULTS_DIR");
    envData.sep           = envGetRequired ("SEP");
    envData.dsep          = environment.get("DSEP");
    envData.obj           = envGetRequired ("OBJ");
    envData.exe           = envGetRequired ("EXE");
    envData.os            = environment.get("OS");
    envData.dmd           = replace(envGetRequired("DMD"), "/", envData.sep);
    envData.compiler      = "dmd"; //should be replaced for other compilers
    envData.ccompiler     = environment.get("CC");
    envData.model         = envGetRequired("MODEL");
    envData.required_args = environment.get("REQUIRED_ARGS");
    envData.dobjc         = environment.get("D_OBJC") == "1";
    envData.coverage_build   = environment.get("DMD_TEST_COVERAGE") == "1";
    envData.autoUpdate = environment.get("AUTO_UPDATE", "") == "1";

    string result_path    = envData.results_dir ~ envData.sep;
    string input_file     = input_dir ~ envData.sep ~ test_base_name;
    string output_dir     = result_path ~ input_dir;
    string output_file    = result_path ~ input_file ~ ".out";
    string test_app_dmd_base = output_dir ~ envData.sep ~ test_name ~ "_";

    // running & linking costs time - for coverage builds we can save this
    if (envData.coverage_build && testArgs.mode == TestMode.RUN)
        testArgs.mode = TestMode.COMPILE;

    if (envData.ccompiler.empty)
    {
        switch (envData.os)
        {
            case "win32": envData.ccompiler = "dmc"; break;
            case "win64": envData.ccompiler = `\"Program Files (x86)"\"Microsoft Visual Studio 10.0"\VC\bin\amd64\cl.exe`; break;
            default:      envData.ccompiler = "c++"; break;
        }
    }

    envData.usingMicrosoftCompiler = envData.ccompiler.toLower.endsWith("cl.exe");

    if (!gatherTestParameters(testArgs, input_dir, input_file, envData))
        return 0;

    // Clear the DFLAGS environment variable if it was specified in the test file
    if (testArgs.dflags !is null)
    {
        if (testArgs.dflags != "")
            throw new Exception("The DFLAGS test argument must be empty: It is '" ~ testArgs.dflags ~ "'");

        // `environment["DFLAGS"] = "";` doesn't seem to work on Win32 (might be a bug
        // in std.process). So, resorting to `putenv` in snn.lib
        version(Win32)
        {
            putenv("DFLAGS=");
        }
        else
        {
            environment["DFLAGS"] = "";
        }
    }

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
        if (!collectExtraSources(input_dir, output_dir, testArgs.cppSources, testArgs.sources, envData, envData.ccompiler))
            return 1;
    }
    //prepare objc extra sources
    if (!collectExtraSources(input_dir, output_dir, testArgs.objcSources, testArgs.sources, envData, "clang"))
        return 1;

    writef(" ... %-30s %s%s(%s)",
            input_file,
            testArgs.requiredArgs,
            (!testArgs.requiredArgs.empty ? " " : ""),
            testArgs.permuteArgs);

    version (DragonFlyBSD)
    {
        // DragonFlyBSD is x86_64 only, instead of adding DISABLED to a lot of tests, just exclude them from running
        if (testArgs.requiredArgs.canFind("-m32"))
        {
            testArgs.disabled = true;
            writefln("!!! [Skipping -m32 on %s]", envData.os);
        }
    }

    // allows partial matching, e.g. win for both win32 and win64
    if (testArgs.disabledPlatforms.any!(a => envData.os.chain(envData.model).canFind(a)))
    {
        testArgs.disabled = true;
        writefln("!!! [DISABLED on %s]", envData.os);
    }
    else
        write("\n");

    removeIfExists(output_file);

    auto f = File(output_file, "a");

    enum Result { continue_, return0, return1 }

    // Runs the test with a specific combination of arguments
    Result testCombination(bool autoCompileImports, string argSet, size_t permuteIndex, string permutedArgs)
    {
        string test_app_dmd = test_app_dmd_base ~ to!string(permuteIndex) ~ envData.exe;
        string command; // copy of the last executed command so that it can be re-invoked on failures
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

            // can override -verrors by using REQUIRED_ARGS
            auto reqArgs =
                (testArgs.mode == TestMode.FAIL_COMPILE ? "-verrors=0 " : null) ~
                testArgs.requiredArgs;

            // https://issues.dlang.org/show_bug.cgi?id=10664: exceptions don't work reliably with COMDAT folding
            // it also slows down some tests drastically, e.g. runnable/test17338.d
            if (envData.usingMicrosoftCompiler)
                reqArgs ~= " -L/OPT:NOICF";

            string compile_output;
            if (!testArgs.compileSeparately)
            {
                string objfile = output_dir ~ envData.sep ~ test_name ~ "_" ~ to!string(permuteIndex) ~ envData.obj;
                toCleanup ~= objfile;

                command = format("%s -conf= -m%s -I%s %s %s -od%s -of%s %s %s%s %s", envData.dmd, envData.model, input_dir,
                        reqArgs, permutedArgs, output_dir,
                        (testArgs.mode == TestMode.RUN || testArgs.link ? test_app_dmd : objfile),
                        argSet,
                        (testArgs.mode == TestMode.RUN || testArgs.link ? "" : "-c "),
                        join(testArgs.sources, " "),
                        (autoCompileImports ? "-i" : join(testArgs.compiledImports, " ")));
                version(Windows) command ~= " -map nul.map";

                compile_output = execute(fThisRun, command, testArgs.mode != TestMode.FAIL_COMPILE, result_path);
            }
            else
            {
                foreach (filename; testArgs.sources ~ (autoCompileImports ? null : testArgs.compiledImports))
                {
                    string newo= result_path ~ replace(replace(filename, ".d", envData.obj), envData.sep~"imports"~envData.sep, envData.sep);
                    toCleanup ~= newo;

                    command = format("%s -conf= -m%s -I%s %s %s -od%s -c %s %s", envData.dmd, envData.model, input_dir,
                        reqArgs, permutedArgs, output_dir, argSet, filename);
                    compile_output ~= execute(fThisRun, command, testArgs.mode != TestMode.FAIL_COMPILE, result_path);
                }

                if (testArgs.mode == TestMode.RUN || testArgs.link)
                {
                    // link .o's into an executable
                    command = format("%s -conf= -m%s%s%s %s %s -od%s -of%s %s", envData.dmd, envData.model,
                        autoCompileImports ? " -i" : "",
                        autoCompileImports ? "extraSourceIncludePaths" : "",
                        envData.required_args, testArgs.requiredArgsForLink, output_dir, test_app_dmd, join(toCleanup, " "));
                    version(Windows) command ~= " -map nul.map";

                    execute(fThisRun, command, true, result_path);
                }
            }

            compile_output = compile_output.unifyNewLine();
            compile_output = std.regex.replace(compile_output, regex(`^DMD v2\.[0-9]+.*\n? DEBUG$`, "m"), "");
            compile_output = std.string.strip(compile_output);

            auto m = std.regex.match(compile_output, `Internal error: .*$`);
            enforce(!m, m.hit);
            m = std.regex.match(compile_output, `core.exception.AssertError@dmd.*`);
            enforce(!m, m.hit);

            if (testArgs.compileOutput !is null)
            {
                if(!compareOutput(compile_output, testArgs.compileOutput))
                    throw new CompareException(testArgs.compileOutput, compile_output);
            }

            if (testArgs.mode == TestMode.RUN)
            {
                toCleanup ~= test_app_dmd;
                version(Windows)
                    if (envData.usingMicrosoftCompiler)
                    {
                        toCleanup ~= test_app_dmd_base ~ to!string(permuteIndex) ~ ".ilk";
                        toCleanup ~= test_app_dmd_base ~ to!string(permuteIndex) ~ ".pdb";
                    }

                if (testArgs.gdbScript is null)
                {
                    command = test_app_dmd;
                    if (testArgs.executeArgs) command ~= " " ~ testArgs.executeArgs;

                    execute(fThisRun, command, true, result_path);
                }
                else version (linux)
                {
                    auto script = test_app_dmd_base ~ to!string(permuteIndex) ~ ".gdb";
                    toCleanup ~= script;
                    with (File(script, "w"))
                    {
                        writeln("set disable-randomization off");
                        write(testArgs.gdbScript);
                    }
                    string gdbCommand = "gdb "~test_app_dmd~" --batch -x "~script;
                    auto gdb_output = execute(fThisRun, gdbCommand, true, result_path);
                    if (testArgs.gdbMatch !is null)
                    {
                        enforce(match(gdb_output, regex(testArgs.gdbMatch)),
                                "\nGDB regex: '"~testArgs.gdbMatch~"' didn't match output:\n----\n"~gdb_output~"\n----\n");
                    }
                }
            }

            fThisRun.close();

            if (testArgs.postScript && !envData.coverage_build)
            {
                f.write("Executing post-test script: ");
                string prefix = "";
                version (Windows) prefix = "bash ";
                assert(testArgs.sources[0].length, "Internal error: the tested file has no sources.");
                import std.path : baseName, dirName, stripExtension;
                auto testDir = testArgs.sources[0].dirName.baseName;
                auto testName = testArgs.sources[0].baseName.stripExtension;
                execute(f, prefix ~ "tools/postscript.sh " ~ testArgs.postScript ~ " " ~ testDir ~ " " ~ testName ~ " " ~ thisRunName, true, result_path);
            }

            foreach (file; toCleanup) collectException(std.file.remove(file));
            return Result.continue_;
        }
        catch(Exception e)
        {
            // it failed but it was disabled, exit as if it was successful
            if (testArgs.disabled)
                return Result.return0;

            if (envData.autoUpdate)
            if (auto ce = cast(CompareException) e)
            {
                // remove the output file in test_results as its outdated
                output_file.remove();

                auto existingText = input_file.readText;
                auto updatedText = existingText.replace(ce.expected, ce.actual);
                if (existingText != updatedText)
                {
                    std.file.write(input_file, updatedText);
                    writefln("==> `TEST_OUTPUT` of %s has been updated", input_file);
                }
                else
                {
                    writefln("WARNING: %s has multiple `TEST_OUTPUT` blocks and can't be auto-updated", input_file);
                }
                return Result.return0;
            }
            f.writeln();
            f.writeln("==============================");
            f.writef("Test %s failed: ", input_file);
            f.writeln(e.msg);
            f.close();

            writefln("Test %s failed.  The logged output:", input_file);
            auto outputText = output_file.readText;
            writeln(outputText);
            output_file.remove();

            // auto-update if a diff is found and can be updated
            if (envData.autoUpdate &&
                outputText.canFind("diff ") && outputText.canFind("--- ") && outputText.canFind("+++ "))
            {
                import std.range : dropOne;
                auto newFile = outputText.findSplitAfter("+++ ")[1].until("\t");
                auto baseFile = outputText.findSplitAfter("--- ")[1].until("\t");
                writefln("===> Updating %s with %s", baseFile, newFile);
                newFile.copy(baseFile);
                return Result.return0;
            }

            // automatically rerun a segfaulting test and print its stack trace
            version(linux)
            if (e.msg.canFind("exited with rc == 139"))
            {
                auto gdbCommand = "gdb -q -n -ex 'set backtrace limit 100' -ex run -ex bt -batch -args " ~ command;
                import std.process : executeShell;
                auto res = executeShell(gdbCommand);
                res.output.writeln;
            }

            return Result.return1;
        }
    }

    size_t index = 0; // index over all tests to avoid identical output names in consecutive tests
    auto argSets = (testArgs.argSets.length == 0) ? [""] : testArgs.argSets;
    for(auto autoCompileImports = false;; autoCompileImports = true)
    {
        foreach(argSet; argSets)
        {
            foreach (c; combinations(testArgs.permuteArgs))
            {
                final switch(testCombination(autoCompileImports, argSet, index, c))
                {
                    case Result.continue_: break;
                    case Result.return0: return 0;
                    case Result.return1: return 1;
                }
                index++;
            }
        }
        if(autoCompileImports || testArgs.compiledImports.length == 0)
            break;
    }

    // it was disabled but it passed! print an informational message
    if (testArgs.disabled)
        writefln(" !!! %-30s DISABLED but PASSES!", input_file);

    return 0;
}

int runBashTest(string input_dir, string test_name)
{
    version(Windows)
    {
        auto process = spawnShell(format("bash %s %s %s",
            buildPath(scriptDir, "tools", "sh_do_test.sh"), input_dir, test_name));
    }
    else
    {
        auto process = spawnProcess([scriptDir.buildPath("tools", "sh_do_test.sh"), input_dir, test_name]);
    }
    return process.wait();
}
