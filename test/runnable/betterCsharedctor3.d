/* REQUIRED_ARGS: -betterC
 * PERMUTE_ARGS:
 */

import core.stdc.stdio;

shared static this()
{
    printf("hello\n");
}

extern (C) int main()
{
    printf("main()\n");
    return 0;
}
