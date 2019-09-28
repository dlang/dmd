/* REQUIRED_ARGS: -preview=rvaluetype
TEST_OUTPUT:
---
fail_compilation/rvalue_type1.d(15): Error: enum `rvalue_type1.E` base type cannot be `__rvalue`
fail_compilation/rvalue_type1.d(17): Error: variable `rvalue_type1.a` `@rvalue` types can only be used in `ref` function parameters or with pointer types
fail_compilation/rvalue_type1.d(18): Error: variable `rvalue_type1.b` `@rvalue` types can only be used in `ref` function parameters or with pointer types
fail_compilation/rvalue_type1.d(20): Error: only `ref` parameters can be `@rvalue`
fail_compilation/rvalue_type1.d(21): Error: only `ref` parameters can be `@rvalue`
fail_compilation/rvalue_type1.d(22): Error: only `ref` parameters can be `@rvalue`
fail_compilation/rvalue_type1.d(24): Error: only `ref` parameters can be `@rvalue`
fail_compilation/rvalue_type1.d(25): Error: functions cannot return `@rvalue` types except by `ref`
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
