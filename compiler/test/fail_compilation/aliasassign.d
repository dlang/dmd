/* TEST_OUTPUT:
---
fail_compilation/aliasassign.d(21): Error: `B` must have same parent `Swap!(int, string)` as alias `B`
    B = A;
    ^
fail_compilation/aliasassign.d(22): Error: `A` must have same parent `Swap!(int, string)` as alias `A`
    A = B;
    ^
fail_compilation/aliasassign.d(29): Error: template instance `aliasassign.Swap!(int, string)` error instantiating
static assert(Swap!(A, B));
              ^
fail_compilation/aliasassign.d(29):        while evaluating: `static assert(Swap!(int, string))`
static assert(Swap!(A, B));
^
---
*/

template Swap (alias A, alias B)
{
    alias C = A;
    B = A;
    A = B;
    enum Swap = true;
}

alias A = int;
alias B = string;

static assert(Swap!(A, B));
