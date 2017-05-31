struct iota_range
{
  int current;
  int end;
  int step;

  uint front()
  {
     return current;
  }

  void popFront()
  {
    current += step;
    return ;
  }

  bool empty()
  {
    return current > end;
  }

  this(uint end, uint begin = 0, uint step = 1) pure
  {
    assert(step != 0, "cannot have a step of 0");
    this.step = step;
    this.current = begin;
    this.end = end;
  }
}

auto Iota(int end)
{
  return iota_range(end);
}

uint testThisCall(uint end)
{
  uint result;

  foreach(n;Iota(end))
  {
    result += n;
  }

  return result;
}


pragma(msg, testThisCall(144_000));
