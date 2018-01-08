int[12] fold (int[4][3] a)
{
  int[12] result;

  uint pos;
  foreach (i; 0 .. 3)
  {
    foreach (j; 0 .. 4)
    {
      result[pos++] = a[i][j];
    }
  }
  return result;
}
static assert (fold([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]])
==	       [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);


int[2][3]
split(int[6] a)
{
    int[2][3] result; 
    int p;

    result[0][0] = 0;

    foreach(j;0 .. 3)
        foreach(i;0 .. 2)
    {
        result[j][i] = a[p++]; 
    }

    return result;
}

int[2][3] echo(int[2][3] a) { return a; }


//static assert ( split([1, 2, 3, 4, 5, 6]) == [[1, 2], [3, 4], [5, 6]] );
pragma(msg, split([1,2,3,4,5,6]));
//pragma(msg, echo([[1,1],[2,2],[3,3]]) );
