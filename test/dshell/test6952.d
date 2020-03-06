import dshell;
import std.algorithm : find;

void main()
{
    if (OS != "linux")
    {
        writefln("Skipping test6952.d for %s.", OS);
        return;
    }

    auto cmd = shellExpand("$DMD"
        ~ " -m$MODEL -of$OUTPUT_BASE/main$EXE -conf= -fPIC -g -v"
        ~ " -I$EXTRA_FILES/test6952/ -defaultlib="
        ~ " -Xcc=-nostartfiles -Xcc=-nostdlib -Xcc=-nodefaultlibs $EXTRA_FILES/test6952/main.d");

    // Remove DFLAGS environment variable.  Everything we need is explicitly stated in
    // the command line above.
    string[string] e;
    e["DFLAGS"] = "";

    // Compile the D code
    auto result = executeShell(cmd, e);
    assert(result.status == 0, "\n" ~ result.output);

    // due to `-v` the last line should be the command past to the linker driver; probably `cc`
    immutable lines = result.output.split("\n");
    auto foundLines = lines.find!(a => a.startsWith("cc"));
    if (!foundLines.length)
        foundLines = lines.find!(a => a.startsWith("gcc"));
    if (!foundLines.length)
        assert(0, "Couldn't find 'cc' in compiler output:\n" ~ result.output);
    auto ccLine = foundLines[0];

    // The arguments prefixed with `-Xcc` should not have an
    // additional `-Xlinker` prepended to them
    assert(ccLine.find("-Xlinker -nostartfiles") == "");
    assert(ccLine.find("-Xlinker -nostdlib") == "");
    assert(ccLine.find("-Xlinker -nodefaultlibs") == "");

    // This is the way it should look
    assert(ccLine.find("-nostartfiles -nostdlib -nodefaultlibs") != "");
}
