/*
TEST_OUTPUT:
---
fail_compilation/fail42.d(17): Error: variable fail42.Qwert.asdfg cannot be further field because it will change the determined Qwert size
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
