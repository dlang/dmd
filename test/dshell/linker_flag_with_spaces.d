import dshell;

void main()
{
    version (DigitalMars)
    {
        if (OS == "windows" && MODEL == "32")
        {
            writeln("Skipping test when using Optlink.");
            return;
        }
    }

    Vars.set("lib", "$OUTPUT_BASE/dir with spaces/b$LIBEXT");

    run("$DMD -m$MODEL -of$lib -lib $EXTRA_FILES/linker_flag_with_spaces_b.d");
    run("$DMD -m$MODEL -I$EXTRA_FILES -of$OUTPUT_BASE/a$EXE $EXTRA_FILES/linker_flag_with_spaces_a.d -L$lib");
}
