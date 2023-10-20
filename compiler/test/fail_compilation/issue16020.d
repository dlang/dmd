/*
TEST_OUTPUT:
---
fail_compilation/issue16020.d(1): Error: user-defined attributes not allowed for `alias` declarations
fail_compilation/issue16020.d(2): Error: semicolon expected to close `alias` declaration, not `(`
fail_compilation/issue16020.d(2): Error: declaration expected, not `(`
---
*/
module issue16020;

struct UDA{}
#line 1
alias Fun = @UDA void();
alias FunTemplate = void(T)(T t);
