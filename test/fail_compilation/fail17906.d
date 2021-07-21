// REQUIRED_ARGS: -de
// https://issues.dlang.org/show_bug.cgi?id=18647
/* TEST_OUTPUT
---
fail_compilation/fail17906.d(11): Error: The `delete` keyword has been removed.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
---
*/
deprecated void main ()
{
    Object o = new Object;
    delete o;
}
