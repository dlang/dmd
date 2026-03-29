/*
TEST_OUTPUT:
---
fail_compilation/fail42.d(24): Error: struct `fail42.Qwert` no size because of forward reference
fail_compilation/fail42.d(24):        while resolving `fail42.Qwert`
fail_compilation/fail42.d(22):        while resolving `fail42.Yuiop`
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
