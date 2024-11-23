/*
TEST_OUTPUT:
---
fail_compilation/fail19917.d(28): Error: overlapping default initialization for field `c` and `a`
struct X
^
fail_compilation/fail19917.d(28): Error: overlapping default initialization for field `d` and `b`
struct X
^
fail_compilation/fail19917.d(45): Error: overlapping default initialization for field `b` and `a`
struct Y
^
---
*/

struct S
{
    union
    {
        struct
        {
            int a = 3;
            int b = 4;
        }
   }
}

struct X
{
    union
    {
        struct
        {
            int a = 3;
            int b = 4;
        }
        struct
        {
            int c = 3;
            int d = 4;
        }
    }
}

struct Y
{
    union
    {
        struct
        {
            union { int a = 3; }
        }
        int b = 4;
    }
}
