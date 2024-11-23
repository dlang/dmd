// REQUIRED_ARGS: -de

/*
TEST_OUTPUT:
---
fail_compilation/deprecated6760.d(17): Deprecation: `deprecated6760.Foo.opEquals` cannot be annotated with `@disable` because it is overriding a function in the base class
    @disable override bool opEquals(Object);
                           ^
fail_compilation/deprecated6760.d(22): Deprecation: `deprecated6760.Bar.opEquals` cannot be marked as `deprecated` because it is overriding a function in the base class
    deprecated override bool opEquals(Object);
                             ^
---
*/

class Foo
{
    @disable override bool opEquals(Object);
}

class Bar
{
    deprecated override bool opEquals(Object);
}
