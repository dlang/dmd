/*
TEST_OUTPUT:
---
fail_compilation/diag3913.d(22): Error: no property `foobardoo` for type `Foo`
    auto a = Foo.foobardoo;
             ^
fail_compilation/diag3913.d(21):        enum `Foo` defined here
    enum Foo { first, second }
    ^
fail_compilation/diag3913.d(23): Error: no property `secon` for type `Foo`. Did you mean `Foo.second` ?
    auto b = Foo.secon;
             ^
fail_compilation/diag3913.d(21):        enum `Foo` defined here
    enum Foo { first, second }
    ^
---
*/

void main()
{
    enum Foo { first, second }
    auto a = Foo.foobardoo;
    auto b = Foo.secon;
}
