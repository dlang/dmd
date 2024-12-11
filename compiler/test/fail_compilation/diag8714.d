/*
TEST_OUTPUT:
---
fail_compilation/diag8714.d(13): Error: function `diag8714.foo` circular dependency. Functions cannot be interpreted while being compiled
string foo(string f)
       ^
fail_compilation/diag8714.d(19):        called from here: `foo("somestring")`
    return bar!(foo("somestring"));
                   ^
---
*/

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
