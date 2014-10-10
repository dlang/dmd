// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/parse12931.d(29): Deprecation: prefix type qualifier on function is deprecated
fail_compilation/parse12931.d(30): Deprecation: prefix type qualifier on function is deprecated
fail_compilation/parse12931.d(31): Deprecation: prefix type qualifier on function is deprecated
fail_compilation/parse12931.d(32): Deprecation: prefix type qualifier on function is deprecated
fail_compilation/parse12931.d(33): Deprecation: prefix type qualifier on function is deprecated
fail_compilation/parse12931.d(34): Deprecation: prefix type qualifier on function is deprecated
fail_compilation/parse12931.d(37): Deprecation: prefix type qualifier on function is deprecated
---
*/

class C
{
    // OK
    const int x;

    // OK
    int post_c()  const        { return 1; }
    int post_w()  inout        { return 1; }
    int post_s()  shared       { return 1; }
    int post_sc() shared const { return 1; }
    int post_sw() shared inout { return 1; }
    int post_i()  immutable    { return 1; }

    // deprecated
    const        int pre_c()  { return 1; }
    inout        int pre_w()  { return 1; }
    shared       int pre_s()  { return 1; }
    shared const int pre_sc() { return 1; }
    shared inout int pre_sw() { return 1; }
    immutable    int pre_i()  { return 1; }

    // deprecated
    const T foo(T)() { return T.init; }
}

/*
TEST_OUTPUT:
---
fail_compilation/parse12931.d(47): Deprecation: prefix type qualifier on function type is deprecated
fail_compilation/parse12931.d(48): Deprecation: prefix type qualifier on function type is deprecated
---
*/
const alias int f2();
alias const int f1();
alias int f3() const;
