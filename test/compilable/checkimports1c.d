// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
---
*/

// old lookup + information (the order of switches is reverse)
class C
{
    void f()
    {
        import imports.diag12598a;
        lines ~= "";
    }

    string[] lines;
}
