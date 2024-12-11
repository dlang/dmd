/*
EXTRA_FILES: imports/constraints.d
TEST_OUTPUT:
---
fail_compilation/constraints_func2.d(150): Error: template `test13` is not callable using argument types `!()(int)`
    test13(0);
          ^
fail_compilation/imports/constraints.d(23):        Candidate is: `test13(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       !P!T`
void test13(T)(T v) if (P!T ? N!T : P!T);    // P!T && N!T || !P!T && P!T
     ^
fail_compilation/constraints_func2.d(151): Error: template `test14` is not callable using argument types `!()(int)`
    test14(0);
          ^
fail_compilation/imports/constraints.d(24):        Candidate is: `test14(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       !P!T
       N!T`
void test14(T)(T v) if (!P!T ? P!T : N!T);
     ^
fail_compilation/constraints_func2.d(152): Error: template `test15` is not callable using argument types `!()(int)`
    test15(0);
          ^
fail_compilation/imports/constraints.d(25):        Candidate is: `test15(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       !P!T
       !P!T`
void test15(T)(T v) if (!(P!T ? P!T : N!T)); // (!P!T || !P!T) && (P!T || !N!T)
     ^
fail_compilation/constraints_func2.d(153): Error: template `test16` is not callable using argument types `!()(int)`
    test16(0);
          ^
fail_compilation/imports/constraints.d(26):        Candidate is: `test16(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
void test16(T)(T v) if (N!T && P!T || N!T);
     ^
fail_compilation/constraints_func2.d(154): Error: template `test17` is not callable using argument types `!()(int)`
    test17(0);
          ^
fail_compilation/imports/constraints.d(27):        Candidate is: `test17(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
void test17(T)(T v) if (N!T && P!T && (P!T || P!T));
     ^
fail_compilation/constraints_func2.d(155): Error: template `test18` is not callable using argument types `!()(int)`
    test18(0);
          ^
fail_compilation/imports/constraints.d(28):        Candidate is: `test18(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
void test18(T)(T v) if ((N!T || P!T && N!T) && P!T);
     ^
fail_compilation/constraints_func2.d(156): Error: template `test19` is not callable using argument types `!()(int)`
    test19(0);
          ^
fail_compilation/imports/constraints.d(29):        Candidate is: `test19(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       !P!T
       N!T`
void test19(T)(T v) if ((N!T ? P!T : !P!T) ? P!T : N!T); // (N!T && P!T || !N!T && !P!T) && P!T || (!N!T || !P!T) && (N!T || P!T) && N!T
     ^
fail_compilation/constraints_func2.d(157): Error: template `test20` is not callable using argument types `!()(int)`
    test20(0);
          ^
fail_compilation/imports/constraints.d(30):        Candidate is: `test20(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
void test20(T)(T v) if (N!T && (P!T && N!T || N!T));
     ^
fail_compilation/constraints_func2.d(158): Error: template `test21` is not callable using argument types `!()(int)`
    test21(0);
          ^
fail_compilation/imports/constraints.d(31):        Candidate is: `test21(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       N!T
       N!T`
void test21(T)(T v) if (P!T && (N!T && P!T || N!T));
     ^
fail_compilation/constraints_func2.d(159): Error: template `test22` is not callable using argument types `!()(int)`
    test22(0);
          ^
fail_compilation/imports/constraints.d(32):        Candidate is: `test22(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       !P!T
       !P!T`
void test22(T)(T v) if ((!P!T || !P!T && P!T) && (N!T || !P!T));
     ^
fail_compilation/constraints_func2.d(160): Error: template `test23` is not callable using argument types `!()(int)`
    test23(0);
          ^
fail_compilation/imports/constraints.d(33):        Candidate is: `test23(T)(T v)`
  with `T = int`
  must satisfy one of the following constraints:
`       !P!T
       N!T
       !P!T`
void test23(T)(T v) if (!P!T || P!T && N!T || !P!T);
     ^
fail_compilation/constraints_func2.d(161): Error: template `test24` is not callable using argument types `!()(int)`
    test24(0);
          ^
fail_compilation/imports/constraints.d(34):        Candidate is: `test24(R)(R r)`
  with `R = int`
  must satisfy the following constraint:
`       __traits(hasMember, R, "stuff")`
void test24(R)(R r) if (__traits(hasMember, R, "stuff"));
     ^
fail_compilation/constraints_func2.d(162): Error: template `test25` is not callable using argument types `!()(int)`
    test25(0);
          ^
fail_compilation/imports/constraints.d(35):        Candidate is: `test25(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
int test25(T)(T v) if (N!T);
    ^
fail_compilation/constraints_func2.d(163): Error: template `test26` is not callable using argument types `!(float)(int)`
    test26!float(5);
                ^
fail_compilation/imports/constraints.d(36):        Candidate is: `test26(T, U)(U u)`
  with `T = float,
       U = int`
  must satisfy the following constraint:
`       N!U`
float test26(T, U)(U u) if (N!U);
      ^
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
