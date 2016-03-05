/*
REQUIRED_ARGS: -de
*/
module test313;

import imports.a313;

void test1()
{
    import imports.b313;
    imports.b313.bug();
}

void test2()
{
    cstdio.printf("");
}

import imports.pkg313.c313;
void test3()
{
    imports.pkg313.c313.bug();
}
