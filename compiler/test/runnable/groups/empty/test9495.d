import core.vararg;

int func1(int a, ...)
{
  auto result = va_arg!int(_argptr);
  return result;
}

void test9495a()
{
  assert(func1(5, 12345678) == 12345678);
}

int func2(const(char)[] a, ...)
{
  auto result = va_arg!int(_argptr);
  return result;
}

void test9495b()
{
  assert(func2("5", 12345678) == 12345678);
}

shared static this()
{
  test9495a();
  test9495b();
}
