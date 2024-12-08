/*
TEST_OUTPUT:
---
fail_compilation/fail237.d(15): Error: undefined identifier `a` in module `fail237`
static assert(.a!().b);
              ^
fail_compilation/fail237.d(15):        while evaluating: `static assert(module fail237.a!().b)`
static assert(.a!().b);
^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=581
// Error message w/o line number in dot-instantiated template
static assert(.a!().b);
