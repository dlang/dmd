/**
TEST_OUTPUT:
---
fail_compilation/fail18057.d(20): Error: template instance `RBNode!int` `RBNode` is not a template declaration, it is a struct
alias bug18057 = RBNode!int;
                 ^
fail_compilation/fail18057.d(17): Error: variable `fail18057.RBNode.copy` recursive initialization of field
    RBNode *copy = new RBNode;
                   ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=18057
// Recursive field initializer causes segfault.
struct RBNode
{
    RBNode *copy = new RBNode;
}

alias bug18057 = RBNode!int;
