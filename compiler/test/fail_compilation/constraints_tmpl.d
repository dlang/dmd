/*
EXTRA_FILES: imports/constraints.d
TEST_OUTPUT:
---
fail_compilation/constraints_tmpl.d(105): Error: template instance `imports.constraints.dummy!()` does not match template declaration `dummy()()`
  must satisfy the following constraint:
`       false`
fail_compilation/constraints_tmpl.d(105):        instantiated from here: `dummy!()`
fail_compilation/imports/constraints.d(46):        Candidate match: dummy()() if (false)
fail_compilation/constraints_tmpl.d(107): Error: template instance `imports.constraints.message_nice!(int, int)` does not match template declaration `message_nice(T, U)()`
  with `T = int,
       U = int`
  must satisfy the following constraint:
`       N!U`
fail_compilation/constraints_tmpl.d(107):        instantiated from here: `message_nice!(int, int)`
fail_compilation/imports/constraints.d(47):        Candidate match: message_nice(T, U)() if (P!T && "message 1" && N!U && "message 2")
fail_compilation/constraints_tmpl.d(108): Error: template instance `imports.constraints.message_ugly!int` does not match template declaration `message_ugly(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_tmpl.d(108):        instantiated from here: `message_ugly!int`
fail_compilation/imports/constraints.d(48):        Candidate match: message_ugly(T)(T v) if (!N!T && T.stringof ~ " must be that" && N!T)
fail_compilation/constraints_tmpl.d(110): Error: template instance `args!int` does not match template declaration `args(T, U)()`
fail_compilation/constraints_tmpl.d(110):        instantiated from here: `args!int`
fail_compilation/imports/constraints.d(49):        Candidate match: args(T, U)() if (N!T || N!U)
fail_compilation/constraints_tmpl.d(111): Error: template instance `imports.constraints.args!(int, float)` does not match template declaration `args(T, U)()`
  with `T = int,
       U = float`
  must satisfy one of the following constraints:
`       N!T
       N!U`
fail_compilation/constraints_tmpl.d(111):        instantiated from here: `args!(int, float)`
fail_compilation/imports/constraints.d(49):        Candidate match: args(T, U)() if (N!T || N!U)
fail_compilation/constraints_tmpl.d(113): Error: template instance `constraints_tmpl.main.lambda!((a) => a)` does not match template declaration `lambda(alias pred)()`
  with `pred = __lambda1`
  must satisfy the following constraint:
`       N!int`
fail_compilation/constraints_tmpl.d(113):        instantiated from here: `lambda!((a) => a)`
fail_compilation/imports/constraints.d(50):        Candidate match: lambda(alias pred)() if (N!int)
---
*/

#line 100

void main()
{
    import imports.constraints;

    dummy!();

    message_nice!(int, int);
    message_ugly!int;

    args!int;
    args!(int, float);

    lambda!(a => a)();
}
