/**
TEST_OUTPUT:
---
fail_compilation/diag_template_alias.d(1): Error: identifier expected for template `alias` parameter
fail_compilation/diag_template_alias.d(1): Error: semicolon expected following function declaration, not `(`
---
 */
#line 1
void func1(alias alias)() {}
