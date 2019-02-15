/* PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/imphint.d(15): Error: `printf` is not defined, perhaps `import core.stdc.stdio;` is needed?
fail_compilation/imphint.d(16): Error: `writeln` is not defined, perhaps `import std.stdio;` is needed?
fail_compilation/imphint.d(17): Error: `sin` is not defined, perhaps `import std.math;` is needed?
fail_compilation/imphint.d(18): Error: `cos` is not defined, perhaps `import std.math;` is needed?
fail_compilation/imphint.d(19): Error: `sqrt` is not defined, perhaps `import std.math;` is needed?
fail_compilation/imphint.d(20): Error: `fabs` is not defined, perhaps `import std.math;` is needed?
---
*/

void foo()
{
    printf("hello world\n");
    writeln("hello world\n");
    sin(3.6);
    cos(1.2);
    sqrt(2.0);
    fabs(-3);
}
