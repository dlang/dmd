/*
TEST_OUTPUT:
---
fail_compilation/template_decl.d(7): Error: `{` expected after template parameter list, not `(`
fail_compilation/template_decl.d(7): Error: declaration expected, not `(`
---
*/
template b(alias d)() {
}
