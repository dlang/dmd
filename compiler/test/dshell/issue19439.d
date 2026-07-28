// https://github.com/dlang/dmd/issues/19439
//
// The `-lib`/multiobj variant of #20439: a CTFE `new Object` baked into a class's `.init`
// is emitted with one object module per symbol, so the class init image and its "internal"
// backing symbol can land in different archive members. The symbol was cached on the shared
// AST node and emitted (locally) into only one member, leaving the member that holds
// `C.__init` with an undefined reference:
// `lib(c.o):(.data._D...1C6__initZ+0x10): undefined reference to 'internal'`.
import dshell;

int main()
{
    // class C (with the CTFE field) and derived class B live in separate modules, so their
    // codegen lands in separate archive members.
    run("$DMD -m$MODEL -lib -of$OUTPUT_BASE/issue19439$LIBEXT $IMPORT_FILES/issue19439b.d $IMPORT_FILES/issue19439c.d");
    run("$DMD -m$MODEL -I$IMPORT_FILES -of$OUTPUT_BASE/issue19439$EXE $EXTRA_FILES/issue19439.d $OUTPUT_BASE/issue19439$LIBEXT");
    run("$OUTPUT_BASE/issue19439$EXE");

    return 0;
}
