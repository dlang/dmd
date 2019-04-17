// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
---
*/


// new lookup + information
class C
{
    void f()
    {
        import imports.diag12598a;
        lines ~= "";
    }

    string[] lines;
}
