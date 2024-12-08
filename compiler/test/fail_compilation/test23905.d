// https://issues.dlang.org/show_bug.cgi?id=23905

/*
TEST_OUTPUT:
---
fail_compilation/test23905.d(26): Error: enum `test23905.Foo` is opaque and has no default initializer
    SumType!Foo data = Foo.init;
                       ^
---
*/

struct SumType(T)
{
    T storage;

    bool opEquals(Rhs)(Rhs rhs)
    if (is(typeof(Rhs.init)))
    {
    }

}

enum Foo;

void main(){
    SumType!Foo data = Foo.init;
}
