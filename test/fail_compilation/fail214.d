
template Foo(T:invariant(T))
{
    alias T Foo;
}

void main()
{
  {
    const int x;
    alias Foo!(typeof(x)) f;
  }
}
