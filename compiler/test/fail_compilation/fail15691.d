/*
TEST_OUTPUT:
---
fail_compilation/fail15691.d(19): Error: `c` is not a member of `Foo`
            c: 4,  // line 15
               ^
fail_compilation/fail15691.d(24): Error: `bc` is not a member of `Foo`, did you mean variable `abc`?
            bc: 4, // line 20
                ^
---
*/

struct Foo { int a; int abc; }

void main()
{
    Foo z = {      // line 13
            a: 3,
            c: 4,  // line 15
        };

    Foo z2 = {     // line 18
            a: 3,
            bc: 4, // line 20
        };
}
