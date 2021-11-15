/* TEST_OUTPUT:
---
fail_compilation/alignas2.c(101): Error: no alignment-specifier for typedef declaration
fail_compilation/alignas2.c(103): Error: no alignment-specifier for function declaration
fail_compilation/alignas2.c(107): Error: no alignment-specifier for `register` storage class
fail_compilation/alignas2.c(110): Error: no alignment-specifier for parameters
fail_compilation/alignas2.c(115): Error: no alignment-specifier for parameters
fail_compilation/alignas2.c(116): Error: no declaration for identifier `x`
fail_compilation/alignas2.c(121): Error: no alignment-specifier for bit field declaration
fail_compilation/alignas2.c(122): Error: no alignment-specifier for bit field declaration
---
 */

#line 100

typedef _Alignas(4) int x;

_Alignas(8) int mercury();

void venus()
{
    register _Alignas(8) int x;
}

void earth(_Alignas(4) int x)
{
}

void mars(x)
_Alignas(4) int x;
{
}

struct B
{
    _Alignas(4) int bf : 3;
    _Alignas(8) int : 0;
};

