/*
TEST_OUTPUT:
---
fail_compilation/fail213.d(22): Error: template instance `Foo!int` does not match template declaration `Foo(T : immutable(T))`
    alias Foo!(typeof(x)) f;
          ^
fail_compilation/fail213.d(29): Error: template instance `Foo!(const(int))` does not match template declaration `Foo(T : immutable(T))`
    alias Foo!(typeof(x)) f;
          ^
---
*/

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
