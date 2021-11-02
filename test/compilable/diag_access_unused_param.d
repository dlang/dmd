// REQUIRED_ARGS: -wi -vcolumns -unittest -vunused

/*
TEST_OUTPUT:
---
compilable/diag_access_unused_param.d(37,5): Warning: value assigned to public parameter `x` of function is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_param.d(35,6): Warning: unused modified public parameter `x` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_param.d(50,5): Warning: value assigned to public parameter `x` of function is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_param.d(48,14): Warning: unused modified public parameter `x` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_param.d(31,6): Warning: unused parameter `x` of function, pass type `int` only by removing or commenting out name `x` to silence
compilable/diag_access_unused_param.d(40,14): Warning: unused private function `g0` of module
compilable/diag_access_unused_param.d(44,14): Warning: unused private function `g1` of module
compilable/diag_access_unused_param.d(44,14): Warning: unused parameter `x` of function, pass type `int` only by removing or commenting out name `x` to silence
compilable/diag_access_unused_param.d(48,14): Warning: unused private function `g2` of module
compilable/diag_access_unused_param.d(53,14): Warning: unused private function `h1` of module
compilable/diag_access_unused_param.d(53,14): Warning: unused parameter `x` of function, pass type `int` only by removing or commenting out name `x` to silence
compilable/diag_access_unused_param.d(53,14): Warning: unused parameter `b` of function, pass type `bool` only by removing or commenting out name `b` to silence
compilable/diag_access_unused_param.d(57,14): Warning: unused private function `h2` of module
compilable/diag_access_unused_param.d(57,14): Warning: unused parameter `x` of function, pass type `int` only by removing or commenting out name `x` to silence
compilable/diag_access_unused_param.d(57,14): Warning: unused parameter `b` of function, pass type `bool` only by removing or commenting out name `b` to silence
compilable/diag_access_unused_param.d(65,14): Warning: unused private function `h4` of module
---
*/

@safe pure:

void f0(int)
{
}

void f1(int x)
{
}

void f2(int x)
{
    x = 32;
}

private void g0(int)
{
}

private void g1(int x)
{
}

private void g2(int x)
{
    x = 42;
}

private void h1(int x, bool b)
{
}

private void h2(int x, bool b = false)
{
}

private void h3(int x) // TODO unused variable
{
}

private void h4(int x)
{
    h3(x);
}
