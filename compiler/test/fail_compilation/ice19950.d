/*
TEST_OUTPUT:
---
fail_compilation/ice19950.d(12): Error: undefined identifier `NotHere`
alias Foo = NotHere;
            ^
fail_compilation/ice19950.d(13): Error: template instance `ice19950.baz!()` does not match template declaration `baz()(Foo)`
alias Bar = baz!();
            ^
---
*/
alias Foo = NotHere;
alias Bar = baz!();

void baz()(Foo)
    if (true)
{}
