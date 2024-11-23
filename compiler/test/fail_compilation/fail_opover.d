// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/fail_opover.d(95): Error: no `[]` operator overload for type `object.Object`
    m[] = error;
     ^
$p:object.d$(110):        `object.Object` declared here
class Object
^
fail_compilation/fail_opover.d(99): Error: no `[]` operator overload for type `TestS`
    s[] = error;
     ^
fail_compilation/fail_opover.d(97):        `fail_opover.test1.TestS` declared here
    struct TestS {}
    ^
fail_compilation/fail_opover.d(111): Error: no `[]` operator overload for type `S`
    s[];            // in ArrayExp::op_overload()
     ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(112): Error: no `[]` operator overload for type `S`
    s[1];           // ditto
     ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(113): Error: no `[]` operator overload for type `S`
    s[1..2];        // ditto
     ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(114): Error: no `[]` operator overload for type `S`
    +s[];           // in UnaExp::op_overload()
      ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(115): Error: no `[]` operator overload for type `S`
    +s[1];          // ditto
      ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(116): Error: no `[]` operator overload for type `S`
    +s[1..2];       // ditto
      ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(117): Error: no `[]` operator overload for type `S`
    s[] = 3;        // in AssignExp::semantic()
     ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(118): Error: no `[]` operator overload for type `S`
    s[1] = 3;       // ditto
     ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(119): Error: no `[]` operator overload for type `S`
    s[1..2] = 3;    // ditto
     ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(120): Error: no `[]` operator overload for type `S`
    s[] += 3;       // in BinAssignExp::op_overload()
     ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(121): Error: no `[]` operator overload for type `S`
    s[1] += 3;      // ditto
     ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
fail_compilation/fail_opover.d(122): Error: no `[]` operator overload for type `S`
    s[1..2] += 3;   // ditto
     ^
fail_compilation/fail_opover.d(104):        `fail_opover.test2.S` declared here
    struct S
    ^
---
*/
void test1()
{
    Object m;
    m[] = error;

    struct TestS {}
    TestS s;
    s[] = error;
}

void test2()
{
    struct S
    {
        void func(int) {}
        alias func this;
    }
    S s;
    // The errors failing aliasthis access need to be gagged for better error messages.
    s[];            // in ArrayExp::op_overload()
    s[1];           // ditto
    s[1..2];        // ditto
    +s[];           // in UnaExp::op_overload()
    +s[1];          // ditto
    +s[1..2];       // ditto
    s[] = 3;        // in AssignExp::semantic()
    s[1] = 3;       // ditto
    s[1..2] = 3;    // ditto
    s[] += 3;       // in BinAssignExp::op_overload()
    s[1] += 3;      // ditto
    s[1..2] += 3;   // ditto
}
