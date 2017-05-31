uint[] expand(ref uint[] arr, uint expandBy)
{
  uint newLen = (cast(uint)arr.length) + expandBy;
  arr.length = newLen;
  return arr;
}

uint[] checkExpand()
{
    uint[] a = [1,2,3];
    a.length = 6;
    assert(a.length == 6);
    return a;
}
static immutable checkExpandArray = checkExpand();
static assert(checkExpandArray == [1,2,3,0,0,0]);



