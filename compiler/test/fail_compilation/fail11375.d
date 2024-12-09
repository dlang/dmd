/*
TEST_OUTPUT:
---
fail_compilation/fail11375.d(22): Error: constructor `fail11375.D!().D.this` is not `nothrow`
    auto d = new D!()();
             ^
       which calls `fail11375.B.this`
fail_compilation/fail11375.d(20): Error: function `D main` may throw but is marked as `nothrow`
void main() nothrow
     ^
---
*/

class B {
    this() {}
}

class D() : B {}

void main() nothrow
{
    auto d = new D!()();
}
