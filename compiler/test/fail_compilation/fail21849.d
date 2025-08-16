// https://issues.dlang.org/show_bug.cgi?id=21849
// REQUIRED_ARGS: -verrors=context -vcolumns
/* TEST_OUTPUT:
---
fail_compilation/fail21849.d(22): Error: cannot implicitly convert expression `1` of type `int` to `string`
    string ß = 1;
               ^
fail_compilation/fail21849.d(26): Error: implicit conversion from `ushort` (16 bytes) to `byte` (8 bytes) may truncate value
    string s = "ß☺-oneline"; byte S = ushort.max;
                                      ^
fail_compilation/fail21849.d(26):        Use an explicit cast (e.g., `cast(byte)expr`) to silence this.
fail_compilation/fail21849.d(31): Error: undefined identifier `undefined_identifier`
ß-utf"; undefined_identifier;
        ^
fail_compilation/fail21849.d(35): Error: `s[0..9]` has no effect
☺-smiley"; s[0 .. 9];
            ^
---
*/
void fail21849a()
{
    string ß = 1;
}
void fail21849b()
{
    string s = "ß☺-oneline"; byte S = ushort.max;
}
void fail21849c()
{
    string s = "
ß-utf"; undefined_identifier;
}

// Test correct context with line directive present
// https://github.com/dlang/dmd/issues/20929
#line 32
void fail21849d()
{
    string s = "
☺-smiley"; s[0 .. 9];
}
