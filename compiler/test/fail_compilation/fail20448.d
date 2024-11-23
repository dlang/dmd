/*
TEST_OUTPUT:
---
fail_compilation/fail20448.d(20): Error: returning `p.x` escapes a reference to parameter `p`
    return p.x;
           ^
fail_compilation/fail20448.d(26): Error: template instance `fail20448.member!"x"` error instantiating
    p.member!"x" = 2;
     ^
---
*/

struct S
{
    int x, y;
}

ref int member(string mem)(S p)
{
    return p.x;
}

void main()
{
    S p;
    p.member!"x" = 2;
}
