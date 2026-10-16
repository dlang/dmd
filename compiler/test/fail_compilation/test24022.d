// https://github.com/dlang/dmd/issues/24022

/*
TEST_OUTPUT:
---
fail_compilation/test24022.d(16): Error: cannot decode UTF-8 sequence starting with `\x80` (Outside Unicode code space)
fail_compilation/test24022.d(30):        called from here: `f()`
fail_compilation/test24022.d(25): Error: cannot decode UTF-16 sequence starting with `\udc00` (Unpaired surrogate)
fail_compilation/test24022.d(31):        called from here: `g()`
---
*/

dchar[] f()
{
    dchar[] r;
    foreach_reverse (dchar c; "a\x80")
        r ~= c;
    return r;
}

dchar[] g()
{
    dchar[] r;
    wchar[] s = ['a', 0xDC00];
    foreach_reverse (dchar c; s)
        r ~= c;
    return r;
}

enum x = f();
enum y = g();
