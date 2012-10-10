/*
TEST_OUTPUT:
---
fail_compilation/diag8714.d(1): Error: function diag8714.foo circular dependency. Functions cannot be interpreted while being compiled
fail_compilation/diag8714.d(7):        called from here: foo("somestring")
---
*/

#line 1
string foo(string f)
{
    if (f == "somestring")
    {
        return "got somestring";
    }
    return bar!(foo("somestring"));
}

template bar(string s)
{
    enum bar = s;
}
