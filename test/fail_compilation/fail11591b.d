/*
TEST_OUTPUT:
---
fail_compilation/fail11591b.d(16): Error: associative array key type S11591 does not have 'const bool opEquals(ref const S11591)' member function
---
*/

struct S11591
{
    bool opEquals(int i) { return false; }
    Object o; // needed to suppress compiler generated opEquals
}

void test11591()
{
    int[S11591] aa;
}

/*
TEST_OUTPUT:
---
fail_compilation/fail11591b.d(30): Error: associative array key type S12307a does not have 'const bool opEquals(ref const S12307a)' member function
fail_compilation/fail11591b.d(31): Error: associative array key type S12307b does not have 'const bool opEquals(ref const S12307b)' member function
---
*/
struct S12307a { bool opEquals(T : typeof(this))(T) { return false; } }

void test12307()
{
    int[S12307a] aa1;    // a
    int[S12307b] aa2;    // b
}

struct S12307b { bool opEquals(T : typeof(this))(T) { return false; } }
