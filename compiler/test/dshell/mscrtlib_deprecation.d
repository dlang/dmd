module compiler.test.dshell.mscrtlib_deprecation;

// Selecting the deprecated MinGW replacement runtime (msvcrt120) must emit a
// deprecation warning. See the deprecation of non-UCRT C runtimes on Windows.
import dshell;

int main()
{
    // This deprecation only applies when targeting Windows.
    version (Windows) {} else
        return DISABLED;

    // The dedicated MinGW CI job compiles with `-d` (deprecations silenced) and
    // `-mscrtlib=msvcrt120` globally, which would hide the warning checked here.
    if (environment.get("C_RUNTIME", "") == "mingw")
        return DISABLED;

    const errFile = shellExpand("$OUTPUT_BASE.stderr");
    mkdirFor(errFile);

    // Compile only (-c) so neither a linker nor the MinGW import libraries are
    // required; the deprecation is emitted regardless of linking.
    {
        auto err = File(errFile, "w");
        tryRun("$DMD -m$MODEL -c -of$OUTPUT_BASE$OBJ -mscrtlib=msvcrt120 $EXTRA_FILES${SEP}mscrtlib_app.d",
            stdout, err);
        err.close();
    }

    grep(errFile, "msvcrt120").enforceMatches("expected a deprecation warning for -mscrtlib=msvcrt120");

    return 0;
}
