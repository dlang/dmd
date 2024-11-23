/*
TEST_OUTPUT:
---
fail_compilation/fail14416.d(15): Error: template `S(T)` does not have property `sizeof`
enum n = S.sizeof;
          ^
---
*/

struct S(T)
{
    int x;
}

enum n = S.sizeof;
