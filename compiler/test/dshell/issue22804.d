import dshell;

int main()
{
    run("$DMD -m$MODEL -od$OUTPUT_BASE -c $IMPORT_FILES/issue22804_1.d $IMPORT_FILES/issue22804_2.d");
    run("$DMD -m$MODEL -I$IMPORT_FILES -of$OUTPUT_BASE/a$EXE $EXTRA_FILES/issue22804.d $OUTPUT_BASE/issue22804_1$OBJ $OUTPUT_BASE/issue22804_2$OBJ");

    return 0;
}
