/*
TEST_OUTPUT:
---
fail_compilation/fail276.d(23): Error: `this` has no effect
                    this.outer.outer;
                    ^
fail_compilation/fail276.d(19): Error: cannot construct anonymous nested class because no implicit `this` reference to outer class is available
            auto k = new class()
                     ^
---
*/

class C
{
    this()
    {
        auto i = new class()
        {
            auto k = new class()
            {
                void func()
                {
                    this.outer.outer;
                }
            };
        };
    }
    int i;
}
void main() {}
