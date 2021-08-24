/**
  EXTRA_SOURCES: imports/test5309.d
*/
module test5309;

extern(D, imports.test5309) {
    extern class FooBar;
    extern int foo(FooBar f);
}

extern(D,) void notreferenced();

extern(D, imports)
{
    extern(D, test5309) extern __gshared int global;
}

void main ()
{
    assert(foo(null) == 42);
    assert(global == 84);
}
