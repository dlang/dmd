/*
TEST_OUTPUT:
---
fail_compilation/diag9357.d(26): Error: cannot implicitly convert expression `1.0` of type `double` to `int`
    { int x = 1.0; }
              ^
fail_compilation/diag9357.d(27): Error: cannot implicitly convert expression `10.0` of type `double` to `int`
    { int x = 10.0; }
              ^
fail_compilation/diag9357.d(28): Error: cannot implicitly convert expression `11.0` of type `double` to `int`
    { int x = 11.0; }
              ^
fail_compilation/diag9357.d(29): Error: cannot implicitly convert expression `99.0` of type `double` to `int`
    { int x = 99.0; }
              ^
fail_compilation/diag9357.d(30): Error: cannot implicitly convert expression `1.04858e+06L` of type `real` to `int`
    { int x = 1048575.0L; }
              ^
fail_compilation/diag9357.d(31): Error: cannot implicitly convert expression `1.04858e+06L` of type `real` to `int`
    { int x = 1048576.0L; }
              ^
---
*/
void main()
{
    { int x = 1.0; }
    { int x = 10.0; }
    { int x = 11.0; }
    { int x = 99.0; }
    { int x = 1048575.0L; }
    { int x = 1048576.0L; }
}
