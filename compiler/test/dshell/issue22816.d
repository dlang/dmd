import dshell;

int main()
{
    auto stderr_file = shellExpand("$OUTPUT_BASE/issue22816.err");
    auto stderr = File(stderr_file, "w");

    string cmd = "$DMD -m$MODEL -c $EXTRA_FILES/issue22816.c";
    string expected = shellExpand("^Error: cannot find input file `$EXTRA_FILES" ~ SEP ~ "issue22816.c`");

    version (Windows)
        expected = expected.replace(`\`, `\\`); // Replace \ => \\ for regex

    const exitCode = tryRun(cmd, std.stdio.stdout, stderr);
    assert(exitCode == 1, "DMD should've failed!");

    Vars.set("stderr", stderr_file);
    Vars.stderr
        .grep(expected)
        .enforceMatches("Expected 'Error: cannot find input file'");

    return 0;
}
