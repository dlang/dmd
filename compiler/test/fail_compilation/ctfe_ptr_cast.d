/*
TEST_OUTPUT:
---
fail_compilation/ctfe_ptr_cast.d(9): Error: reinterpreting cast from `int()*` to `int(int)*` is not supported in CTFE
---
*/

int f1() { return 0; }
auto fp = cast(int function(int)) &f1;

// https://github.com/dlang/dmd/issues/23947
//int i = (cast(int function(int)) &f1)(1); // ICE
