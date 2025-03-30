/*
TEST_OUTPUT:
---
fail_compilation/diag14102.d(14): Error: cannot modify expression `-x` because it is not an lvalue
fail_compilation/diag14102.d(15): Error: cannot modify expression `-(x -= 1)` because it is not an lvalue
fail_compilation/diag14102.d(16): Error: cannot modify expression `-(x -= 1 -= 1)` because it is not an lvalue
fail_compilation/diag14102.d(17): Error: cannot modify expression `-(x -= 1 -= 1 -= 1)` because it is not an lvalue
---
*/

int main()
{
    int x;
    return -- -x;           // error: -x is not an lvalue
    return -- - --x;        // error: -(x -= 1) is not an lvalue
    return -- - -- --x;     // error: -((x -= 1 , x) -= 1) is not an lvalue
    return -- - -- -- --x;  // error: -((ref int __assignop1 = x -= 1 , __assignop1 = x; , __assignop1 -= 1 , __assignop1) -= 1) is not an lvalue
}
