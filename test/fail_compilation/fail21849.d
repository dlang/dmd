// https://issues.dlang.org/show_bug.cgi?id=21849
// REQUIRED_ARGS: -verrors=context -vcolumns
/* TEST_OUTPUT:
---
Deprecation: -verrors=context is redundant, and will be removed in future DMD versions.
fail_compilation/fail21849.d(14,17): Error: cannot implicitly convert expression `1` of type `int` to `string`
fail_compilation/fail21849.d(18,42): Error: cannot implicitly convert expression `cast(ushort)65535u` of type `ushort` to `byte`
fail_compilation/fail21849.d(23,10): Error: undefined identifier `undefined_identifier`
fail_compilation/fail21849.d(28,15): Error: `s[0..9]` has no effect
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
void fail21849d()
{
    string s = "
☺-smiley"; s[0 .. 9];
}
