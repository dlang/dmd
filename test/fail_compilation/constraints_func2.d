/*
TEST_OUTPUT:
---
fail_compilation/constraints_func2.d(93): Error: template `imports.constraints.test13` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(23):        `test13(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       !P!T`
fail_compilation/constraints_func2.d(94): Error: template `imports.constraints.test14` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(24):        `test14(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       !P!T
       N!T`
fail_compilation/constraints_func2.d(95): Error: template `imports.constraints.test15` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(25):        `test15(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       !P!T
       !P!T`
fail_compilation/constraints_func2.d(96): Error: template `imports.constraints.test16` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(26):        `test16(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
fail_compilation/constraints_func2.d(97): Error: template `imports.constraints.test17` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(27):        `test17(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_func2.d(98): Error: template `imports.constraints.test18` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(28):        `test18(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
fail_compilation/constraints_func2.d(99): Error: template `imports.constraints.test19` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(29):        `test19(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       !P!T
       N!T`
fail_compilation/constraints_func2.d(100): Error: template `imports.constraints.test20` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(30):        `test20(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_func2.d(101): Error: template `imports.constraints.test21` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(31):        `test21(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
fail_compilation/constraints_func2.d(102): Error: template `imports.constraints.test22` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(32):        `test22(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       !P!T
       !P!T`
fail_compilation/constraints_func2.d(103): Error: template `imports.constraints.test23` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(33):        `test23(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       !P!T
       N!T
       !P!T`
fail_compilation/constraints_func2.d(104): Error: template `imports.constraints.test24` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(34):        `test24(R)(R r)`
  with `R = int`
  must satisfy the following constraint:
`       __traits(hasMember, R, "stuff")`
fail_compilation/constraints_func2.d(105): Error: template `imports.constraints.test25` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(35):        `test25(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_func2.d(106): Error: template `imports.constraints.test26` cannot deduce function from argument types `!(float)(int)`, candidates are:
fail_compilation/imports/constraints.d(36):        `test26(T, U)(U u)`
  with `T = float,
       U = int`
  must satisfy the following constraint:
`       N!U`
---
*/

void main()
{
    import imports.constraints;

    test13(0);
    test14(0);
    test15(0);
    test16(0);
    test17(0);
    test18(0);
    test19(0);
    test20(0);
    test21(0);
    test22(0);
    test23(0);
    test24(0);
    test25(0);
    test26!float(5);
}
