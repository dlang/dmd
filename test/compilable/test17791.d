/*
TEST_OUTPUT:
---
compilable/test17791.d(23): Deprecation: class `test17791.DepClass` is deprecated - A deprecated class
---
*/
deprecated("A deprecated class") {
class DepClass
{
}
}

class NewClass
{
}

void main()
{
    // test that a symbol (which is not likely to be deprecated)
    // is not depercated
    static assert(!__traits(isDeprecated, int));
    // check that a class marked deprecated "isDeprecated"
    static assert(__traits(isDeprecated, DepClass));
    // check that a class not marked deprecated is not deprecated
    static assert(!__traits(isDeprecated, NewClass));
}
