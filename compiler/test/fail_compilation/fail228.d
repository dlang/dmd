/*
TEST_OUTPUT:
---
fail_compilation/fail228.d(24): Error: undefined identifier `localVariable`
    auto x = ToTypeString!(typeof(localVariable))();
                                  ^
---
*/

//import core.stdc.stdio : printf;

int ToTypeString(T : int)()
{
    return 1;
}

int ToTypeString(T : string)()
{
    return 2;
}

void main()
{
    auto x = ToTypeString!(typeof(localVariable))();
}
