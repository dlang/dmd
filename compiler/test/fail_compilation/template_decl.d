/*
TEST_OUTPUT:
---
fail_compilation/template_decl.d(8): Error: `{` expected after template parameter list, not `(`
---
*/

template b(alias d)() {
}
