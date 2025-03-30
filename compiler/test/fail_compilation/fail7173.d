/*
TEST_OUTPUT:
---
fail_compilation/fail7173.d(23): Error: expression `b1._a.opBinary(b2._a).fun()` is `void` and has no value
---
*/
struct A{

  A opBinary(string op)(A a){ A rt; return rt; }

  void fun(){ }
}

struct B{

  A _a;
  alias _a this;
}


void main(){

  B b1, b2, b3; b3 = (b1 - b2).fun();
}
