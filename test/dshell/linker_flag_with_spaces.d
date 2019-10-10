import dshell;

void expandAndRun(string[] args...)
{
    import std.algorithm.iteration, std.array;
    const expandedArgs = args
        .map!(a => a.replace("/", "${SEP}"))
        .map!shellExpand
        .array;
    run(expandedArgs);
}

void main()
{
    const dir = "$OUTPUT_BASE/dir with spaces";
    const lib = dir ~ "/b$LIBEXT";

    mkdirFor(lib);
    expandAndRun("$DMD", "-m$MODEL", "-of" ~ lib,
        "-lib", "$EXTRA_FILES/linker_flag_with_spaces_b.d");
    expandAndRun("$DMD", "-m$MODEL", "-I$EXTRA_FILES", "-of$OUTPUT_BASE/a$EXE",
        "$EXTRA_FILES/linker_flag_with_spaces_a.d", "-L" ~ lib);
}
