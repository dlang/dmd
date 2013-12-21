/*
TEST_OUTPUT:
---
fail_compilation/fail112.d(11): Error: functions cannot return a function
---
*/

void func(int a) { }
//typedef int ft(int);

typeof(func) test()
{
}
