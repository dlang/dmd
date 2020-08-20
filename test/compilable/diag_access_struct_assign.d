// REQUIRED_ARGS: -wi -unittest -diagnose=access -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_struct_assign.d(16): Warning: unmodified public variable `x` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_struct_assign.d(24): Warning: unmodified public variable `x` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_struct_assign.d(25): Warning: unmodified public variable `y` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
---
*/

struct S {}

S f()
{
	S x;                        // warn
    S y;
    y = x;
    return y;
}

S g()
{
	S x;                        // warn
    S y = x;                    // warn
    return y;
}
