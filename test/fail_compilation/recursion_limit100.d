// REQUIRED_ARGS: -recursion-limit=100

enum NUMBER_OF_STRUCTS=800;

struct Struct(uint N) {
    enum value = Struct!(N-1).value;
}

struct Struct(uint N: 0) {
    enum value = 42;
}

void main() {
    pragma(msg, Struct!NUMBER_OF_STRUCTS.value);
}

/*
TEST_OUTPUT:
---
fail_compilation/recursion_limit100.d(6): Error: template instance `recursion_limit100.Struct!700u` recursive expansion exceeded allowed nesting limit
---
*/
