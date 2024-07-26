/*
TEST_OUTPUT:
---
fail_compilation/fail213.d(110): Error: template instance `Foo!int` does not match template declaration `Foo(T : immutable(T))`
fail_compilation/fail213.d(110):        instantiated from here: `Foo!int`
fail_compilation/fail213.d(101):        Candidate match: Foo(T : immutable(T))
fail_compilation/fail213.d(117): Error: template instance `Foo!(const(int))` does not match template declaration `Foo(T : immutable(T))`
fail_compilation/fail213.d(117):        instantiated from here: `Foo!(const(int))`
fail_compilation/fail213.d(101):        Candidate match: Foo(T : immutable(T))
---
*/

#line 100

template Foo(T:immutable(T))
{
    alias T Foo;
}

void main()
{
  {
    int x;
    alias Foo!(typeof(x)) f;
    //printf("%s\n", typeid(f).toString().ptr);
    assert(is(typeof(x) == int));
    assert(is(f == int));
  }
  {
    const int x;
    alias Foo!(typeof(x)) f;
  }
}
