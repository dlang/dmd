/*
TEST_OUTPUT:
---
fail_compilation/fail27.d(20): Error: implicit conversion from `int` (32 bytes) to `short` (16 bytes) may truncate value
fail_compilation/fail27.d(20):        Use an explicit cast (e.g., `cast(short)expr`) to silence this.
fail_compilation/fail27.d(21): Error: implicit conversion from `int` (32 bytes) to `byte` (8 bytes) may truncate value
fail_compilation/fail27.d(21):        Use an explicit cast (e.g., `cast(byte)expr`) to silence this.
fail_compilation/fail27.d(22): Error: implicit conversion from `int` (32 bytes) to `char` (8 bytes) may truncate value
fail_compilation/fail27.d(22):        Use an explicit cast (e.g., `cast(char)expr`) to silence this.
fail_compilation/fail27.d(23): Error: implicit conversion from `int` (32 bytes) to `wchar` (16 bytes) may truncate value
fail_compilation/fail27.d(23):        Use an explicit cast (e.g., `cast(wchar)expr`) to silence this.
fail_compilation/fail27.d(24): Error: implicit conversion from `int` (32 bytes) to `wchar` (16 bytes) may truncate value
fail_compilation/fail27.d(24):        Use an explicit cast (e.g., `cast(wchar)expr`) to silence this.
fail_compilation/fail27.d(26): Error: cannot implicitly convert expression `-1` of type `int` to `dchar`
---
*/

void main()
{
    short a = -32769; // short.min-1
    byte  b = -129; // byte.min-1
    char  c = -1; // char.min-1
    wchar D = 65536; // wchar.max+1
    wchar d = -1; // wchar.min-1
    dchar E = 1114111; // dchar.max+1
    dchar e = -1; // dchar.min-1
}
