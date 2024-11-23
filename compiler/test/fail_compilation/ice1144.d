/*
TEST_OUTPUT:
---
fail_compilation/ice1144.d(18): Error: undefined identifier `a`
    foreach (t; a)
                ^
fail_compilation/ice1144.d(27): Error: template instance `ice1144.testHelper!("hello", "world")` error instantiating
    mixin(testHelper!("hello", "world")());
          ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=1144
// ICE(template.c) template mixin causes DMD crash
char[] testHelper(A ...)()
{
    char[] result;
    foreach (t; a)
    {
        result ~= "int " ~ t ~ ";\n";
    }
    return result;
}

void main()
{
    mixin(testHelper!("hello", "world")());
}
