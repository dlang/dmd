/*
TEST_OUTPUT:
---
fail_compilation/fail13336a.d(27): Error: choose(true) is not an lvalue
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
    static assert(is(typeof(&choose) == Animal function(bool)));    // pass

    choose(true) = new Dog();
}
