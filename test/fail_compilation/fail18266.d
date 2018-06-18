/*
TEST_OUTPUT:
---
fail_compilation/fail18266.d(22): Error: declaration `fail18266.main.S` is already defined in another scope in `main` at line `14`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=18266

void main()
{
    foreach (i; 0 .. 10)
    {
        struct S
        {
            int x;
        }
        auto s = S(i);
    }
    foreach (i; 11 .. 20)
    {
        struct S
        {
            int y;
        }
        auto s = S(i);
    }
}
