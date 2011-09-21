
template Foo(T:immutable(T))
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
