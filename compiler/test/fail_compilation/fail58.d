/*
TEST_OUTPUT:
----
fail_compilation/fail58.d(36): Error: function `SomeFunc` is not callable using argument types `(string, int)`
    SomeFunc("123", sp);
            ^
fail_compilation/fail58.d(36):        cannot pass argument `"123"` of type `string` to parameter `dchar[] pText`
fail_compilation/fail58.d(22):        `fail58.SomeFunc(dchar[] pText, out int pStopPosn)` declared here
dchar[] SomeFunc( dchar[] pText, out int pStopPosn)
        ^
fail_compilation/fail58.d(40): Error: function `SomeFunc` is not callable using argument types `(string, int)`
    SomeFunc("", sp);
            ^
fail_compilation/fail58.d(40):        cannot pass argument `""` of type `string` to parameter `dchar[] pText`
fail_compilation/fail58.d(22):        `fail58.SomeFunc(dchar[] pText, out int pStopPosn)` declared here
dchar[] SomeFunc( dchar[] pText, out int pStopPosn)
        ^
----
*/
debug import std.stdio;
const int anything = -1000; // Line #2
dchar[] SomeFunc( dchar[] pText, out int pStopPosn)
{
    if (pText.length == 0)
        pStopPosn = 0;
    else
        pStopPosn = -1;
    debug writefln("DEBUG: using '%s' we get %d", pText, pStopPosn);
    return pText.dup;
}

int main(char[][] pArgs)
{
    int sp;

    SomeFunc("123", sp);
    debug writefln("DEBUG: got %d", sp);
    assert(sp == -1);

    SomeFunc("", sp);
//    if (sp != 0){} // Line #22
    debug writefln("DEBUG: got %d", sp);
    assert(sp == -1);
    return 0;
}
