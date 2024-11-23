/*
TEST_OUTPUT:
---
fail_compilation/fail7861.d(22): Error: no property `nonexistent` for type `test.B`
enum C = B.nonexistent;
         ^
fail_compilation/fail7861.d(18):        struct `B` defined here
struct B {
^
---
*/
module test;

mixin template A() {
import test;
}

struct B {
mixin A!();
}

enum C = B.nonexistent;
