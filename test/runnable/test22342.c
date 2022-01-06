/* RUN_OUTPUT:
---
B
A
B
---
 */

// https://issues.dlang.org/show_bug.cgi?id=22342

int printf(const char *, ...);

int foo()
{
  printf("A\n");
  return 0;
}

int bar()
{
  printf("B\n");
  return 0;
}

int main()
{
  int v;
  return bar(1, &v, foo(), "str", bar());
}
