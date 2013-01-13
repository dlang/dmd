// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 648

module ddoc648;

/// Mixin declaration
mixin template Mixin1()
{
    /// struct S
    struct S { }
}

/// class A
class A
{
    /// field x
    int x;

    /// no docs for mixin statement (only for expanded members)
    mixin Mixin1!();
}

/// Mixin declaration2
mixin template Mixin2()
{
    /// struct S2
    struct S2 { }
}

/// Mixin declaration3
mixin template Mixin3()
{
    /// another field
    int f;
    
    /// no docs for mixin statement (only for expanded members)
    mixin Mixin2!();
}

/// class B
class B
{
    /// no docs for mixin statement (only for expanded members)
    mixin Mixin3!();
}

/// no docs for mixin statement (only for expanded members)
mixin Mixin3!();
