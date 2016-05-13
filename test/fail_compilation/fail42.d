/*
TEST_OUTPUT:
---
fail_compilation/fail42.d(17): Error: struct fail42.Yuiop no size because of forward reference
---
*/

/+
struct Qwert
{
    Qwert asdfg;
}
+/

struct Qwert
{
    Yuiop asdfg;
}

struct Yuiop
{
    Qwert hjkl;
}
