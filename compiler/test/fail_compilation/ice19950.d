/*
TEST_OUTPUT:
---
fail_compilation/ice19950.d(10): Error: undefined identifier `NotHere`
fail_compilation/ice19950.d(11): Error: template instance `ice19950.baz!()` does not match template declaration `baz()(Foo)`
fail_compilation/ice19950.d(11):        instantiated from here: `baz!()`
fail_compilation/ice19950.d(13):        Candidate match: baz()(Foo) if (true)
---
*/

#line 100

alias Foo = NotHere;
alias Bar = baz!();

void baz()(Foo)
    if (true)
{}
