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
        ~ " -m$MODEL -of$OUTPUT_BASE/main$EXE -conf= -fPIC -g -v -preview=noXlinker"
        ~ " -I$EXTRA_FILES/test6952/ -defaultlib="
        ~ " -L-nostartfiles -L-nostdlib -L-nodefaultlibs $EXTRA_FILES/test6952/main.d");

    // Remove DFLAGS environment variable.  Everything we need is explicitly stated in
    // the command line above.
    string[string] e;
    e["DFLAGS"] = "";

    // Compile the D code
    auto result = executeShell(cmd, e);
    assert(result.status == 0, "\n" ~ result.output);

    // due to `-v` the last line should be the command past to the linker driver; probably `cc`
    immutable lines = result.output.split("\n");
    auto ccLine = lines.find!(a => a.startsWith("cc"))[0];

    // Due to the `-preview=noXlinker` switch, the arguments prefixed with `-L` should
    // not have an additional `-Xlinker` prepended to them
    assert(ccLine.find("-Xlinker -nostartfiles") == "");
    assert(ccLine.find("-Xlinker -nostdlib") == "");
    assert(ccLine.find("-Xlinker -nodefaultlibs") == "");

    // This is the way it should look
    assert(ccLine.find("-nostartfiles -nostdlib -nodefaultlibs") != "");
}
