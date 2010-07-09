struct Foo {
  void foo(int x) {}
}

void main() {
   void delegate (int) a = &Foo.foo;
}

