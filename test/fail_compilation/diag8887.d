// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/diag8887.d(1): Error: param 'x' of type (int[4u]) cannot be passed by value in extern(C) function
fail_compilation/diag8887.d(2): Error: Return type (int[4u]) cannot be returned by value in extern(C) function
fail_compilation/diag8887.d(3): Error: param 'x' of type (int[4u]) cannot be passed by value in extern(C++) function
fail_compilation/diag8887.d(4): Error: Return type (int[4u]) cannot be returned by value in extern(C++) function
---
*/
module diag8887;

#line 1
extern(C) void fail(int[4] x);
extern(C) int[4] fail2();
extern(C++) void fail3(int[4] x);
extern(C++) int[4] fail4();

void main() { }
