interface TestInterface 
{
    void tpl(T)();
//    int x;
}

class TestImplementation : TestInterface 
  { void tpl(T)() { } }

void main()
{
  /* TestImplementation t = new TestImplementation(); // works */

  TestInterface t = new TestImplementation(); // fails

  t.tpl!(int)();
}

