/*
TEST_OUTPUT:
---
fail_compilation/fail13537.d(16): Error: field u.y cannot be modified in @safe code because it overlaps mutable and immutable
fail_compilation/fail13537.d(18): Error: field u.y cannot be modified in @safe code because it overlaps mutable and immutable
---
*/
union U
{
    immutable int x;
    int y;
} 
void fun() @safe
{
    U u;
    u.y = 1;
    assert(u.x == 1);
    u.y = 2;
    assert(u.x == 2); // look ma! I broke immutability!

    // read-only access should be allowed
    int a = u.x;
}
void gun() @system
{
    U u;
    u.y = 1; // should be allowed in @system code
    int a = u.x;
}
