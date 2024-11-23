/*
TEST_OUTPUT:
---
fail_compilation/ice11518.d(23): Error: class `ice11518.B` matches more than one template declaration:
    new B!(A!void);
        ^
fail_compilation/ice11518.d(18):        `B(T : A!T)`
and:
class B(T : A!T) {}
^
fail_compilation/ice11518.d(19):        `B(T : A!T)`
class B(T : A!T) {}
^
---
*/

class A(T) {}
class B(T : A!T) {}
class B(T : A!T) {}

void main()
{
    new B!(A!void);
}
