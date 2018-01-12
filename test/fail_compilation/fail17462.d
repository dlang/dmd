/*
TEST_OUTPUT:
---
fail_compilation/fail17462.d(19): Error: class fail17462.Derived1 interface function `void foo()` is not implemented
fail_compilation/fail17462.d(20): Error: class fail17462.Derived2 interface function `void bar()` is not implemented
fail_compilation/fail17462.d(20): Error: class fail17462.Derived2 interface function `void foo()` is not implemented
---
*/

interface Marker { void bar();}
interface Foo { void foo(); }
interface Bar {}

interface FooMarked : Foo, Marker{}
interface MarkedFoo : Marker, Foo  {}

class Base : Foo { void foo() {} }

class Derived1 : Base, FooMarked { void bar() {}}
class Derived2 : Base, MarkedFoo {}

void main() {}
