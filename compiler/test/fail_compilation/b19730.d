/*
TEST_OUTPUT:
---
fail_compilation/b19730.d(14): Error: found `)` while expecting `=` or identifier
  if (const x) {}
            ^
fail_compilation/b19730.d(15): Error: found `)` while expecting `=` or identifier
  if (auto x) {}
           ^
---
*/
void func() {
  bool x;
  if (const x) {}
  if (auto x) {}
}
