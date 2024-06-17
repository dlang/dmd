module test.dshell.cpp_header_gen;

import dshell;

int main()
{
    if (!CXX.length)
    {
        writeln("CPP header generation test was skipped because $CXX is empty!");
        return DISABLED;
    }

    Vars.set("SOURCE_DIR",  "$EXTRA_FILES/cpp_header_gen");
    Vars.set("LIB",         "$OUTPUT_BASE/library$LIBEXT");
    Vars.set("CPP_OBJ",     "$OUTPUT_BASE/cpp$OBJ");
    Vars.set("HEADER_EXE",  "$OUTPUT_BASE/test$EXE");

    run("$DMD -m$MODEL -c -lib -of=$LIB -HC=verbose -HCf=$OUTPUT_BASE/library.h $SOURCE_DIR/library.d");

    // Dump header if any of the following step fails
    scope (failure)
    {
        const file = buildPath(Vars.OUTPUT_BASE, "library.h");
        const header = (cast(string) read(file)).ifThrown("<Could not read file>\n");

        stderr.flush();
        writeln("========================= library.h ==================================\n");
        write(header);
        writeln("======================================================================\n");
        stdout.flush();
    }

    version (Windows)
        run([CXX, "/c", "/Fo" ~ Vars.CPP_OBJ, "/I" ~ OUTPUT_BASE, "/I" ~ EXTRA_FILES ~"/../../../src/dmd/root", Vars.SOURCE_DIR ~ "/app.cpp"]);
    else
        run("$CXX -m$MODEL -c -o $CPP_OBJ -I$OUTPUT_BASE -I$EXTRA_FILES/../../../src/dmd/root $SOURCE_DIR/app.cpp");
    run("$DMD -m$MODEL -conf= -of=$HEADER_EXE $LIB $CPP_OBJ");
    run("$HEADER_EXE");

    return 0;
}
