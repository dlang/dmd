void main()
{
  TFoo!(int).t; // should produce a "no identifier" error.
}
template TFoo(T) { alias T* t; }


