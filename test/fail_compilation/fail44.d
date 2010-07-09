void Foo()
{
  void[] bar;
  void[] foo;
  
  bar.length = 50;
  foo.length = 50;
  
  for(int i=0; i<50; i++)
  {
    foo[i] = bar[i];
  }
}

