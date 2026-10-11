/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=19933
// https://issues.dlang.org/show_bug.cgi?id=18816

import core.stdc.stdio : FILE, fprintf, stderr;

extern(C) int main()
{
    // C stdio owns this shared global; the test only needs the current handle.
    fprintf(cast(FILE*) stderr, "Hello\n");
    return 0;
}
