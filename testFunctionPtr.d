int[] filterBy(int[] arr , bool function(uint) fn)
{
    int[] result = [];
    uint resultLength;

    result.length = arr.length;
    foreach(i;0 .. arr.length)
    {
        auto e = arr[i];
        bool r = true;
        r = fn(e);
        if(r)
        {
            result[resultLength++] = e; 
        }
    }
    
   int[] filterResult;
   filterResult.length = resultLength;
   
   foreach(i; 0 .. resultLength)
   {
     filterResult[i] = result[i];
   }

  return filterResult;
}

bool isDiv2(uint e)
{
  bool result_;
  result_ = (e % 2 == 0);
  return result_;
}

bool isNotDiv2(uint e)
{
  bool result_;
  result_ = (e % 2 != 0);
  return result_;
}

int[] run(int[] arr, bool div2)
{
  return filterBy(arr, div2 ? &isDiv2 : &isNotDiv2);
}


static assert(run([3,4,5], true) == [4]);
static assert(run([3,4,5], false) == [3,5]);

static assert(filterBy([3,4,5], &isDiv2) == [4]);
