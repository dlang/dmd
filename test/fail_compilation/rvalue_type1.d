/* REQUIRED_ARGS: -preview=rvaluetype
TEST_OUTPUT:
---
fail_compilation/rvalue_type1.d(16): Error: enum `rvalue_type1.E` base type cannot be `__rvalue`
fail_compilation/rvalue_type1.d(18): Error: variable `rvalue_type1.a` `@rvalue` types can only be used in `ref` function parameters or with pointer types
fail_compilation/rvalue_type1.d(19): Error: variable `rvalue_type1.b` `@rvalue` types can only be used in `ref` function parameters or with pointer types
fail_compilation/rvalue_type1.d(21): Error: only `ref` parameters can be `@rvalue`
fail_compilation/rvalue_type1.d(22): Error: only `ref` parameters can be `@rvalue`
fail_compilation/rvalue_type1.d(23): Error: only `ref` parameters can be `@rvalue`
fail_compilation/rvalue_type1.d(25): Error: only `ref` parameters can be `@rvalue`
fail_compilation/rvalue_type1.d(26): Error: functions cannot return `@rvalue` types except by `ref`
fail_compilation/rvalue_type1.d(32): Error: cannot pass lvalue default argument `g` to parameter `ref @rvalue(int) a = g`
---
*/

enum E : @rvalue(int) { a, }

@rvalue int a;
const(@rvalue(int)) b;

void f0(@rvalue int p);
void f1(out @rvalue int p);
void f2(lazy @rvalue int p);

alias T0 = void delegate(@rvalue int);
alias T1 = @rvalue(int) delegate();

ref @rvalue(int) f3(ref int a) { return a; }
ref @rvalue(int) f4(ref int a) { return 1; }

int g;
void f5(ref @rvalue int a = g);
