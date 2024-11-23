/*
TEST_OUTPUT:
---
fail_compilation/newaa.d(21): Error: cannot implicitly convert expression `new string[string]` of type `string[string]` to `int[string]`
    int[string] c = new typeof(crash);
                    ^
fail_compilation/newaa.d(22): Error: function expected before `()`, not `new int[int]` of type `int[int]`
    auto d = new int[int](5);
                         ^
fail_compilation/newaa.d(24): Error: `new` cannot take arguments for an associative array
    auto e = new AA(5);
             ^
---
*/
// Line 9 starts here
void main()
{
    //https://issues.dlang.org/show_bug.cgi?id=11790
    string[string] crash = new string[string];
    //https://issues.dlang.org/show_bug.cgi?id=20547
    int[string] c = new typeof(crash);
    auto d = new int[int](5);
    alias AA = char[string];
    auto e = new AA(5);
}
