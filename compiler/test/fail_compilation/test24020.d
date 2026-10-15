// https://github.com/dlang/dmd/issues/24020

/*
TEST_OUTPUT:
---
fail_compilation/test24020.d(16): Error: cannot append invalid UTF character `\U00110000` to `string`
fail_compilation/test24020.d(27):        called from here: `f()`
fail_compilation/test24020.d(23): Error: cannot append invalid UTF character `\U0000d800` to `string`
fail_compilation/test24020.d(28):        called from here: `g()`
---
*/

string f()
{
    string s;
    s ~= cast(dchar) 0x110000;
    return s;
}

string g()
{
    string s;
    s ~= cast(dchar) 0xD800;
    return s;
}

enum x = f();
enum y = g();
