/*
TEST_OUTPUT:
---
fail_compilation/diag8894.d(36): Error: no property `x` for `f` of type `diag8894.Foo`
    f.x;           // UFCS getter1
     ^
fail_compilation/diag8894.d(31):        struct `Foo` defined here
struct Foo { }
^
fail_compilation/diag8894.d(37): Error: no property `y` for `f` of type `diag8894.Foo`
    f.y!int;       // UFCS getter2
     ^
fail_compilation/diag8894.d(31):        struct `Foo` defined here
struct Foo { }
^
fail_compilation/diag8894.d(38): Error: no property `x` for `f` of type `diag8894.Foo`
    f.x     = 10;  // UFCS setter1
     ^
fail_compilation/diag8894.d(31):        struct `Foo` defined here
struct Foo { }
^
fail_compilation/diag8894.d(39): Error: no property `x` for `f` of type `diag8894.Foo`
    f.x!int = 10;  // UFCS setter2
     ^
fail_compilation/diag8894.d(31):        struct `Foo` defined here
struct Foo { }
^
---
*/

struct Foo { }

void main()
{
    Foo f;
    f.x;           // UFCS getter1
    f.y!int;       // UFCS getter2
    f.x     = 10;  // UFCS setter1
    f.x!int = 10;  // UFCS setter2
}
