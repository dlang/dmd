#!/usr/bin/env rdmd
/**
Allows running tests individually

Usage:
  ./run_individual_tests.d <test-file>...

Example:
  ./run_individual_tests.d runnable/template2962.d fail_compilation/fail282.d

See the README.md for all available test targets
*/

void main(string[] args)
{
    import std.algorithm, std.conv, std.format, std.getopt, std.path, std.process, std.range, std.stdio, std.string;
    import std.parallelism : totalCPUs;

    const scriptDir = __FILE_FULL_PATH__.dirName;
    int jobs = totalCPUs;
    auto res = getopt(args,
        "j|jobs", "Specifies the number of jobs (commands) to run simultaneously (default: %d)".format(totalCPUs), &jobs,
    );
    if (res.helpWanted || args.length < 2)
    {
        defaultGetoptPrinter(`./run_individual_tests.d <test-file>...

Examples:

    ./run_individual_tests.d runnable/template2962.d
    ./run_individual_tests.d runnable/template2962.d fail_compilation/fail282.d

Options:
`, res.options);
        "\nSee the README.md for a more in-depth explanation of the test-runner.".writeln;
        return;
    }

    auto makeArguments = ["make", "--jobs=".text(jobs)]
            .chain(args.dropOne.map!(f =>
                format!"test_results/%s/%s.out"(f.absolutePath.dirName.baseName, f.baseName)))
            .array;
    spawnProcess(makeArguments, null, Config.none, scriptDir).wait;
}
