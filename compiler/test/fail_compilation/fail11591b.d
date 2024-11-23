/*
TEST_OUTPUT:
---
fail_compilation/fail11591b.d(24): Error: AA key type `S11591` does not have `bool opEquals(ref const S11591) const`
    int[S11591] aa;
                ^
fail_compilation/fail11591b.d(31): Error: AA key type `S12307a` does not have `bool opEquals(ref const S12307a) const`
    int[S12307a] aa1;    // a
                 ^
fail_compilation/fail11591b.d(32): Error: AA key type `S12307b` does not have `bool opEquals(ref const S12307b) const`
    int[S12307b] aa2;    // b
                 ^
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

struct S12307a { bool opEquals(T : typeof(this))(T) { return false; } }

void test12307()
{
    int[S12307a] aa1;    // a
    int[S12307b] aa2;    // b
}

struct S12307b { bool opEquals(T : typeof(this))(T) { return false; } }
