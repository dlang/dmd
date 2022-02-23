import dshell;

int main()
{
    auto stderr_file = shellExpand("$OUTPUT_BASE/issue22817.err");
    auto stderr = File(stderr_file, "w");

    string cmd = "$DMD -m$MODEL -c $EXTRA_FILES/issue22817.d";
    string expected = "^Error: cannot find input file `$EXTRA_FILES/issue22817.d`";

    const exitCode = tryRun(parseCommand(cmd)), std.stdio.stdout, stderr);

    Vars.set("stderr", stderr_file);
    Vars.stderr
        .grep(shellExpand(expected).replace("/", SEP))
        .enforceMatches("Expected 'Error: cannot find input file'");

    return 0;
}
