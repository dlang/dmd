/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test23134.d(105): Error: cannot implicitly convert expression `T(& x)` of type `T` to `immutable(T)`
fail_compilation/test23134.d(108): Error: cannot implicitly convert expression `S(&foo)` of type `S` to `immutable(S)`
fail_compilation/test23134.d(109): Error: cannot implicitly convert expression `&foo` of type `void delegate() pure nothrow @nogc @safe` to `immutable(void delegate() @safe)`
fail_compilation/test23134.d(110): Error: cannot implicitly convert expression `__lambda6` of type `void delegate() pure nothrow @nogc @safe` to `immutable(void delegate() @safe)`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23134

struct S {
@safe:
     void delegate() dg;
}

struct T { int* p; }

#line 100

@safe
void main() {
     int x = 42;

     immutable T t = T(&x);

     void foo() { ++x; }
     immutable S s1 = S(&foo);
     immutable S s2 = { &foo };
     immutable S s3 = { () { x++; } };
}
