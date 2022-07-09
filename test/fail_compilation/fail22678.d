// https://issues.dlang.org/show_bug.cgi?id=22678
// REQUIRED_ARGS: -verrors=context -vcolumns
/* TEST_OUTPUT:
---
fail_compilation/fail22678.d(24,13): Error: cannot implicitly convert expression `1` of type `int` to `string`
    string a = 1;
               ^
fail_compilation/fail22678.d(28,14): Error: cannot implicitly convert expression `1` of type `int` to `string`
    string a = 1;
               ^
fail_compilation/fail22678.d(32,21): Error: cannot implicitly convert expression `1` of type `int` to `string`
    string straße = 1;
                    ^
fail_compilation/fail22678.d(36,22): Error: cannot implicitly convert expression `1` of type `int` to `string`
    string straße = 1;
                    ^
fail_compilation/fail22678.d(40,23): Error: cannot implicitly convert expression `1` of type `int` to `string`
        string straße = 1;
                        ^
---
*/
void fail22678_1()
{
	string a = 1;
}
void fail22678_2()
{
 	string a = 1;
}
void fail22678_3()
{
  	string straße = 1;
}
void fail22678_4()
{
   	string straße = 1;
}
void fail22678_5()
{
    	string straße = 1;
}
