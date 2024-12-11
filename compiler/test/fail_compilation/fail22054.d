// https://issues.dlang.org/show_bug.cgi?id=22054

/*
TEST_OUTPUT:
---
fail_compilation/fail22054.d(31): Error: no property `what` for type `fail22054.exception`
    assert(exception.what() == "Hello");
           ^
fail_compilation/fail22054.d(26):        `class fail22054.exception` is opaque and has no members.
class exception;
^
fail_compilation/fail22054.d(26):        class `exception` defined here
fail_compilation/fail22054.d(32): Error: no property `what` for type `fail22054.exception2`
    assert(exception2.what() == "Hello");
           ^
fail_compilation/fail22054.d(27):        `struct fail22054.exception2` is opaque and has no members.
struct exception2;
^
fail_compilation/fail22054.d(27):        struct `exception2` defined here
---
*/




class exception;
struct exception2;

void main ()
{
    assert(exception.what() == "Hello");
    assert(exception2.what() == "Hello");
}
