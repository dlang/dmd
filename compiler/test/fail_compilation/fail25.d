/*
TEST_OUTPUT:
---
fail_compilation/fail25.d(16): Error: accessing non-static variable `yuiop` requires an instance of `Qwert`
        return Qwert.yuiop + 105;
               ^
---
*/

class Qwert
{
    int yuiop;

    static int asdfg()
    {
        return Qwert.yuiop + 105;
    }
}
