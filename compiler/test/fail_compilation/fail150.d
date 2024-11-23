/*
TEST_OUTPUT:
---
fail_compilation/fail150.d(24): Error: `.new` is only for allocating nested classes
    myclass.new Foo();
            ^
---
*/

//import std.stdio;

class Class1
{
}

class Foo
{
}

int main(char[][] argv)
{
    Class1 myclass = new Class1;

    myclass.new Foo();
    return 0;
}
