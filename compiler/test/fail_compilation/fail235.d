/*
TEST_OUTPUT:
---
fail_compilation/fail235.d(17): Error: template instance `Tuple!(typeid(char))` expression `typeid(char)` is not a valid template value argument
auto K = Tuple!(typeid(char));
                ^
fail_compilation/fail235.d(23): Error: template instance `Alias!(typeid(char))` expression `typeid(char)` is not a valid template value argument
auto A = Alias!(typeid(char));
                ^
---
*/
template Tuple(TPL...)
{
    alias TPL Tuple;
}

auto K = Tuple!(typeid(char));

template Alias(alias A)
{
    alias A Alias;
}
auto A = Alias!(typeid(char));
