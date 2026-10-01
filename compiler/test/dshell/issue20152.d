import dshell;

void main()
{
    Vars.set("libname", "$OUTPUT_BASE/issue20152$LIBEXT");

    run("$DMD -m$MODEL -of$libname -lib $EXTRA_FILES/issue20152.c");
    run("$DMD -m$MODEL -I$EXTRA_FILES -of$OUTPUT_BASE/issue20152$EXE $EXTRA_FILES/issue20152main.d $libname");
    run("$OUTPUT_BASE/issue20152$EXE");
}
