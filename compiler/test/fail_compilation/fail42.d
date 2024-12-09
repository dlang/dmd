/*
TEST_OUTPUT:
---
fail_compilation/fail42.d(24): Error: struct `fail42.Qwert` no size because of forward reference
    Qwert hjkl;
          ^
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
