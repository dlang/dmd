/* REQUIRED_ARGS: -recursion-limit=0
TEST_OUTPUT:
---
42
---
*/

enum NUMBER_OF_STRUCTS = 400;

struct Struct(uint N) {
    enum value = Struct!(N-1).value;
}

struct Struct(uint N: 0) {
    enum value = 42;
}


void main()
{
    pragma(msg, Struct!NUMBER_OF_STRUCTS.value);
}
