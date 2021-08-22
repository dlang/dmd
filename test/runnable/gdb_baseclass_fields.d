/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b gdb_baseclass_fields.d:30
r
set print pretty off
echo RESULT=
p *c
---
GDB_MATCH: RESULT=.*a = 1.* b = 2
*/

class B {
  uint a;
}

class C : B {
  int b;
}


void main()
{
  C c = new C();
  c.a = 1;
  c.b = 2;

  int bp = 1;
}
