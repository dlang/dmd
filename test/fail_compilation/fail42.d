/*
TEST_OUTPUT:
---
fail_compilation/fail42.d(20): Error: struct fail42.Yuiop no size yet for forward reference
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
