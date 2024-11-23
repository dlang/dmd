/*
EXTRA_FILES: imports/constraints.d
TEST_OUTPUT:
---
fail_compilation/constraints_defs.d(63): Error: template instance `constraints_defs.main.def!(int, 0, (a) => a)` does not match template declaration `def(T, int i = 5, alias R)()`
  with `T = int,
       i = 0,
       R = __lambda_L63_C18`
  must satisfy the following constraint:
`       N!T`
    def!(int, 0, a => a)();
    ^
fail_compilation/constraints_defs.d(64): Error: template instance `imports.constraints.defa!int` does not match template declaration `defa(T, U = int)()`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
    defa!(int)();
    ^
fail_compilation/constraints_defs.d(65): Error: template instance `imports.constraints.defv!()` does not match template declaration `defv(T = bool, int i = 5, Ts...)()`
  with `Ts = ()`
  must satisfy the following constraint:
`       N!T`
    defv!()();
    ^
fail_compilation/constraints_defs.d(66): Error: template instance `imports.constraints.defv!int` does not match template declaration `defv(T = bool, int i = 5, Ts...)()`
  with `T = int,
       Ts = ()`
  must satisfy the following constraint:
`       N!T`
    defv!(int)();
    ^
fail_compilation/constraints_defs.d(67): Error: template instance `imports.constraints.defv!(int, 0)` does not match template declaration `defv(T = bool, int i = 5, Ts...)()`
  with `T = int,
       i = 0,
       Ts = ()`
  must satisfy the following constraint:
`       N!T`
    defv!(int, 0)();
    ^
fail_compilation/constraints_defs.d(68): Error: template instance `imports.constraints.defv!(int, 0, bool)` does not match template declaration `defv(T = bool, int i = 5, Ts...)()`
  with `T = int,
       i = 0,
       Ts = (bool)`
  must satisfy the following constraint:
`       N!T`
    defv!(int, 0, bool)();
    ^
fail_compilation/constraints_defs.d(69): Error: template instance `imports.constraints.defv!(int, 0, bool, float)` does not match template declaration `defv(T = bool, int i = 5, Ts...)()`
  with `T = int,
       i = 0,
       Ts = (bool, float)`
  must satisfy the following constraint:
`       N!T`
    defv!(int, 0, bool, float)();
    ^
---
*/

void main()
{
    import imports.constraints;

    def!(int, 0, a => a)();
    defa!(int)();
    defv!()();
    defv!(int)();
    defv!(int, 0)();
    defv!(int, 0, bool)();
    defv!(int, 0, bool, float)();
}
