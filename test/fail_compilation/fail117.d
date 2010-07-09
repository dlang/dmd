// 420

import std .stdio ;

template MGettor (alias Fld) {
  typeof(Fld) opCall () {
    writefln("getter");
    return Fld;
  }
}

class Foo {
  int a = 1 ,
      b = 2 ;

  mixin MGettor!(a) geta;
  mixin MGettor!(b) getb;
}

void main () {
  auto foo = new Foo;

  writefln(foo.geta);
  writefln(foo.getb);
}

