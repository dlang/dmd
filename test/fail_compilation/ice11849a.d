/*
TEST_OUTPUT:
---
fail_compilation/ice11849a.d(20): Error: enum ice11849a.RegValueType1a recursive definition of .max property
fail_compilation/ice11849a.d(27): Error: enum ice11849a.RegValueType1b recursive definition of .max property
fail_compilation/ice11849a.d(32): Error: enum ice11849a.RegValueType2a recursive definition of .min property
fail_compilation/ice11849a.d(39): Error: enum ice11849a.RegValueType2b recursive definition of .min property
---
*/

alias DWORD = uint;

enum : DWORD
{
    REG_DWORD = 4
}

enum RegValueType1a : DWORD
{
    Unknown = DWORD.max,
    DWORD = REG_DWORD,
}

enum RegValueType1b : DWORD
{
    DWORD = REG_DWORD,
    Unknown = DWORD.max,
}

enum RegValueType2a : DWORD
{
    Unknown = DWORD.min,
    DWORD = REG_DWORD,
}

enum RegValueType2b : DWORD
{
    DWORD = REG_DWORD,
    Unknown = DWORD.min,
}
