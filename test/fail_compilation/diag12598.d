/*
REQUIRED_ARGS: -revert=import
TEST_OUTPUT:
---
fail_compilation/diag12598.d(14): Error: `lines` is a `struct` definition and cannot be modified
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
