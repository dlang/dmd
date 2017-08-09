uint fn()
{
  uint x = 7;
  modx(&x);
  return x;
}

void modx(uint* x)
{
    *x = 12;
    uint xy;
    foreach(i; 0 .. 4096*10)
    {
      xy++;
    }

    return ;
}

static assert(fn() == 12);
