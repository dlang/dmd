/*
TEST_OUTPUT:
---
fail_compilation/diag12598.d(13): Error: struct 'lines' is a type, not an lvalue
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
