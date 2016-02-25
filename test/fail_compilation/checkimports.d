/*
REQUIRED_ARGS: -transition=checkimports
TEST_OUTPUT:
---
fail_compilation/checkimports.d(15): Deprecation: local import search method found struct imports.diag12598a.lines instead of variable checkimports.C.lines
fail_compilation/checkimports.d(15): Error: struct 'lines' is a type, not an lvalue
---
*/

class C
{
    void f()
    {
        import imports.diag12598a;
        lines ~= "";
    }

    string[] lines;
}

void main()
{
}
