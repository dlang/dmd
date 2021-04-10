/* TEST_OUTPUT:
---
fail_compilation/issue20704.d(21): Error: cannot modify constant `0`
       use `-preview=in` or `preview=rvaluerefparam`
fail_compilation/issue20704.d(32): Error: template instance `issue20704.f2!int` error instantiating
fail_compilation/issue20704.d(23): Error: cannot modify constant `0`
       use `-preview=in` or `preview=rvaluerefparam`
fail_compilation/issue20704.d(34): Error: template instance `issue20704.f4!int` error instantiating
fail_compilation/issue20704.d(21): Error: `S(0)` is not an lvalue and cannot be modified
       use `-preview=in` or `preview=rvaluerefparam`
fail_compilation/issue20704.d(40): Error: template instance `issue20704.f2!(S)` error instantiating
fail_compilation/issue20704.d(21): Error: `null` is not an lvalue and cannot be modified
       use `-preview=in` or `preview=rvaluerefparam`
fail_compilation/issue20704.d(42): Error: template instance `issue20704.f2!(C)` error instantiating
---
*/

// https://issues.dlang.org/show_bug.cgi?id=20704

void f1(T)(const auto ref T arg = T.init) {}
void f2(T)(const      ref T arg = T.init) {}
void f3(T)(const auto ref T arg = 0) {}
void f4(T)(const      ref T arg = 0) {}

struct S { int _; }
class C { int _; }

void main ()
{
    int i;
    f1!int(i);
    f2!int(i);
    f3!int(i);
    f4!int(i);
    f1!int();
    f2!int();
    f3!int();
    f4!int();
    f1!S();
    f2!S();
    f1!C();
    f2!C();
}
