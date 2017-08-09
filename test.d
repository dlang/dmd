auto fnX(int y) @safe
{
  uint FooBar;
  char* Foozel;
  return () @trusted {return FooBar + Foozel + y;} () ;

}
