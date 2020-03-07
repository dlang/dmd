#!/usr/bin/env rdmd
module d_do_test;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime.stopwatch;
import std.datetime.systime;
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

const dmdTestDir = __FILE_FULL_PATH__.dirName.dirName;

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
          ~ "      OS:            windows, linux, freebsd, osx, netbsd, dragonflybsd\n"
          ~ "      RESULTS_DIR:   base directory for test results\n"
          ~ "      MODEL:         32 or 64 (required)\n"
          ~ "      AUTO_UPDATE:   set to 1 to auto-update mismatching test output\n"
          ~ "      PRINT_RUNTIME: set to 1 to print test runtime\n"
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
    RUN,
    DSHELL,
}

struct TestArgs
{
    TestMode mode;

    bool     compileSeparately;
    bool     link;
    string   executeArgs;
    string   dflags;
    string   cxxflags;
    string[] sources;
    string[] compiledImports;
    string[] cppSources;
    string[] objcSources;
    string   permuteArgs;
    string[] argSets;
    string   compileOutput;
    string   compileOutputFile; /// file containing the expected output
    string   runOutput; /// Expected output of the compiled executable
    string   gdbScript;
    string   gdbMatch;
    string   postScript;
    string   transformOutput; /// Transformations for the compiler output
    string   requiredArgs;
    string   requiredArgsForLink;
    string   disabledReason; // if empty, the test is not disabled

    bool isDisabled() const { return disabledReason.length != 0; }
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

    file = file[tokenStart + token.length .. $];

    auto lineEndR = std.string.indexOf(file, "\r");
    auto lineEndN = std.string.indexOf(file, "\n");
    auto lineEnd  = lineEndR == -1 ?
        (lineEndN == -1 ? file.length : lineEndN) :
        (lineEndN == -1 ? lineEndR    : min(lineEndR, lineEndN));

    //writeln("found ", token, " in line: ", file.length, ", ", tokenStart, ", ", tokenStart+lineEnd);
    //writeln("found ", token, " in line: '", file[tokenStart .. tokenStart+lineEnd], "'");

    result = file[0 .. lineEnd];
    const commentStart = std.string.indexOf(result, "//");
    if (commentStart != -1)
        result = result[0 .. commentStart];
    result = strip(result);

    // filter by OS specific setting (os1 os2 ...)
    if (result.startsWith("("))
    {
        auto close = std.string.indexOf(result, ")");
        if (close >= 0)
        {
            string[] oss = split(result[1 .. close], " ");
            if (oss.canFind(envData.os))
                result = result[close + 1 .. $];
            else
                result = null;
        }
    }
    // skips the :, if present
    if (result.startsWith(":"))
        result = strip(result[1 .. $]);

    //writeln("arg: '", result, "'");

    string result2;
    if (findTestParameter(envData, file[lineEnd .. $], token, result2, multiLineDelimiter))
    {
        if (result2.length > 0)
        {
            if (result.length == 0)
                result = result2;
            else
                result ~= multiLineDelimiter ~ result2;
        }
    }

    // fix-up separators
    result = result.unifyDirSep(envData.sep);

    return true;
}

bool findOutputParameter(string file, string token, out string result, string sep)
{
    bool found = false;

    while (true)
    {
        const istart = std.string.indexOf(file, token);
        if (istart == -1)
            break;
        found = true;

        file = file[istart + token.length .. $];

        enum embed_sep = "---";
        auto n = std.string.indexOf(file, embed_sep);

        enforce(n != -1, "invalid "~token~" format");
        n += embed_sep.length;
        while (file[n] == '-') ++n;
        if (file[n] == '\r') ++n;
        if (file[n] == '\n') ++n;

        file = file[n .. $];
        auto iend = std.string.indexOf(file, embed_sep);
        enforce(iend != -1, "invalid TEST_OUTPUT format");

        result ~= file[0 .. iend];

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

string getDisabledReason(string[] disabledPlatforms, const ref EnvData envData)
{
    if (disabledPlatforms.length == 0)
        return null;

    const target = ((envData.os == "windows") ? "win" : envData.os) ~ envData.model;

    // allow partial matching, e.g. `win` to disable both win32 and win64
    const i = disabledPlatforms.countUntil!(p => target.canFind(p));
    if (i != -1)
        return "on " ~ disabledPlatforms[i];

    return null;
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
    if (envData.os == "windows")
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

    findTestParameter(envData, file, "CXXFLAGS", testArgs.cxxflags);
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

    version (DragonFlyBSD)
    {
        // DragonFlyBSD is x86_64 only, instead of adding DISABLED to a lot of tests, just exclude them from running
        if (testArgs.requiredArgs.canFind("-m32"))
            testArgs.disabledReason = "on DragonFlyBSD (no -m32)";
    }

    version (ARM)         enum supportsM64 = false;
    else version (MIPS32) enum supportsM64 = false;
    else version (PPC)    enum supportsM64 = false;
    else                  enum supportsM64 = true;

    static if (!supportsM64)
    {
        if (testArgs.requiredArgs.canFind("-m64"))
            testArgs.disabledReason = "because target doesn't support -m64";
    }

    if (!testArgs.isDisabled)
        testArgs.disabledReason = getDisabledReason(split(disabledPlatformsStr), envData);

    findTestParameter(envData, file, "TEST_OUTPUT_FILE", testArgs.compileOutputFile);

    // Only check for TEST_OUTPUT is no file was given because it would
    // partially match TEST_OUTPUT_FILE
    if (testArgs.compileOutputFile)
    {
        // Don't require tests to specify the test directory
        testArgs.compileOutputFile = input_dir.buildPath(testArgs.compileOutputFile);
        testArgs.compileOutput = readText(testArgs.compileOutputFile)
                                    .unifyNewLine() // Avoid CRLF issues
                                    .strip();
    }
    else
        findOutputParameter(file, "TEST_OUTPUT", testArgs.compileOutput, envData.sep);

    findTestParameter(envData, file, "TRANSFORM_OUTPUT", testArgs.transformOutput);

    findOutputParameter(file, "RUN_OUTPUT", testArgs.runOutput, envData.sep);

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

/// add quotes around the whole string if it contains spaces that are not in quotes
string quoteSpaces(string str)
{
    if (str.indexOf(' ') < 0)
        return str;
    bool inquote = false;
    foreach(dchar c; str)
        if (c == '"')
            inquote = !inquote;
        else if (c == ' ' && !inquote)
            return "\"" ~ str ~ "\"";
    return str;
}

string unifyNewLine(string str)
{
    // On Windows, Outbuffer.writenl() puts `\r\n` into the buffer,
    // then fprintf() adds another `\r` when formatting the message.
    // This is why there's a match for `\r\r\n` in this regex.
    static re = regex(`\r\r\n|\r\n|\r|\n`, "g");
    return std.regex.replace(str, re, "\n");
}

string unifyDirSep(string str, string sep)
{
    static re = regex(`(?<=[-\w{}][-\w{}]*)/(?=[-\w][-\w/]*\.(di?|mixin)\b)`, "g");
    return std.regex.replace(str, re, sep);
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

    assert(`{{RESULTS_DIR}}/fail_compilation/mixin_test.mixin(7): Error:`.unifyDirSep(`\`)
        == `{{RESULTS_DIR}}\fail_compilation\mixin_test.mixin(7): Error:`);
}

bool collectExtraSources (in string input_dir, in string output_dir, in string[] extraSources,
                          ref string[] sources, in EnvData envData, in string compiler,
                          const(char)[] cxxflags)
{
    foreach (cur; extraSources)
    {
        auto curSrc = input_dir ~ envData.sep ~"extra-files" ~ envData.sep ~ cur;
        auto curObj = output_dir ~ envData.sep ~ cur ~ envData.obj;
        string command = quoteSpaces(compiler);
        if (envData.compiler == "dmd")
        {
            if (envData.usingMicrosoftCompiler)
            {
                command ~= ` /c /nologo `~curSrc~` /Fo`~curObj;
            }
            else if (envData.os == "windows" && envData.model == "32")
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
        if (cxxflags)
            command ~= " " ~ cxxflags;

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

/++
Applies custom transformations defined in transformOutput to testOutput.

Currently the following actions are supported:
 * "sanitize_json"       = replace compiler/plattform specific data from generated JSON
 * "remove_lines(<re>)" = remove all lines matching a regex <re>

Params:
    testOutput      = the existing output to be modified
    transformOutput = list of transformation identifiers
++/
void applyOutputTransformations(ref string testOutput, string transformOutput)
{
    while (transformOutput.length)
    {
        string step, arg;

        const idx = transformOutput.countUntil(' ', '(');
        if (idx == -1)
        {
            step = transformOutput;
            transformOutput = null;
        }
        else
        {
            step = transformOutput[0 .. idx];
            const hasArgs = transformOutput[idx] == '(';
            transformOutput = transformOutput[idx + 1 .. $];
            if (hasArgs)
            {
                // "..." quotes are optional but necessary if the arg contains ')'
                const isQuoted = transformOutput[0] == '"';
                const end = isQuoted ? `"` : `)`;
                auto parts = transformOutput[isQuoted .. $].findSplit(end);
                enforce(parts, "Missing closing `" ~ end ~ "`!");
                arg = parts[0];
                transformOutput = parts[2][isQuoted .. $];
            }

            // Skip space between steps
            import std.ascii : isWhite;
            transformOutput.skipOver!isWhite();
        }

        switch (step)
        {
            case "sanitize_json":
            {
                import sanitize_json : sanitize;
                sanitize(testOutput);
                break;
            }

            case "remove_lines":
            {
                auto re = regex(arg);
                testOutput = testOutput
                    .splitter('\n')
                    .filter!(line => !line.matchFirst(re))
                    .join('\n');
                break;
            }

            default:
                throw new Exception(format(`Unknown transformation: "%s"!`, step));
        }
    }
}

unittest
{
    static void test(string input, const string transformations, const string expected)
    {
        applyOutputTransformations(input, transformations);
        assert(input == expected);
    }

    static void testJson(const string transformations, const string expectedJson)
    {
        test(`{
    "modules": [
        {
            "file": "/path/to/the/file",
            "kind": "module",
            "members": []
        }
    ]
}`, transformations, expectedJson);
    }


    testJson("sanitize_json", `{
    "modules": [
        {
            "file": "VALUE_REMOVED_FOR_TEST",
            "kind": "module",
            "members": []
        }
    ]
}`);

    testJson(`sanitize_json  remove_lines("kind")`, `{
    "modules": [
        {
            "file": "VALUE_REMOVED_FOR_TEST",
            "members": []
        }
    ]
}`);

    testJson(`sanitize_json remove_lines("kind") remove_lines("file")`, `{
    "modules": [
        {
            "members": []
        }
    ]
}`);

    test(`This is a text containing
        some words which is a text sample
        nevertheless`,
        `remove_lines(text sample)`,
        `This is a text containing
        nevertheless`);

    test(`This is a text with
        a random ) which should
        still work`,
        `remove_lines("random \)")`,
        `This is a text with
        still work`);

    test(`Tom bought
        12 apples
        and 6 berries
        from the store`,
        `remove_lines("(\d+)")`,
        `Tom bought
        from the store`);

    assertThrown(test("", "unknown", ""));
}

/++
Compares the output string to the reference string by character
except parts marked with one of the following special sequences:

$n$ = numbers (e.g. compiler generated unique identifiers)
$p:<path>$ = real paths ending with <path>
$?:<choices>$ = environment dependent content supplied as a list
                choices (either <condition>=<content> or <default>),
                separated by a '|'. Currently supported conditions are
                OS and model as supplied from the environment

Params:
    output    = the real output
    refoutput = the expected output
    envData   = test environment

Returns: whether output matches the expected refoutput
++/
bool compareOutput(string output, string refoutput, const ref EnvData envData)
{
    // If no output is expected, only check that nothing was captured.
    if (refoutput.length == 0)
        return (output.length == 0) ? true : false;

    for ( ; ; )
    {
        auto special = refoutput.find("$n$", "$p:", "$?:").rename!("remainder", "id");

        // Simple equality check if no special tokens remain
        if (special.id == 0)
            return refoutput == output;

        const expected = refoutput[0 .. $ - special.remainder.length];

        // Check until the special token
        if (!output.skipOver(expected))
            return false;

        // Discard the special token and progress output appropriately
        refoutput = special.remainder[3 .. $];

        if (special.id == 1) // $n$
        {
            import std.ascii : isDigit;
            output.skipOver!isDigit();
            continue;
        }

        // $<identifier>:<special content>$
        /// ( special content, "$", remaining expected output )
        auto refparts = refoutput.findSplit("$");
        enforce(refparts, "Malformed special sequence!");
        refoutput = refparts[2];

        if (special.id == 2) // $p:<some path>$
        {
            // special content is the expected path tail
            // Substitute / with the appropriate directory separator
            auto pathEnd = refparts[0].replace("/", envData.sep);

            /// ( whole path, remaining output )
            auto parts = output.findSplitAfter(pathEnd);

            if (!parts || !exists(parts[0]))
                return false;

            output = parts[1];
            continue;
        }

        // $?:<predicate>=<content>(;<predicate>=<content>)*(;<default>)?$
        string toSkip = null;

        foreach (const chunk; refparts[0].splitter('|'))
        {
            // ( <predicate> , "=", <content> )
            const conditional = chunk.findSplit("=");

            if (!conditional) // <default>
            {
                toSkip = chunk;
                break;
            }
            // Match against OS or model (accepts "32mscoff" as "32")
            else if (conditional[0].splitter('+').all!(c => c.among(envData.os, envData.model, envData.model[0 .. min(2, $)])))
            {
                toSkip = conditional[2];
                break;
            }
        }

        if (toSkip !is null && !output.skipOver(toSkip))
            return false;
    }
}

unittest
{
    EnvData ed;
    version (Windows)
        ed.sep = `\`;
    else
        ed.sep = `/`;

    assert( compareOutput(`Grass is green`, `Grass is green`, ed));
    assert(!compareOutput(`Grass is green`, `Grass was green`, ed));

    assert( compareOutput(`Bob took 12 apples`, `Bob took $n$ apples`, ed));
    assert(!compareOutput(`Bob took abc apples`, `Bob took $n$ apples`, ed));
    assert(!compareOutput(`Bob took 12 berries`, `Bob took $n$ apples`, ed));

    assert( compareOutput(`HINT: ` ~ __FILE_FULL_PATH__ ~ ` is important`, `HINT: $p:d_do_test.d$ is important`, ed));
    assert( compareOutput(`HINT: ` ~ __FILE_FULL_PATH__ ~ ` is important`, `HINT: $p:test/tools/d_do_test.d$ is important`, ed));

    ed.sep = "/";
    assert(!compareOutput(`See /path/to/druntime/import/object.d`, `See $p:druntime/import/object.d$`, ed));

    assertThrown(compareOutput(`Path /a/b/c.d!`, `Path $p:c.d!`, ed)); // Missing closing $

    const fmt = "This $?:windows=A|posix=B|C$ uses $?:64=1|32=2|3$ bytes";

    assert( compareOutput("This C uses 3 bytes", fmt, ed));

    ed.os = "posix";
    ed.model = "64";
    assert( compareOutput("This B uses 1 bytes", fmt, ed));
    assert(!compareOutput("This C uses 3 bytes", fmt, ed));

    const emptyFmt = "On <$?:windows=abc|$> use <$?:posix=$>!";
    assert(compareOutput("On <> use <>!", emptyFmt, ed));

    ed.model = "32mscoff";
    assert(compareOutput("size_t is uint!", "size_t is $?:32=uint|64=ulong$!", ed));

    assert(compareOutput("no", "$?:posix+64=yes|no$", ed));
    ed.model = "64";
    assert(compareOutput("yes", "$?:posix+64=yes|no$", ed));
}

/++
Creates a diff of the expected and actual test output.

Params:
    expected     = the expected output
    expectedFile = file containing expected (if present, null otherwise)
    actual       = the actual output
    name         = the test files name

Returns: the comparison created by the `diff` utility
++/
string generateDiff(const string expected, string expectedFile,
    const string actual, const string name)
{
    string actualFile = tempDir.buildPath("actual_" ~ name);
    File(actualFile, "w").writeln(actual); // Append \n
    scope (exit) remove(actualFile);

    const needTmp = !expectedFile;
    if (needTmp) // Create a temporary file
    {
        expectedFile = tempDir.buildPath("expected_" ~ name);
        File(expectedFile, "w").writeln(expected); // Append \n
    }
    // Remove temporary file
    scope (exit) if (needTmp)
        remove(expectedFile);

    const cmd = ["diff", "-pu", "--strip-trailing-cr", expectedFile, actualFile];
    try
    {
        string diff = std.process.execute(cmd).output;
        // Skip diff's status lines listing the diffed files and line count
        foreach (_; 0..3)
            diff = diff.findSplitAfter("\n")[1];
        return diff;
    }
    catch (Exception e)
        return format(`%-(%s, %) failed: %s`, cmd, e.msg);
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
    bool fromRun; /// Compared execution instead of compilation output

    this(string expected, string actual, string diff, bool fromRun = false) {
        string msg = "\nexpected:\n----\n" ~ expected ~
            "\n----\nactual:\n----\n" ~ actual ~
            "\n----\ndiff:\n----\n" ~ diff ~ "----\n";
        super(msg);
        this.expected = expected;
        this.actual = actual;
        this.fromRun = fromRun;
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

    const test_file = args[1];
    string input_dir = test_file.dirName();

    TestArgs testArgs;
    switch (input_dir)
    {
        case "compilable":              testArgs.mode = TestMode.COMPILE;      break;
        case "fail_compilation":        testArgs.mode = TestMode.FAIL_COMPILE; break;
        case "runnable":                testArgs.mode = TestMode.RUN;          break;
        case "dshell":                  testArgs.mode = TestMode.DSHELL;       break;
        default:
            writefln("Error: invalid test directory '%s', expected 'compilable', 'fail_compilation', 'runnable' or 'dshell'", input_dir);
            return 1;
    }

    string test_base_name = test_file.baseName();
    string test_name = test_base_name.stripExtension();

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

    if (test_base_name.extension() == ".sh")
    {
        string file = cast(string) std.file.read(input_file);
        string disabledPlatforms;
        if (findTestParameter(envData, file, "DISABLED", disabledPlatforms))
        {
            const reason = getDisabledReason(split(disabledPlatforms), envData);
            if (reason.length != 0)
            {
                writefln(" ... %-30s [DISABLED %s]", input_file, reason);
                return 0;
            }
        }

        return runBashTest(input_dir, test_name);
    }

    if (testArgs.mode == TestMode.DSHELL)
        return runDShellTest(input_dir, test_name, envData, output_dir, output_file);

    // envData.sep is required as the results_dir path can be `generated`
    const absoluteResultDirPath = envData.results_dir.absolutePath ~ envData.sep;
    const resultsDirReplacement = "{{RESULTS_DIR}}" ~ envData.sep;

    // running & linking costs time - for coverage builds we can save this
    if (envData.coverage_build && testArgs.mode == TestMode.RUN)
        testArgs.mode = TestMode.COMPILE;

    if (envData.ccompiler.empty)
    {
        if (envData.os != "windows")
            envData.ccompiler = "c++";
        else if (envData.model == "32")
            envData.ccompiler = "dmc";
        else if (envData.model == "64")
            envData.ccompiler = `C:\"Program Files (x86)"\"Microsoft Visual Studio 10.0"\VC\bin\amd64\cl.exe`;
        else
            assert(0, "unknown $OS$MODEL combination: " ~ envData.os ~ envData.model);
    }

    envData.usingMicrosoftCompiler = envData.ccompiler.toLower.endsWith("cl.exe");

    const printRuntime = environment.get("PRINT_RUNTIME", "") == "1";
    auto stopWatch = StopWatch(AutoStart.no);
    if (printRuntime)
        stopWatch.start();

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
    if (!testArgs.isDisabled && testArgs.cppSources.length)
    {
        switch (envData.compiler)
        {
            case "dmd":
            case "ldc":
                if(envData.os != "windows")
                   testArgs.requiredArgs ~= " -L-lstdc++ -L--no-demangle";
                break;
            case "gdc":
                testArgs.requiredArgs ~= "-Xlinker -lstdc++ -Xlinker --no-demangle";
                break;
            default:
                writeln("unknown compiler: "~envData.compiler);
                return 1;
        }
        if (!collectExtraSources(input_dir, output_dir, testArgs.cppSources, testArgs.sources, envData, envData.ccompiler, testArgs.cxxflags))
            return 1;
    }
    //prepare objc extra sources
    if (!testArgs.isDisabled && !collectExtraSources(input_dir, output_dir, testArgs.objcSources, testArgs.sources, envData, "clang", null))
        return 1;

    writef(" ... %-30s %s%s(%s)",
            input_file,
            testArgs.requiredArgs,
            (!testArgs.requiredArgs.empty ? " " : ""),
            testArgs.permuteArgs);

    if (testArgs.isDisabled)
        writef("!!! [DISABLED %s]", testArgs.disabledReason);

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

                    execute(fThisRun, command, true, result_path);
                }
            }

            compile_output = compile_output.unifyNewLine();
            compile_output = std.regex.replaceAll(compile_output, regex(`^DMD v2\.[0-9]+.*\n? DEBUG$`, "m"), "");
            compile_output = std.string.strip(compile_output);
            // replace test_result path with fixed ones
            compile_output = compile_output.replace(result_path, resultsDirReplacement);
            compile_output = compile_output.replace(absoluteResultDirPath, resultsDirReplacement);

            auto m = std.regex.match(compile_output, `Internal error: .*$`);
            enforce(!m, m.hit);
            m = std.regex.match(compile_output, `core.exception.AssertError@dmd.*`);
            enforce(!m, m.hit);

            compile_output.applyOutputTransformations(testArgs.transformOutput);

            if (!compareOutput(compile_output, testArgs.compileOutput, envData))
            {
                // Allow any messages to come from tests if TEST_OUTPUT wasn't given.
                // This will be removed in future once all tests have been updated.
                if (testArgs.compileOutput !is null || testArgs.mode != TestMode.COMPILE)
                {
                    const diff = generateDiff(testArgs.compileOutput, testArgs.compileOutputFile,
                                                compile_output, test_base_name);
                    throw new CompareException(testArgs.compileOutput, compile_output, diff);
                }
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

                    // Always run main even if compiled with '-unittest' but let
                    // tests switch to another behaviour if necessary
                    if (!command.canFind("--DRT-testmode"))
                        command ~= " --DRT-testmode=run-main";

                    const output = execute(fThisRun, command, true, result_path)
                                    .strip()
                                    .unifyNewLine();

                    if (testArgs.runOutput && !compareOutput(output, testArgs.runOutput, envData))
                    {
                        const diff = generateDiff(testArgs.runOutput, null, output, test_base_name);
                        throw new CompareException(testArgs.runOutput, output, diff, true);
                    }
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
            if (testArgs.isDisabled)
            {
                writeln();
                return Result.return0;
            }

            if (envData.autoUpdate)
            if (auto ce = cast(CompareException) e)
            {
                // remove the output file in test_results as its outdated
                // (might fail for runnable tests on Windows)
                if (output_file.remove().collectException())
                    writef("\nWARNING: Failed to remove `%s`!", output_file);

                if (testArgs.compileOutputFile && !ce.fromRun)
                {
                    std.file.write(testArgs.compileOutputFile, ce.actual);
                    writefln("\n==> `TEST_OUTPUT_FILE` `%s` has been updated", testArgs.compileOutputFile);
                    return Result.return0;
                }

                auto existingText = input_file.readText;
                auto updatedText = existingText.replace(ce.expected, ce.actual);
                if (existingText != updatedText)
                {
                    std.file.write(input_file, updatedText);
                    writefln("\n==> `TEST_OUTPUT` of %s has been updated", input_file);
                }
                else
                {
                    writefln("\nWARNING: %s has multiple `TEST_OUTPUT` blocks and can't be auto-updated", input_file);
                }
                return Result.return0;
            }
            f.writeln();
            f.writeln("==============================");
            f.writef("Test %s failed: ", input_file);
            f.writeln(e.msg);
            f.close();

            writefln("\nTest %s failed.  The logged output:", input_file);
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
                import std.process : spawnShell;
                spawnShell(gdbCommand).wait;
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

    if (printRuntime)
    {
        const long ms = stopWatch.peek.total!"msecs";
        writefln("   [%.3f secs]", ms / 1000.0);
    }
    else
        writeln();

    // it was disabled but it passed! print an informational message
    if (testArgs.isDisabled)
        writefln(" !!! %-30s DISABLED but PASSES!", input_file);

    return 0;
}

int runBashTest(string input_dir, string test_name)
{
    const scriptPath = dmdTestDir.buildPath("tools", "sh_do_test.sh");
    version(Windows)
    {
        auto process = spawnShell(format("bash %s %s %s",
            scriptPath, input_dir, test_name));
    }
    else
    {
        auto process = spawnProcess([scriptPath, input_dir, test_name]);
    }
    return process.wait();
}

/// Return the correct pic flags
string[] getPicFlags()
{
    version (Windows) { } else
    {
        version(X86_64)
            return ["-fPIC"];
        if (environment.get("PIC", null) == "1")
            return ["-fPIC"];
    }
    return cast(string[])[];
}

/// Run a dshell test
int runDShellTest(string input_dir, string test_name, const ref EnvData envData,
    string output_dir, string output_file)
{
    const testScriptDir = buildPath(dmdTestDir, input_dir);
    const testScriptPath = buildPath(testScriptDir, test_name ~ ".d");
    const testOutDir = buildPath(output_dir, test_name);
    const testLogName = format("%s/%s.d", input_dir, test_name);

    writefln(" ... %s", testLogName);

    removeIfExists(output_file);
    if (exists(testOutDir))
        rmdirRecurse(testOutDir);
    mkdirRecurse(testOutDir);

    // create the "dshell" module for the tests
    {
        auto dshellFile = File(buildPath(testOutDir, "dshell.d"), "w");
        dshellFile.writeln(`module dshell;
public import dshell_prebuilt;
static this()
{
    dshellPrebuiltInit("` ~ input_dir ~ `", "`, test_name , `");
}
`);
    }

    const testScriptExe = buildPath(testOutDir, "run" ~ envData.exe);
    const output_file_temp = output_file ~ ".tmp";

    //
    // compile the test
    //
    {
        auto outfile = File(output_file_temp, "w");
        const compile = [envData.dmd, "-conf=", "-m"~envData.model] ~
            getPicFlags ~ [
            "-od" ~ testOutDir,
            "-of" ~ testScriptExe,
            "-I=" ~ testScriptDir,
            "-I=" ~ testOutDir,
            "-I=" ~ buildPath(dmdTestDir, "tools", "dshell_prebuilt"),
            "-i",
            // Causing linker errors for some reason?
            "-i=-dshell_prebuilt", buildPath(envData.results_dir, "dshell_prebuilt" ~ envData.obj),
            testScriptPath,
        ];
        outfile.writeln("[COMPILE_TEST] ", escapeShellCommand(compile));
        // Note that spawnprocess closes the file, so it will need to be re-opened
        // below when we run the test
        auto compileProc = std.process.spawnProcess(compile, stdin, outfile, outfile);
        const exitCode = wait(compileProc);
        if (exitCode != 0)
        {
            printTestFailure(testLogName, output_file_temp);
            return exitCode;
        }
    }

    //
    // run the test
    //
    {
        auto outfile = File(output_file_temp, "a");
        const runTest = [testScriptExe];
        outfile.writeln("[RUN_TEST] ", escapeShellCommand(runTest));
        auto runTestProc = std.process.spawnProcess(runTest, stdin, outfile, outfile);
        const exitCode = wait(runTestProc);
        if (exitCode != 0)
        {
            printTestFailure(testLogName, output_file_temp);
            return exitCode;
        }
    }

    rename(output_file_temp, output_file);
    // TODO: should we remove all the test artifacts if the test passes? rmdirRecurse(testOutDir)?
    return 0;
}

void printTestFailure(string testLogName, string output_file_temp)
{
    writeln("==============================");
    writefln("Test '%s' failed. The logged output:", testLogName);
    const output = readText(output_file_temp);
    write(output);
    if (!output.endsWith("\n"))
          writeln();
    writeln("==============================");
    remove(output_file_temp);
}

/// Make any parent diretories needed for the given `filename`
void mkdirsFor(string filename)
{
    auto dir = dirName(filename);
    if (!exists(dir))
        mkdirRecurse(dir);
}
