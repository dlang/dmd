// REQUIRED_ARGS: -Icompilable/imports

import test19746c;
import test19746b: Frop;

template Base(T)
{
    static if (is(T == super)) alias Base = Object;
}

class Foo
{
    class Nested: Base!Foo { }
    void func(Frop) { }
    void thunk() { }
}
