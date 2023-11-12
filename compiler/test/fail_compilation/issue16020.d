/*
TEST_OUTPUT:
---
fail_compilation/issue16020.d(17): Error: user-defined attributes not allowed for `alias` declarations
fail_compilation/issue16020.d(18): Error: semicolon expected to close `alias` declaration, not `(`
fail_compilation/issue16020.d(18): Error: declaration expected, not `(`
fail_compilation/issue16020.d(20): Deprecation: storage class `const shared` has no effect in type aliases
fail_compilation/issue16020.d(22): Deprecation: storage class `const shared` has no effect in type aliases
fail_compilation/issue16020.d(26): Deprecation: storage class `immutable inout` has no effect in type aliases
fail_compilation/issue16020.d(28): Deprecation: storage class `immutable inout` has no effect in type aliases
---
*/
// function type aliases
module issue16020;

struct UDA{}
alias Fun = @UDA void();
alias FunTemplate = void(T)(T t);

alias F61 = int() const shared;
alias int F62() const shared ;
alias F63 = const shared int();
static assert (is(F61 == F62));
static assert (is(F63 == F62));

alias F71 = int() immutable inout;
alias int F72() immutable inout;
alias F73 = immutable inout int();
static assert (is(F71 == F72));
static assert (is(F73 == F72));

