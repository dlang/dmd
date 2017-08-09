uint sum(uint[] arr)
{
  uint sum;
  foreach(uint i;0 .. cast(uint)arr.length)
  {
    addToSum(sum, arr[i]);
  }

  return sum;
}


void addToSum(ref uint sum, uint element)
{
    sum += element; // works
    // sum = sum + element; // does not work (because a temporary value has to be created for sum)
    return ;
}


static assert([1,2,3,4,5].sum == 15);
