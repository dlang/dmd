// https://github.com/dlang/dmd/issues/24020

/*
TEST_OUTPUT:
---
fail_compilation/test24020.d(18): Error: cannot append invalid UTF character `\U00110000` to `string`
fail_compilation/test24020.d(38):        called from here: `f()`
fail_compilation/test24020.d(25): Error: cannot append invalid UTF character `\U0000d800` to `string`
fail_compilation/test24020.d(39):        called from here: `g()`
fail_compilation/test24020.d(33): Error: cannot encode invalid UTF character `\U00110000` as `char`
fail_compilation/test24020.d(40):        called from here: `h()`
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

// https://github.com/dlang/dmd/issues/24153
string h()
{
    string r;
    foreach (char c; [cast(dchar) 0x110000])
        r ~= c;
    return r;
}

enum x = f();
enum y = g();
enum z = h();
