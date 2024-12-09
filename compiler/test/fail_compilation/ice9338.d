/*
TEST_OUTPUT:
---
fail_compilation/ice9338.d(17): Error: value of `this` is not known at compile time
        enum members1 = makeArray();
                                 ^
fail_compilation/ice9338.d(18): Error: value of `this` is not known at compile time
        enum members2 = this.makeArray();
                        ^
---
*/

class Foo
{
    void test()
    {
        enum members1 = makeArray();
        enum members2 = this.makeArray();
    }

    string[] makeArray()
    {
        return ["a"];
    }
}
