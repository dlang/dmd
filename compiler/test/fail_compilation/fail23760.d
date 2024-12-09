// https://issues.dlang.org/show_bug.cgi?id=23760

/*
TEST_OUTPUT:
---
fail_compilation/fail23760.d(24): Error: type of variable `fail23760.A.state` has errors
    alias T = __traits(getOverloads, Class, "state");
              ^
fail_compilation/fail23760.d(24): Error: `(A).state` cannot be resolved
    alias T = __traits(getOverloads, Class, "state");
              ^
fail_compilation/fail23760.d(29): Error: template instance `fail23760.JavaBridge!(A)` error instantiating
    JavaBridge!(CRTP) _javaDBridge;
    ^
fail_compilation/fail23760.d(32):        instantiated from here: `JavaClass!(A)`
class A : JavaClass!A
          ^
---
*/

class JavaBridge(Class)
{
    static if(is(typeof(__traits(getMember, Class, "state")))) {}
    alias T = __traits(getOverloads, Class, "state");
}

class JavaClass(CRTP)
{
    JavaBridge!(CRTP) _javaDBridge;
}

class A : JavaClass!A
{
    State* state;
}
