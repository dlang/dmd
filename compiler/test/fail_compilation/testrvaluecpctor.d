// https://issues.dlang.org/show_bug.cgi?id=22593

/*
TEST_OUTPUT:
---
/*
TEST_OUTPUT:
---
fail_compilation/testrvaluecpctor.d(19): Error: cannot define both an rvalue constructor and a copy constructor for `struct Foo`
fail_compilation/testrvaluecpctor.d(27):        Template instance `testrvaluecpctor.Foo!int.Foo.this!(immutable(Foo!int), immutable(Foo!int))` creates an rvalue constructor for `struct Foo`
fail_compilation/testrvaluecpctor.d(27): Error: none of the overloads of `this` can construct an immutable object with argument types `(immutable(Foo!int))`. Expected `immutable(immutable(Foo!int))`
fail_compilation/testrvaluecpctor.d(21):        Candidate 1 is: `testrvaluecpctor.Foo!int.Foo.this(ref scope Foo!int rhs)`
fail_compilation/testrvaluecpctor.d(19):        Candidate 2 is: `this(Rhs, this This)(scope Rhs rhs)`
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

// https://issues.dlang.org/show_bug.cgi?id=21613

/*
TEST_OUTPUT:
---
fail_compilation/testrvaluecpctor.d(43): Error: cannot define both an rvalue constructor and a copy constructor for `struct Test`
fail_compilation/testrvaluecpctor.d(49):        Template instance `testrvaluecpctor.Test.this!()` creates an rvalue constructor for `struct Test`
---
*/

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
