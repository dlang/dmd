/*
TEST_OUTPUT:
---
fail_compilation/fail9063.d(11): Error: static assert:  "msg"
static assert(false, bar);
^
---
*/

@property string bar() { return "msg"; }
static assert(false, bar);
