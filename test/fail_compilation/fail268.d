/*
TEST_OUTPUT:
---
fail_compilation/fail268.d(12): Error: constructor fail268.test.T!().this constructors are only for class or struct definitions
fail_compilation/fail268.d(13): Error: destructor fail268.test.T!().~this destructors are only for class/struct/union definitions, not function test
fail_compilation/fail268.d(17): Error: mixin fail268.test.T!() error instantiating
---
*/

template T()
{
    this(){}  // 14G ICE
    ~this() {}  // 14H ICE
}
void test()
{
    mixin T!();
}
