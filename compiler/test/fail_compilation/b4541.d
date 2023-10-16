/*
TEST_OUTPUT:
---
fail_compilation/b4541.d(10): Error: cannot take address of intrinsic function `sin`
fail_compilation/b4541.d(10):        use `&std.math.sin` instead
---
*/
import core.math;
void test() {
    real function(real) c = &sin;
}
