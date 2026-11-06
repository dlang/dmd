// https://github.com/dlang/dmd/issues/24022

/*
TEST_OUTPUT:
---
fail_compilation/test24022.d(20): Error: cannot decode UTF-8 sequence starting with `\x80` (Outside Unicode code space)
fail_compilation/test24022.d(54):        called from here: `f()`
fail_compilation/test24022.d(29): Error: cannot decode UTF-16 sequence starting with `\udc00` (Unpaired surrogate)
fail_compilation/test24022.d(55):        called from here: `g()`
fail_compilation/test24022.d(39): Error: cannot decode UTF-16 sequence starting with `\ud800` (Invalid low surrogate)
fail_compilation/test24022.d(56):        called from here: `h()`
fail_compilation/test24022.d(49): Error: cannot decode UTF-16 sequence starting with `\udc00` (Unpaired surrogate)
fail_compilation/test24022.d(57):        called from here: `i()`
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

// https://github.com/dlang/dmd/issues/24151
dchar[] h()
{
    dchar[] r;
    wchar[] s = [0xD800, 0xE000];
    foreach (dchar c; s)
        r ~= c;
    return r;
}

// https://github.com/dlang/dmd/issues/24152
dchar[] i()
{
    dchar[] r;
    wchar[] s = [0xDC00, 'a'];
    foreach_reverse (dchar c; s)
        r ~= c;
    return r;
}

enum x = f();
enum y = g();
enum z = h();
enum w = i();
