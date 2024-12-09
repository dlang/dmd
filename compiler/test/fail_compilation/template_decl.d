/*
TEST_OUTPUT:
---
fail_compilation/template_decl.d(12): Error: `{` expected after template parameter list, not `(`
template b(alias d)() {
                   ^
fail_compilation/template_decl.d(12): Error: declaration expected, not `(`
template b(alias d)() {
                   ^
---
*/
template b(alias d)() {
}
