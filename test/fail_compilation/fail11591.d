/*
TEST_OUTPUT:
---
fail_compilation/fail11591.d(13): Error: associative array key type T does not have 'const int opCmp(ref const T)' member function
---
*/

struct T {
    bool opCmp(int i) { return false; }
}

void main() {
    int[T] aa;
}
