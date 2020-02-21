module test.dshell.cpp_header_gen;

import dshell;

void main()
{
    if (OS != "linux")
    {
        writeln("CPP header generation test was skipped on non-linux platform.");
        return;
    }

    // FIXME: Should be a default variable
    Vars.set("CC", "g++");

    Vars.set("SOURCE_DIR",  "$EXTRA_FILES/cpp_header_gen");
    Vars.set("LIB",         "$OUTPUT_BASE/lib$LIBEXT");
    Vars.set("CPP_OBJ",     "$OUTPUT_BASE/cpp.o");
    Vars.set("HEADER_EXE",  "$OUTPUT_BASE/test");

    run("$DMD -m$MODEL -c -lib -of=$LIB -HCf=$OUTPUT_BASE/library.h $SOURCE_DIR/library.d");
    run("$CC -m$MODEL -c -o $CPP_OBJ -I$OUTPUT_BASE -I$EXTRA_FILES/../../../src/dmd/root $SOURCE_DIR/app.cpp");
    run("$DMD -m$MODEL -conf= -defaultlib= -of=$HEADER_EXE $LIB $CPP_OBJ");
    run("$HEADER_EXE");
}
