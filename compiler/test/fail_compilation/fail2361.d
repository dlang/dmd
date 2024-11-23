/*
TEST_OUTPUT:
---
fail_compilation/fail2361.d(16): Error: the `delete` keyword is obsolete
    delete c;
    ^
fail_compilation/fail2361.d(16):        use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead
---
*/

class C {}

void main()
{
    immutable c = new immutable(C);
    delete c;
}
