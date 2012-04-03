class Foo
{
    // It is rather a bug that class template methods don't require an
    // explicit final/static, but changing this would probably break a
    // lot of code.
    void call(T)(T t) { }
}

void test()
{
    Foo foo;
    foo.call(2);
}
