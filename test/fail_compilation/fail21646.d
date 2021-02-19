/*
TEST_OUTPUT:
---
fail_compilation/fail21646.d(9): Error: cannot pass type `Type` as a function argument
---
*/
struct Type {
  enum a = __traits(compiles, Type());
  static if (int(Type)) { }
}
