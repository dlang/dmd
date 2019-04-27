/*
REQUIRED_ARGS:
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
