import dshell;
void main()
{
    Vars.set("libname", "$OUTPUT_BASE/a$LIBEXT");

    run("$DMD -m$MODEL -I$EXTRA_FILES -of$libname -c $EXTRA_FILES/mul9377a.d $EXTRA_FILES/mul9377b.d -lib");
    run("$DMD -m$MODEL -I$EXTRA_FILES -of$OUTPUT_BASE/a$EXE $EXTRA_FILES/multi9377.d $libname");
}
