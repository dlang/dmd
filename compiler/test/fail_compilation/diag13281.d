/*
TEST_OUTPUT:
---
fail_compilation/diag13281.d(46): Error: cannot implicitly convert expression `123` of type `int` to `string`
string x1 = 123;
            ^
fail_compilation/diag13281.d(47): Error: cannot implicitly convert expression `123u` of type `uint` to `string`
string x2 = 123u;
            ^
fail_compilation/diag13281.d(48): Error: cannot implicitly convert expression `123L` of type `long` to `string`
string x3 = 123L;
            ^
fail_compilation/diag13281.d(49): Error: cannot implicitly convert expression `123LU` of type `ulong` to `string`
string x4 = 123uL;
            ^
fail_compilation/diag13281.d(50): Error: cannot implicitly convert expression `123.4` of type `double` to `int`
int y1 = 123.4;
         ^
fail_compilation/diag13281.d(51): Error: cannot implicitly convert expression `123.4F` of type `float` to `int`
int y2 = 123.4f;
         ^
fail_compilation/diag13281.d(52): Error: cannot implicitly convert expression `123.4L` of type `real` to `int`
int y3 = 123.4L;
         ^
fail_compilation/diag13281.d(53): Error: cannot implicitly convert expression `123.4i` of type `idouble` to `int`
int y4 = 123.4i;
         ^
fail_compilation/diag13281.d(54): Error: cannot implicitly convert expression `123.4Fi` of type `ifloat` to `int`
int y5 = 123.4fi;
         ^
fail_compilation/diag13281.d(55): Error: cannot implicitly convert expression `123.4Li` of type `ireal` to `int`
int y6 = 123.4Li;
         ^
fail_compilation/diag13281.d(56): Error: cannot implicitly convert expression `123.4 + 5.6i` of type `cdouble` to `int`
int y7 = 123.4 +5.6i;
         ^
fail_compilation/diag13281.d(57): Error: cannot implicitly convert expression `123.4F + 5.6Fi` of type `cfloat` to `int`
int y8 = 123.4f+5.6fi;
         ^
fail_compilation/diag13281.d(58): Error: cannot implicitly convert expression `123.4L + 5.6Li` of type `creal` to `int`
int y9 = 123.4L+5.6Li;
         ^
---
*/

string x1 = 123;
string x2 = 123u;
string x3 = 123L;
string x4 = 123uL;
int y1 = 123.4;
int y2 = 123.4f;
int y3 = 123.4L;
int y4 = 123.4i;
int y5 = 123.4fi;
int y6 = 123.4Li;
int y7 = 123.4 +5.6i;
int y8 = 123.4f+5.6fi;
int y9 = 123.4L+5.6Li;
