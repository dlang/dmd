import dshell;
void main()
{
    Vars.set("libname", "$OUTPUT_BASE/a_b$LIBEXT");

    run("$DMD -m$MODEL -I$EXTRA_FILES -of$libname -c $EXTRA_FILES/mul9377a.d $EXTRA_FILES/mul9377b.d -lib");
    run("$DMD -m$MODEL -I$EXTRA_FILES -of$OUTPUT_BASE/a_b_full$EXE $EXTRA_FILES/multi9377.d $libname");
}
