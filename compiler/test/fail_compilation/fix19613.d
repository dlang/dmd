/*
TEST_OUTPUT:
---
fail_compilation\fix19613.d(14): Error: function `fix19613.B.a` cannot override `final` function `fix19613.A.a`
fail_compilation\fix19613.d(14): Error: function `fix19613.B.a` does not override any function
---
*/

class A {
        final void a(int) {}
        void a(string) {}
}
class B : A {
        override void a(int) {}
}
