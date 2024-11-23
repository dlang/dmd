/*
TEST_OUTPUT:
---
fail_compilation/fail215.d(12): Error: function `fail215.b.k` cannot be both `final` and `abstract`
    final abstract void k();
                        ^
---
*/

class b
{
    final abstract void k();
}
