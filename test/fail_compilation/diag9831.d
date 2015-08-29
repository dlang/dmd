/*
TEST_OUTPUT:
---
fail_compilation/diag9831.d(12): Error: cannot match delegate literal to function pointer type 'int function(int x)'
---
*/

void main()
{
    immutable int c;
    int function(int x) func;
    func = x => c;
}
