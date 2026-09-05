// https://github.com/dlang/dmd/issues/20439
//
// A CTFE class/struct instance baked into a struct's `.init` needs a local backing symbol
// ("internal") in *every* object module that emits the init image. The symbol was cached on
// the shared AST node, so compiling two modules in one invocation (`dmd -c a.d b.d`) leaked
// the first object module's local symbol into the second, which then emitted only an
// undefined reference to a symbol it never defines:
// `b.o:(.data.rel.ro+0x8): undefined reference to 'internal'`.
//
// The issue used `SysTime.max`; reduced here to a plain CTFE instance to avoid importing
// Phobos (the test suite must not), exercising both toSymbol overloads (class + struct).
import dshell;

int main()
{
    // One invocation, two source files, separate object files (-c): issue20439a defines the
    // types (and emits the .init image + its local `internal`), issue20439 bakes __gshared
    // instances of them (and must define its own `internal`, not reference the other's).
    run("$DMD -m$MODEL -od$OUTPUT_BASE -I$IMPORT_FILES -c $IMPORT_FILES/issue20439a.d $EXTRA_FILES/issue20439.d");
    run("$DMD -m$MODEL -of$OUTPUT_BASE/issue20439$EXE $OUTPUT_BASE/issue20439a$OBJ $OUTPUT_BASE/issue20439$OBJ");
    run("$OUTPUT_BASE/issue20439$EXE");

    return 0;
}
