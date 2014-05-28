/*
TEST_OUTPUT:
---
fail_compilation/fail11591.d(15): Error: associative array key type S11591 does not have 'const int opCmp(ref const S11591)' member function
---
*/

struct S11591
{
    bool opCmp(int i) { return false; }
}

void test11591()
{
    int[S11591] aa;
}

/*
TEST_OUTPUT:
---
fail_compilation/fail11591.d(29): Error: associative array key type S12307a does not have 'const int opCmp(ref const S12307a)' member function
fail_compilation/fail11591.d(30): Error: associative array key type S12307b does not have 'const int opCmp(ref const S12307b)' member function
---
*/
struct S12307a { int opCmp(T : typeof(this))(T) { return 0; } }

void test12307()
{
    int[S12307a] aa1;    // a
    int[S12307b] aa2;    // b
}

struct S12307b { int opCmp(T : typeof(this))(T) { return 0; } }
