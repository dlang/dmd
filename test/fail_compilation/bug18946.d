// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/bug18743.d(15): Deprecation: `throwingFunc()` assert error messages must not throw
---
*/
// https://issues.dlang.org/show_bug.cgi?id=18946
void main() {

    static string throwingFunc()
    {
        throw new Exception("An exception");
    }
    assert(0, throwingFunc());
}
