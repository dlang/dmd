/*
TEST_OUTPUT:
---
fail_compilation/diag14950.d(18): Deprecation: Comparison between different enumeration types `B` and `A`; If this behavior is intended consider using `std.conv.asOriginalType`
fail_compilation/diag14950.d(18): Error: enum member diag14950.B.end initialization with (B.start + 1) causes overflow for type 'A'
---
*/

enum A
{
    start,
    end
}

enum B
{
    start = A.end,
    end
}
