// ARG_SETS: -preview=all
// ARG_SETS: -transition=all
// ARG_SETS: -revert=all
// TRANSFORM_OUTPUT: remove_lines(druntime)
import core.stdc.stdio;

void main (string[] args)
{
    if (args.length == 42)
        printf("Hello World\n");
}
