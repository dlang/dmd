/*
TEST_OUTPUT:
---
fail_compilation/test21062.d(22): Error: no identifier for declarator `bool`
bool synchronized;
     ^
fail_compilation/test21062.d(22):        `synchronized` is a keyword, perhaps append `_` to make it an identifier
fail_compilation/test21062.d(23): Error: no identifier for declarator `ubyte*`
ubyte* out;
       ^
fail_compilation/test21062.d(23):        `out` is a keyword, perhaps append `_` to make it an identifier
fail_compilation/test21062.d(27): Error: no identifier for declarator `uint`
    foreach(uint in; [])
                 ^
fail_compilation/test21062.d(27):        `in` is a keyword, perhaps append `_` to make it an identifier
---
*/

// https://issues.dlang.org/show_bug.cgi?id=21062
// Confusing error when using a keyword as an identifier for a declaration

bool synchronized;
ubyte* out;

void main()
{
    foreach(uint in; [])
    {
    }
}
