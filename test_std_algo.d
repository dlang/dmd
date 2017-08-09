/*struct FilterRange(alias fn, uint[] arr)
{
  bool haveValue;
  uint lastValue;

  auto front()
  {
    if (haveValue)
      return lastValue;
    else 
    {
      popFront();
      
    }
  }
  
  void popFornt()
  {
  }

  bool empty()
  {
  }
}
*/

auto arrayRange(uint[] arr)
{
  struct ArrayRange {
     uint[] arr;
     uint idx;

     uint front() { return getArray()[idx]; }
     void popFront() { idx++; }
     bool empty() { return idx == getArray().length; }
     uint[] getArray() { return arr; }      
   }

  return ArrayRange(arr);
}

uint[] testMap(uint[] arr)
{
  uint[] result;
  result.length = arr.length;

  import std.algorithm : map;
  auto mapRange = arr.arrayRange.map!(a => (a * 3));

  uint idx;
  foreach(e;mapRange)
  {
    result[idx++] = e;
  }

  return result;   
}
static immutable testMapResult = testMap([4,9,12,6]);

//static assert(testMapResult == [4*3, 9*3, 12*3, 6*3]);
