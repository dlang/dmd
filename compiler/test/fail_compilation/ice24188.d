/*
REQUIRED_ARGS: fail_compilation/ice24188_a/ice24188_c.d
TEST_OUTPUT:
---
fail_compilation/ice24188.d(10): Error: module `ice24188_c` from file fail_compilation/ice24188_a/ice24188_c.d must be imported with 'import ice24188_c;'
fail_compilation/ice24188.d(10):        `fail_compilation/ice24188_a/ice24188_c.d` has no module declaration, so its module name was inferred as `ice24188_c` from the filename
---
*/
auto b() {
    import fail_compilation.ice24188_a.ice24188_c : D;

    struct A {
        D e;
    }
}
