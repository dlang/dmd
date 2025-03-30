// https://issues.dlang.org/show_bug.cgi?id=23439
// PERMUTE_ARGS: -lowmem
/* TEST_OUTPUT:
---
fail_compilation/fail23439.d(14): Error: variable `fail23439.ice23439` is a thread-local class and cannot have a static initializer
fail_compilation/fail23439.d(14):        use `static this()` to initialize instead
---
*/
class C23439
{
    noreturn f23439;
}

static ice23439 = new C23439();
