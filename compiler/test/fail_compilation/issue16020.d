/*
TEST_OUTPUT:
---
fail_compilation/issue16020.d(19): Error: user-defined attributes not allowed for `alias` declarations
alias Fun = @UDA void();
                 ^
fail_compilation/issue16020.d(20): Error: semicolon expected to close `alias` declaration, not `(`
alias FunTemplate = void(T)(T t);
                           ^
fail_compilation/issue16020.d(20): Error: declaration expected, not `(`
alias FunTemplate = void(T)(T t);
                           ^
fail_compilation/issue16020.d(21): Deprecation: storage class `final` has no effect in type aliases
---
*/
module issue16020;

struct UDA{}
alias Fun = @UDA void();
alias FunTemplate = void(T)(T t);
alias F2 = final int();
