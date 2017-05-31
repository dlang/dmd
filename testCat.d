uint[] cat(uint[] a, uint[] b)
{
  return a ~ b;
}

pragma(msg, cat([1,2,3,10], [4,5,6]));
