
template Foo(T:invariant(T))
{
    alias T Foo;
}

void main()
{
  {
    int x;
    alias Foo!(typeof(x)) f;
    printf("%s\n", typeid(f).toString().ptr);
    assert(is(typeof(x) == int));
    assert(is(f == int));
  }
}
