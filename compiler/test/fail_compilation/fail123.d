/*
TEST_OUTPUT:
---
fail_compilation/fail123.d(15): Error: undefined identifier `type`
enum foo : type
^
fail_compilation/fail123.d(21): Error: enum `fail123.foo2` base type must not be `void`
enum foo2 : void { a, b }
^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=355
// ICE from enum : nonexistent type
enum foo : type
{
    blah1,
    blah2
}

enum foo2 : void { a, b }
