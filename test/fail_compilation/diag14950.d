/*
TEST_OUTPUT:
---
fail_compilation/diag14950.d(17): Error: enum member diag14950.B.end initialization with (B.start + 1) causes overflow for type 'A'
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
