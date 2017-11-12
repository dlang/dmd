/*
REQUIRED_ARGS: -de

TEST_OUTPUT:
---
fail_compilation/test9999.d(27): Deprecation: cannot implicitly convert expression `'\x00'` of type `char` to `bool`
fail_compilation/test9999.d(28): Deprecation: cannot implicitly convert expression `'\x01'` of type `char` to `bool`
fail_compilation/test9999.d(30): Deprecation: cannot implicitly convert expression `'\x00'` of type `wchar` to `bool`
fail_compilation/test9999.d(31): Deprecation: cannot implicitly convert expression `'\x01'` of type `wchar` to `bool`
fail_compilation/test9999.d(33): Deprecation: cannot implicitly convert expression `0` of type `int` to `bool`
fail_compilation/test9999.d(34): Deprecation: cannot implicitly convert expression `1` of type `int` to `bool`
fail_compilation/test9999.d(36): Deprecation: cannot implicitly convert expression `0u` of type `uint` to `bool`
fail_compilation/test9999.d(37): Deprecation: cannot implicitly convert expression `1u` of type `uint` to `bool`
fail_compilation/test9999.d(39): Deprecation: cannot implicitly convert expression `0L` of type `long` to `bool`
fail_compilation/test9999.d(40): Deprecation: cannot implicitly convert expression `1L` of type `long` to `bool`
fail_compilation/test9999.d(42): Deprecation: cannot implicitly convert expression `0LU` of type `ulong` to `bool`
fail_compilation/test9999.d(43): Deprecation: cannot implicitly convert expression `1LU` of type `ulong` to `bool`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=9999

void main()
{
    bool boolValue;

    boolValue = '\0';
    boolValue = '\1';

    boolValue = '\u0000';
    boolValue = '\u0001';

    boolValue = 0;
    boolValue = 1;

    boolValue = 0u;
    boolValue = 1u;

    boolValue = 0L;
    boolValue = 1L;

    boolValue = 0UL;
    boolValue = 1UL;
}
