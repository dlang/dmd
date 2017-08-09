

bool testFn()
{
    uint a = 1;
    foreach(u;35 .. 69)
    {
      auto x = a << u;
    }
    return true;
}

static assert(testFn());
