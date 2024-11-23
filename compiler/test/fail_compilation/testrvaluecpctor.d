// https://issues.dlang.org/show_bug.cgi?id=22593
// https://issues.dlang.org/show_bug.cgi?id=21613

/*
TEST_OUTPUT:
---
fail_compilation/testrvaluecpctor.d(33): Error: cannot define both an rvalue constructor and a copy constructor for `struct Foo`
    this(Rhs, this This)(scope Rhs rhs){}
    ^
fail_compilation/testrvaluecpctor.d(41):        Template instance `testrvaluecpctor.Foo!int.Foo.__ctor!(immutable(Foo!int), immutable(Foo!int))` creates an rvalue constructor for `struct Foo`
    a.__ctor(a);
            ^
fail_compilation/testrvaluecpctor.d(41): Error: none of the overloads of `this` can construct a `immutable` object with argument types `(immutable(Foo!int))`
    a.__ctor(a);
            ^
fail_compilation/testrvaluecpctor.d(35):        Candidates are: `testrvaluecpctor.Foo!int.Foo.this(ref scope Foo!int rhs)`
    this(ref scope typeof(this) rhs){}
    ^
fail_compilation/testrvaluecpctor.d(33):                        `this(Rhs, this This)(scope Rhs rhs)`
    this(Rhs, this This)(scope Rhs rhs){}
    ^
fail_compilation/testrvaluecpctor.d(47): Error: cannot define both an rvalue constructor and a copy constructor for `struct Test`
    this()(const typeof(this) rhs){}    // rvalue ctor
    ^
fail_compilation/testrvaluecpctor.d(53):        Template instance `testrvaluecpctor.Test.__ctor!()` creates an rvalue constructor for `struct Test`
    Test b = cb;
         ^
---
*/

struct Foo(T)
{
    this(Rhs, this This)(scope Rhs rhs){}

    this(ref scope typeof(this) rhs){}
}

void fail22593()
{
    immutable Foo!int a;
    a.__ctor(a);
}

struct Test
{
    this(ref const typeof(this) rhs){}
    this()(const typeof(this) rhs){}    // rvalue ctor
}

void fail21613()
{
    const Test cb;
    Test b = cb;
}
