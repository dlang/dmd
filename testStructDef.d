struct S
{
  this(uint x) {}
  ubyte b;
  uint one()
  {
    S s;
    return 1;
  }
}

uint one()
{
  S s;
  return s.one;  
}

static assert(one);
