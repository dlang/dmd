/*
TEST_OUTPUT:
---
fail_compilation/diag8787.d(12): Error: function `diag8787.I.f` function body only allowed in `final` functions in interface `I`
    void f() { }
         ^
---
*/

interface I
{
    void f() { }
}

void main() {}
