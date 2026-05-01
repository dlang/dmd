/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=19933
// https://issues.dlang.org/show_bug.cgi?id=18816

import core.atomic : atomicLoad;
import core.stdc.stdio : fprintf, stderr;

extern(C) int main()
{
    fprintf(atomicLoad(stderr), "Hello\n");
    return 0;
}
