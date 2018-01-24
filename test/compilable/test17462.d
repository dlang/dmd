interface Marker {}
interface Foo { void foo(); }
interface Bar {}

interface FooMarked : Foo, Marker{}
interface MarkedFoo : Marker, Foo  {}

class Base : Foo { void foo() {} }

class Derived1 : Base, FooMarked {}
class Derived2 : Base, MarkedFoo {}

void main() {}
