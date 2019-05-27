import dshell;
void main()
{
    // Compile with/without -defaultlib=, make sure that the libraries
    // that were linked without -defaultlib= were not linked with it
    const verboseFileA = shellExpand("$OUTPUT_BASE/verbose_out_a");
    const verboseFileB = shellExpand("$OUTPUT_BASE/verbose_out_b");

    run("$DMD -m$MODEL -of${OUTPUT_BASE}a -v $EXTRA_FILES/noruntime.d",
        File(verboseFileA, "wb"));
    run("$DMD -m$MODEL -of${OUTPUT_BASE}b -v $EXTRA_FILES/noruntime.d -defaultlib=",
        File(verboseFileB, "wb"));

    version (Windows)
        immutable candidates = ["user32", "kernel32"];
    else
        immutable candidates = ["-lphobos2", "-lm", "-lrt", "-ldl"];

    string[] found = null;
    foreach (candidate; candidates)
    {
        if (grep(verboseFileA, candidate).matches)
            found ~= candidate;
        else
            writefln("did not find library '%s'", candidate);
    }
    writefln("found these libraries in verbose output: %s", found);

    bool fail = false;
    foreach (lib; found)
    {
        if (grep(verboseFileB, lib).matches)
        {
            writefln("Error: found library '%s' even with -defaultlib=", lib);
            fail = true;
        }
    }
    assert(!fail);
}
