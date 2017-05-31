int fn(int a, int b, int c)
{
  return a * b -c;
}

static assert(fn(3,3,4) == 5);
