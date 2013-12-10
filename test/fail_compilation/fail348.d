/*
TEST_OUTPUT:
---
fail_compilation/fail348.d(15): Error: pure function 'fail348.f.g.h' cannot call impure function 'fail348.f.g'
---
*/

void f() pure
{
    void g()
    {
        void h() pure
        {
            void i() { }
            void j() { i(); g(); }
        }
    }
}
