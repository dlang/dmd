/*
TEST_OUTPUT:
---
fail_compilation/mixin_template.d(12): Error: mixin `mixin_template.f!1` - `f` is a function, not a template
mixin f!1;
^
---
*/
string f() {
    return "int i;";
}
mixin f!1;
