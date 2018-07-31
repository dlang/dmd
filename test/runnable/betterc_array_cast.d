/* REQUIRED_ARGS: -betterC
   PERMUTE_ARGS:
 */

// test call to `object.__ArrayCast`

import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.string;

extern(C) void __assert(const char *msg, const char *file, int line)
{
    if (strcmp(msg, "array cast misalignment") != 0)
    {
        fprintf(stderr, "Assertion failure message is not correct\n");
        exit(1);
    }
}

extern(C) void main()
{
    byte[] b;
    long[] l;

    // We can't actually create dynamic arrays in idiomatic D when
    // compiling with -betterC, so we do it manually.
    auto b_length = cast(size_t*)&b;
    auto b_ptr = cast(void*)(b_length + 1);
    *b_length = int.sizeof * 3;
    b_ptr = malloc(*b_length);

    // size mismatch, should result in an assertion failure
    l = cast(long[])b;
}
