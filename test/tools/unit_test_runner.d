#!/usr/bin/env rdmd
module unit_test_runner;

import std.algorithm : filter, map, joiner, substitute;
import std.array : array, join;
import std.conv : to;
import std.exception : enforce;
import std.file : dirEntries, exists, SpanMode, mkdirRecurse, write;
import std.format : format;
import std.getopt : getopt;
import std.path : absolutePath, buildPath, dirSeparator, stripExtension,
    setExtension;
import std.process : environment, execute;
import std.range : empty;
import std.stdio;
import std.string : join, outdent;

import tools.paths;

enum unitTestDir = testPath("unit");

string[] testFiles(Range)(Range givenFiles)
{
    if (!givenFiles.empty)
        return givenFiles.map!(testPath).array;

    return unitTestDir
        .dirEntries("*.d", SpanMode.depth)
        .map!(e => e.name)
        .array;
}

auto moduleNames(const string[] testFiles)
{
    return testFiles
        .map!(e => e[unitTestDir.length + 1 .. $])
        .map!stripExtension
        .array
        .map!(e => e.substitute(dirSeparator, "."));
}

void writeRunnerFile(Range)(Range moduleNames, string path, string filter)
{
    enum codeTemplate = q{
        import core.runtime : Runtime, UnitTestResult;
        import std.meta : AliasSeq;

        // modules to unit test starts here:
        %s

        alias modules = AliasSeq!(
            %s
        );

        enum filter = %s;

        version(unittest) shared static this()
        {
            Runtime.extendedModuleUnitTester = &unitTestRunner;
        }

        UnitTestResult unitTestRunner()
        {
            import std.algorithm : any, canFind, each, map;
            import std.array : array;
            import std.conv : text;
            import std.format : format;
            import std.meta : Alias;
            import std.range : chain, empty, enumerate, only, repeat;
            import std.stdio : writeln, writefln, stderr, stdout;
            import std.string : join;
            import std.traits : hasUDA, isCallable;

            static import support;

            alias TestCallback = void function();

            struct Test
            {
                Throwable throwable;
                string[] descriptions;

                string toString(size_t i)
                {
                    const descs = descriptions;
                    const index = text(i + 1) ~ ") ";

                    enum fmt = "%%s%%s\n%%s";

                    if (descs.length < 2)
                        return format!fmt(index, descriptions.join(""), throwable);

                    auto trailing = descs[1 .. $]
                        .map!(e => ' '.repeat(index.length).array ~ e);

                    const description = descriptions[0]
                        .only
                        .chain(trailing)
                        .join("\n");

                    return format!fmt(index, description, throwable);
                }

                string fileInfo()
                {
                    with (throwable)
                        return format!"%%s:%%s"(file, line);
                }
            }

            Test[] failedTests;
            size_t testCount;

            void printReport()
            {
                if (!failedTests.empty)
                {
                    alias formatTest = t => t.value.toString(t.index);

                    const failedTestsMessage = failedTests
                        .enumerate
                        .map!(formatTest)
                        .join("\n\n");

                    stderr.writefln!"Failures:\n\n%%s\n"(failedTestsMessage);
                }

                auto output = failedTests.empty ? stdout : stderr;
                output.writefln!"%%s tests, %%s failures"(testCount, failedTests.length);

                if (failedTests.empty)
                    return;

                stderr.writefln!"\nFailed tests:\n%%s"(
                    failedTests.map!(t => t.fileInfo).join("\n"));
            }

            TestCallback[] getTestCallbacks(alias module_, alias uda)()
            {
                enum isMemberAccessible(string memberName) =
                    is(typeof(__traits(getMember, module_, memberName)));

                TestCallback[] callbacks;

                static foreach(mem ; __traits(allMembers, module_))
                {
                    static if (isMemberAccessible!(mem))
                    {{
                        alias member = __traits(getMember, module_, mem);

                        static if (isCallable!member && hasUDA!(member, uda))
                            callbacks ~= &member;
                    }}
                }

                return callbacks;
            }

            void executeCallbacks(const TestCallback[] callbacks)
            {
                callbacks.each!(c => c());
            }

            static foreach (module_ ; modules)
            {
                foreach (unitTest ; __traits(getUnitTests, module_))
                {
                    enum attributes = [__traits(getAttributes, unitTest)];

                    const beforeEachCallbacks = getTestCallbacks!(module_, support.beforeEach);
                    const afterEachCallbacks = getTestCallbacks!(module_, support.afterEach);

                    Test test;

                    try
                    {
                        static if (!attributes.empty)
                        {
                            test.descriptions = attributes;

                            if (attributes.any!(a => a.canFind(filter)))
                            {
                                testCount++;
                                executeCallbacks(beforeEachCallbacks);
                                unitTest();
                            }
                        }

                        else static if (filter.length == 0)
                        {
                            testCount++;
                            executeCallbacks(beforeEachCallbacks);
                            unitTest();
                        }
                    }

                    catch (Throwable t)
                    {
                        test.throwable = t;
                        failedTests ~= test;
                    }

                    finally
                        executeCallbacks(afterEachCallbacks);
                }
            }

            printReport();

            UnitTestResult result = {
                runMain: false,
                executed: testCount,
                passed: testCount - failedTests.length
            };

            return result;
        }
    }.outdent;

    const imports = moduleNames
        .map!(e => format!"static import %s;"(e))
        .joiner("\n")
        .to!string;

    const modules = moduleNames
        .map!(e => format!"%s"(e))
        .joiner(",\n")
        .to!string;

    const content = format!codeTemplate(imports, modules, format!`"%s"`(filter));
    write(path, content);
}

/**
Writes a cmdfile with all the compiler flags to the given `path`.

Params:
    path = the path where to write the cmdfile file
    runnerPath = the path of the unit test runner file outputted by `writeRunnerFile`
    outputPath = the path where to place the compiled binary
    testFiles = the test files to compile
*/
void writeCmdfile(string path, string runnerPath, string outputPath,
    const string[] testFiles)
{
    auto flags = [
        "-version=NoBackend",
        "-version=GC",
        "-version=NoMain",
        "-version=MARS",
        "-version=DMDLIB",
        "-unittest",
        "-J" ~ buildOutputPath,
        "-J" ~ projectRootDir.buildPath("src/dmd/res"),
        "-I" ~ projectRootDir.buildPath("src"),
        "-I" ~ unitTestDir,
        "-i",
        "-main",
        "-of" ~ outputPath,
        "-m" ~ model
    ] ~ testFiles ~ runnerPath;

    // Generate coverage reports if requested
    if (environment.get("DMD_TEST_COVERAGE", "0") == "1")
        flags ~= "-cov";

    // older versions of Optlink causes: "Error 45: Too Much DEBUG Data for Old CodeView format"
    if (!usesOptlink)
        flags ~= "-g";

    write(path, flags.join("\n"));
}

/**
Returns `true` if any of the given files don't exist.

Also prints an error message.
*/
bool missingTestFiles(Range)(Range givenFiles)
{
    const nonExistingTestFiles = givenFiles
        .filter!(file => !file.exists)
        .join("\n");

    if (!nonExistingTestFiles.empty)
    {
        stderr.writefln("The following test files don't exist:\n\n%s",
            nonExistingTestFiles);

        return true;
    }

    return false;
}

bool usesOptlink()
{
    version (DigitalMars)
        return os == "windows" && model == "32";

    else
        return false;
}

int main(string[] args)
{
    string unitTestFilter;
    getopt(args, "filter|f", &unitTestFilter);

    auto givenFiles = args[1 .. $].map!absolutePath;

    if (missingTestFiles(givenFiles))
        return 1;

    const runnerPath = resultsDir.buildPath("runner.d");
    const testFiles = givenFiles.testFiles;

    mkdirRecurse(resultsDir);
    testFiles
        .moduleNames
        .writeRunnerFile(runnerPath, unitTestFilter);

    const cmdfilePath = resultsDir.buildPath("cmdfile");
    const outputPath = resultsDir.buildPath("runner").setExtension(exeExtension);
    writeCmdfile(cmdfilePath, runnerPath, outputPath, testFiles);

    scope const compile = [ dmdPath, "@" ~ cmdfilePath ];
    const dmd = execute(compile);
    if (dmd.status)
    {
        enum msg = "Failed to compile the `unit` test executable! (exit code %d)

> %-(%s %)
%s";
        // Build the string in advance to avoid cluttering
        writeln(format(msg, dmd.status, compile, dmd.output));
        return 1;
    }

    const test = execute(outputPath);
    if (test.status)
    {
        enum msg = "Failed to execute the `unit` test executable! (exit code %d)

> %-(%s %)
%s
> %s
%s";
        // Build the string in advance to avoid cluttering
        writeln(format(msg, test.status, compile, dmd.output, outputPath, test.output));
        return 1;
    }

    return 0;
}
