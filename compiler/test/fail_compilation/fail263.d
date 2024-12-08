/*
TEST_OUTPUT:
----
fail_compilation/fail263.d(24): Error: function `f` is not callable using argument types `(const(byte)*)`
    f(A.ptr);
     ^
fail_compilation/fail263.d(24):        cannot pass argument `cast(const(byte)*)A` of type `const(byte)*` to parameter `byte* p`
fail_compilation/fail263.d(18):        `fail263.f(byte* p)` declared here
void f(byte* p)
     ^
----
*/

// https://issues.dlang.org/show_bug.cgi?id=2766
// DMD hangs with 0%cpu
const byte[] A = [ cast(byte)0 ];

void f(byte* p)
{
}

void func()
{
    f(A.ptr);
}
