// EXTRA_FILES: imports/test15785.d
/*
TEST_OUTPUT:
---
fail_compilation/test15785b.d(20): Error: `imports.test15785.Base.T` is not visible from module `test15785b`
    typeof(super).T t;
                    ^
fail_compilation/test15785b.d(21): Error: `imports.test15785.Base.T` is not visible from module `test15785b`
    Base.T t2;
           ^
fail_compilation/test15785b.d(22): Error: `imports.test15785.IBase2.T` is not visible from module `test15785b`
    IBase2.T t3;
             ^
---
*/
import imports.test15785;

class Derived : Base, IBase2
{
    typeof(super).T t;
    Base.T t2;
    IBase2.T t3;
}
