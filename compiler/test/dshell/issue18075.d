import dshell;
import std.algorithm.searching : canFind;
import std.file : read;

int main()
{
    if (OS == "windows")
    {
        writefln("Skipping %s for %s.", TEST_NAME, OS);
        return DISABLED;
    }

    const src = shellExpand("$EXTRA_FILES/issue18075.d");

    void checkRun(string dmdFlags, string[] appArgs, string[] expectedTokens, string[] forbiddenTokens)
    {
        const exe = shellExpand("$OUTPUT_BASE/app$EXE");
        const stderrFile = shellExpand("$OUTPUT_BASE/app.err");

        run("$DMD -m$MODEL " ~ dmdFlags ~ " -of" ~ exe ~ " " ~ src);

        auto stderr = File(stderrFile, "w");
        const exitCode = tryRun([exe] ~ appArgs, std.stdio.stdout, stderr);
        assert(exitCode != 0, "Expected process to exit with non-zero status on assertion failure");

        stderr.close();
        const output = cast(const(ubyte)[]) read(stderrFile);

        foreach (token; expectedTokens)
        {
            const tokenBytes = cast(const(ubyte)[]) token;
            assert(output.canFind(tokenBytes),
                "Expected output to contain '" ~ token ~ "' but got:\n" ~ (cast(const(char)[]) output));
        }

        foreach (token; forbiddenTokens)
        {
            const tokenBytes = cast(const(ubyte)[]) token;
            assert(!output.canFind(tokenBytes),
                "Output unexpectedly contained forbidden '" ~ token ~ "':\n" ~ (cast(const(char)[]) output));
        }
    }

    // 1. -checkaction=C without inlining reports original expression and line 14
    checkRun("-checkaction=C", [], ["check(&", "data)", "14"], ["mydata*", "(*p)"]);

    // 2. -checkaction=C with inlining reports original expression and line 14 (issue #18075)
    checkRun("-inline -checkaction=C", [], ["check(&", "data)", "14"], ["mydata*", "(*p)"]);

    // 3. -checkaction=C with inlining and explicit message preserves custom message and line 20
    checkRun("-inline -checkaction=C", ["msg"], ["custom assert message", "20"], ["mydata*"]);

    // 4. -checkaction=D with inlining retains normal AssertError behavior
    checkRun("-inline -checkaction=D", [], ["core.exception.AssertError", "14"], []);

    // 5. -checkaction=context with inlining retains normal context behavior
    checkRun("-inline -checkaction=context", [], ["false != true", "14"], []);

    return 0;
}
