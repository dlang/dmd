/*
TEST_OUTPUT:
---
fail_compilation/issue21247.d(12): Error: static assert:  "foo"
---
*/

alias AliasSeq(T...) = T;

alias check(T) = AliasSeq!(false, "foo");

static assert(check!int);
