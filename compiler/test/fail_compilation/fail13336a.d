/*
TEST_OUTPUT:
---
fail_compilation/fail13336a.d(28): Error: cannot modify expression `choose(true)` because it is not an lvalue
---
*/

class Animal {}
class Cat : Animal {}
class Dog : Animal {}

Animal animal;
Cat cat;

auto ref choose(bool f)
{
    if (f)
        return cat;
    else
        return animal;
}

void main()
{
    //pragma(msg, typeof(&choose));
    static assert(is(typeof(&choose) == Animal function(bool) nothrow @nogc @safe));    // pass

    choose(true) = new Dog();
}
