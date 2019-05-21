/*
TEST_OUTPUT:
---
fail_compilation/constraints_func1.d(78): Error: template `imports.constraints.test1` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(9):        `test1(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_func1.d(79): Error: template `imports.constraints.test2` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(10):        `test2(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       !P!T`
fail_compilation/constraints_func1.d(80): Error: template `imports.constraints.test3` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(11):        `test3(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_func1.d(81): Error: template `imports.constraints.test4` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(12):        `test4(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_func1.d(82): Error: template `imports.constraints.test5` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(13):        `test5(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
fail_compilation/constraints_func1.d(83): Error: template `imports.constraints.test6` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(14):        `test6(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T
       !P!T`
fail_compilation/constraints_func1.d(84): Error: template `imports.constraints.test7` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(15):        `test7(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
fail_compilation/constraints_func1.d(85): Error: template `imports.constraints.test8` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(16):        `test8(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_func1.d(86): Error: template `imports.constraints.test9` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(17):        `test9(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       !P!T`
fail_compilation/constraints_func1.d(87): Error: template `imports.constraints.test10` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(18):        `test10(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       !P!T`
fail_compilation/constraints_func1.d(88): Error: template `imports.constraints.test11` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(19):        `test11(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       !P!T`
fail_compilation/constraints_func1.d(89): Error: template `imports.constraints.test12` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/imports/constraints.d(20):        `test12(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       !P!T`
fail_compilation/constraints_func1.d(91): Error: template `imports.constraints.test1` cannot deduce function from argument types `!()(int, int)`, candidates are:
fail_compilation/imports/constraints.d(9):        `test1(T)(T v)`
---
*/

void main()
{
    import imports.constraints;

    test1(0);
    test2(0);
    test3(0);
    test4(0);
    test5(0);
    test6(0);
    test7(0);
    test8(0);
    test9(0);
    test10(0);
    test11(0);
    test12(0);

    test1(0, 0);
}
