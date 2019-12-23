/* REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/issue19325.d(11): Deprecation: Usage of the `body` keyword is deprecated. Use `do` instead.
fail_compilation/issue19325.d(12): Deprecation: Usage of the `body` keyword is deprecated. Use `do` instead.
fail_compilation/issue19325.d(13): Deprecation: Usage of the `body` keyword is deprecated. Use `do` instead.
fail_compilation/issue19325.d(16): Deprecation: Usage of the `body` keyword is deprecated. Use `do` instead.
---
*/

void foo () in {} body {}
class Foo { void foo() in {} body {} }
void bar() out {} body {
    void fun (void* ptr)
        in(ptr !is null)
        body {
            int body;
        }
}
