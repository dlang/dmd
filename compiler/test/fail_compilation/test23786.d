/* TEST_OUTPUT:
---
fail_compilation/test23786.d(34): Error: function `foo` is not callable using argument types `(double)`
    __traits(parent, {})(1.0);
                        ^
fail_compilation/test23786.d(34):        cannot pass argument `1.0` of type `double` to parameter `int i`
fail_compilation/test23786.d(31):        `test23786.foo(int i)` declared here
void foo(int i)
     ^
fail_compilation/test23786.d(41): Error: function `bar` is not callable using argument types `(int*)`
    __traits(parent, {})(&i);
                        ^
fail_compilation/test23786.d(41):        cannot pass argument `& i` of type `int*` to parameter `int i`
fail_compilation/test23786.d(38):        `test23786.bar(int i)` declared here
void bar(int i)
     ^
fail_compilation/test23786.d(49): Error: function `baz` is not callable using argument types `(int*)`
    __traits(parent, {})(&i);
                        ^
fail_compilation/test23786.d(49):        cannot pass argument `& i` of type `int*` to parameter `int i`
fail_compilation/test23786.d(46):        `test23786.baz(int i)` declared here
void baz(int i)
     ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23786

module test23786;

void foo(int i)
{
    static assert(__traits(parent, {}).mangleof == "_D9test237863fooFiZv");
    __traits(parent, {})(1.0);
}
void foo(int* p) {}

void bar(int i)
{
    static assert(__traits(parent, {}).mangleof == "_D9test237863barFiZv");
    __traits(parent, {})(&i);
}
void bar(int* p) {}

void baz(int* p) {}
void baz(int i)
{
    static assert(__traits(parent, {}).mangleof == "_D9test237863bazFiZv");
    __traits(parent, {})(&i);
}
void baz(float* p) {}
