uint[3] fn(uint a)
{
  uint b = 1;
  
  uint r = (a++, a++, b++);
  return [a, r, b];
}

static assert(fn(2) == [4, 1, 2]);
