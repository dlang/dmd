/*
TEST_OUTPUT:
---
fail_compilation/fail11375.d(17): Error: constructor `fail11375.D!().D.this` is not `nothrow`
fail_compilation/fail11375.d(13):          could not infer `nothrow` for `fail11375.D!().D.this` because:
fail_compilation/fail11375.d(13):          - calling `fail11375.B.this` which is not `nothrow`
fail_compilation/fail11375.d(15): Error: `nothrow` function `D main` may throw
---
*/
#line 9
class B {
    this() {}
}

class D() : B {}

void main() nothrow
{
    auto d = new D!()();
}
