/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/enum_function.d(19): Deprecation: function cannot have enum storage class
enum void f1() { return; }
               ^
fail_compilation/enum_function.d(20): Deprecation: function cannot have enum storage class
enum f2() { return 5; }
          ^
fail_compilation/enum_function.d(21): Deprecation: function cannot have enum storage class
enum f3() => 5;
          ^
fail_compilation/enum_function.d(22): Deprecation: function cannot have enum storage class
enum int f4()() => 5;
                ^
---
*/
enum void f1() { return; }
enum f2() { return 5; }
enum f3() => 5;
enum int f4()() => 5;
