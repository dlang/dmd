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

uint testThisCall(uint end)
{
  uint result;

  foreach(n;iota_range(end))
  {
    result += n;
  }

  return result;
}


uint[] initArray(uint end)
{
    uint[] arr;
    arr.length = end;
    auto range = iota_range(end - 1);
    foreach(n;range)
      arr[n] = n + 1;

     return arr;
}

pragma(msg, testThisCall(100_000_0));
