/*
TEST_OUTPUT:
---
fail_compilation/fail3022.d(15): Error: variable fail3022.main.x conflict stack allocation and allocator call
---
*/

class Foo
{
    new(size_t, int) { return null; }
}

void main()
{
    scope x = new(1) Foo();
}
