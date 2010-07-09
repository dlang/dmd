// 1645

import std.c.stdio;

class A
{
  int x;
  shared const void f()
  {
    printf("A\n");
  }
}

class B : A
{
  override const void f()
  {
//    x = 2;
    printf("B\n");
  }
}

void main(){
  A y = new B;
  y.f;
}

