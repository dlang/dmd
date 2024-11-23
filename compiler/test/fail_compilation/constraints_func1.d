/*
EXTRA_FILES: imports/constraints.d
TEST_OUTPUT:
---
fail_compilation/constraints_func1.d(131): Error: template `test1` is not callable using argument types `!()(int)`
    test1(0);
         ^
fail_compilation/imports/constraints.d(9):        Candidate is: `test1(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
void test1(T)(T v) if (N!T);
     ^
fail_compilation/constraints_func1.d(132): Error: template `test2` is not callable using argument types `!()(int)`
    test2(0);
         ^
fail_compilation/imports/constraints.d(10):        Candidate is: `test2(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       !P!T`
void test2(T)(T v) if (!P!T);
     ^
fail_compilation/constraints_func1.d(133): Error: template `test3` is not callable using argument types `!()(int)`
    test3(0);
         ^
fail_compilation/imports/constraints.d(11):        Candidate is: `test3(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
void test3(T)(T v) if (P!T && N!T);
     ^
fail_compilation/constraints_func1.d(134): Error: template `test4` is not callable using argument types `!()(int)`
    test4(0);
         ^
fail_compilation/imports/constraints.d(12):        Candidate is: `test4(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
void test4(T)(T v) if (P!T && N!T && P!T);
     ^
fail_compilation/constraints_func1.d(135): Error: template `test5` is not callable using argument types `!()(int)`
    test5(0);
         ^
fail_compilation/imports/constraints.d(13):        Candidate is: `test5(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
void test5(T)(T v) if (N!T || N!T);
     ^
fail_compilation/constraints_func1.d(136): Error: template `test6` is not callable using argument types `!()(int)`
    test6(0);
         ^
fail_compilation/imports/constraints.d(14):        Candidate is: `test6(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T
       !P!T`
void test6(T)(T v) if (N!T || N!T || !P!T);
     ^
fail_compilation/constraints_func1.d(137): Error: template `test7` is not callable using argument types `!()(int)`
    test7(0);
         ^
fail_compilation/imports/constraints.d(15):        Candidate is: `test7(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
void test7(T)(T v) if (N!T || P!T && N!T);
     ^
fail_compilation/constraints_func1.d(138): Error: template `test8` is not callable using argument types `!()(int)`
    test8(0);
         ^
fail_compilation/imports/constraints.d(16):        Candidate is: `test8(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
void test8(T)(T v) if ((N!T || P!T) && N!T);
     ^
fail_compilation/constraints_func1.d(139): Error: template `test9` is not callable using argument types `!()(int)`
    test9(0);
         ^
fail_compilation/imports/constraints.d(17):        Candidate is: `test9(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       !P!T`
void test9(T)(T v) if (!P!T && !N!T);
     ^
fail_compilation/constraints_func1.d(140): Error: template `test10` is not callable using argument types `!()(int)`
    test10(0);
          ^
fail_compilation/imports/constraints.d(18):        Candidate is: `test10(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       !P!T`
void test10(T)(T v) if (!N!T && !P!T);
     ^
fail_compilation/constraints_func1.d(141): Error: template `test11` is not callable using argument types `!()(int)`
    test11(0);
          ^
fail_compilation/imports/constraints.d(19):        Candidate is: `test11(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       !P!T`
void test11(T)(T v) if (!(!N!T && P!T));
     ^
fail_compilation/constraints_func1.d(142): Error: template `test12` is not callable using argument types `!()(int)`
    test12(0);
          ^
fail_compilation/imports/constraints.d(20):        Candidate is: `test12(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       !P!T`
void test12(T)(T v) if (!(N!T || P!T));
     ^
fail_compilation/constraints_func1.d(144): Error: template `test1` is not callable using argument types `!()(int, int)`
    test1(0, 0);
         ^
fail_compilation/imports/constraints.d(9):        Candidate is: `test1(T)(T v)`
void test1(T)(T v) if (N!T);
     ^
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
