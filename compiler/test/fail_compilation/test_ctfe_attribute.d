/*
TEST_OUTPUT:
---
fail_compilation/test_ctfe_attribute.d(13): Error: function `test_ctfe_attribute.add` is `@__ctfe` and cannot be used at runtime
fail_compilation/test_ctfe_attribute.d(16): Error: function `test_ctfe_attribute.add` is `@__ctfe` and cannot be used at runtime
---
*/

int add(int a) @__ctfe => a + 2;

void main() {
    // Error: calling @__ctfe function at runtime
    int x = add(9);

    // Error: taking address of @__ctfe function at runtime
    auto fp = &add;
}
