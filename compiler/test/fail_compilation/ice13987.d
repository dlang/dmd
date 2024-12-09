/*
TEST_OUTPUT:
---
fail_compilation/ice13987.d(11): Error: cannot use array to initialize `S`
S s = [{}];
      ^
---
*/

struct S {}
S s = [{}];
