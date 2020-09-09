/*
REQUIRED_ARGS:
EXTRA_FILES: imports/diag12598a.d
TEST_OUTPUT:
---
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
