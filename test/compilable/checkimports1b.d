// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
---
*/

// old lookup + information
class C
{
    void f()
    {
        import imports.diag12598a;
        lines ~= "";
    }

    string[] lines;
}
