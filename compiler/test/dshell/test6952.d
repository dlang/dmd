import dshell;
import std.algorithm : find;

int main()
{
    if (OS == "windows")
    {
        writefln("Skipping test6952.d for %s.", OS);
        return DISABLED;
    }

    auto cmd = shellExpand("$DMD"
        ~ " -m$MODEL -of$OUTPUT_BASE/main$EXE -conf= -fPIC -g -v"
        ~ " -I$EXTRA_FILES/test6952/ -defaultlib="
        ~ " -Xcc=-nostartfiles -Xcc=-nostdlib -Xcc=-nodefaultlibs $EXTRA_FILES/test6952/main.d");

    // Remove DFLAGS environment variable.  Everything we need is explicitly stated in
    // the command line above.
    string[string] e;
    e["DFLAGS"] = "";
    // Use our custom linker wrapper in order not to depend on the platform's CC
    const ccWrapper = shellExpand("$OUTPUT_BASE/test6952.fakeLinker.sh");
    e["CC"] = ccWrapper;

    // And make this explicit
    const outputFile = shellExpand("$OUTPUT_BASE/test6952.last_test_output.txt");
    // Write the wrapper script...
    std.file.write(ccWrapper, "#!/usr/bin/env bash\nset -e\necho \"$@\" > " ~ outputFile ~ "\n");
    run("chmod +x " ~ ccWrapper);

    // Compile the D code
    run(cmd, std.stdio.stdout, std.stdio.stderr, e);

    // This test used to parse the compiler output (using `-v`),
    // but that turned out to be quite brittle.
    // Instead, just provide a wrapper script via CC and write the arguments
    // to a file, and inspect what has been written.
    const result = readText(outputFile);
    immutable lines = result.split("\n");
    if (!lines.length || !lines[0].length)
        assert(0, "The CC wrapper didn't write to " ~ outputFile ~ ":\n" ~ result);
    auto line = lines[0];

    // The arguments prefixed with `-Xcc` should not have an
    // additional `-Xlinker` prepended to them
    assert(line.find("-Xlinker -nostartfiles") == "");
    assert(line.find("-Xlinker -nostdlib") == "");
    assert(line.find("-Xlinker -nodefaultlibs") == "");

    // This is the way it should look
    assert(line.find("-nostartfiles -nostdlib -nodefaultlibs") != "");

    return 0;
}
