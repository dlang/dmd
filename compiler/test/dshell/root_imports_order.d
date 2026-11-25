/*
`a` and `b` instantiate `S!int` and import each other through `x`.
Compiling one with the other as a non-root module may only elide the
instance if that module doesn't import a root module, whatever the order
of the root modules on the command line.
*/
import dshell;

void main()
{
    const dir = "$EXTRA_FILES/root_imports_order";
    const dmd = "$DMD -m$MODEL -I" ~ dir ~ " -od$OUTPUT_BASE ";
    run(dmd ~ "-c " ~ dir ~ "/main.d " ~ dir ~ "/a.d");
    run(dmd ~ "-c " ~ dir ~ "/unrelated.d " ~ dir ~ "/b.d");
    run(dmd ~ "-c " ~ dir ~ "/x.d");
    run("$DMD -m$MODEL -of$OUTPUT_BASE/main$EXE $OUTPUT_BASE/main$OBJ $OUTPUT_BASE/a$OBJ"
        ~ " $OUTPUT_BASE/unrelated$OBJ $OUTPUT_BASE/b$OBJ $OUTPUT_BASE/x$OBJ");
    run("$OUTPUT_BASE/main$EXE");
}
