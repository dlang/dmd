import dshell;
void main()
{
    if (OS != "linux")
    {
        writefln("Skipping shared library test on %s.", OS);
        return;
    }

    run("$DMD -m$MODEL -of$OUTPUT_BASE/a$EXE -defaultlib=libphobos2.so $EXTRA_FILES/test_shared.d");
    run("$OUTPUT_BASE/a$EXE", stdout, [
        "LD_LIBRARY_PATH" : "../../phobos/generated/"~OS~"/release/"~MODEL
    ]);
}
