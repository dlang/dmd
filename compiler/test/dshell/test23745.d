import dshell;

// https://github.com/dlang/dmd/issues/23745
// Nested functions were inline-scanned in symbol-table bucket order, which
// follows the Identifier addresses, so -inline codegen varied under ASLR.
void main()
{
    const obj = shellExpand("$OUTPUT_BASE/test23745$OBJ");
    const(ubyte)[] first;
    foreach (i; 0 .. 10)
    {
        run("$DMD -m$MODEL -c -inline -of$OUTPUT_BASE/test23745$OBJ"
            ~ " $EXTRA_FILES/test23745.d");
        const bytes = cast(const(ubyte)[]) std.file.read(obj);
        if (i == 0)
            first = bytes;
        else
            enforce(bytes == first, "-inline codegen differs between identical runs");
    }
}
