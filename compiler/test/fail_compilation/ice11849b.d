/*
TEST_OUTPUT:
---
fail_compilation/ice11849b.d(17): Error: circular reference to enum base type `DWORD1`
enum : DWORD1
^
fail_compilation/ice11849b.d(17): Error: `DWORD1` is used as a type
enum : DWORD1
^
fail_compilation/ice11849b.d(22): Error: circular reference to enum base type `typeof(DWORD2)`
enum : typeof(DWORD2)
^
---
*/
enum REG_DWORD = 1;

enum : DWORD1
{
    DWORD1 = REG_DWORD
}

enum : typeof(DWORD2)
{
    DWORD2 = REG_DWORD
}
