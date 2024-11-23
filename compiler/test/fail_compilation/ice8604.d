/*
TEST_OUTPUT:
---
fail_compilation/ice8604.d(11): Error: undefined identifier `i`
    static if(i) { }
              ^
---
*/
struct StructFoo
{
    static if(i) { }
    else enum z = "";
}

void main() { }
