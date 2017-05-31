struct S
{
    uint pad;
    uint[] slice;
}

uint fn()
{
  S s;
  s.slice.length = 12;
  return cast(uint)s.slice.length;
}

// static assert(fn() == 12);
pragma(msg, fn());
