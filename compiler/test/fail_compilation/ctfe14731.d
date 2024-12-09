/*
TEST_OUTPUT:
---
fail_compilation/ctfe14731.d(20): Error: cannot implicitly convert expression `split("a b")` of type `string[]` to `string`
    enum string list1 = "a b".split();
                                   ^
fail_compilation/ctfe14731.d(21): Error: cannot implicitly convert expression `split("a b")` of type `string[]` to `string`
         string list2 = "a b".split();
                                   ^
---
*/

string[] split(string a)
{
    return [a];
}

void main()
{
    enum string list1 = "a b".split();
         string list2 = "a b".split();
}
