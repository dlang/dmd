uint[] fold (int[4][3] a)
{
  uint[]result;
  result.length = 4 * 3;
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

static assert (fold ([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]]) ==
	       [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);


int[2][3]
split(int[6] a)
{
    int[2][3] result; 
    int p;

    result[0][0] = 0;

    foreach(j;0 .. 3)
        foreach(i;0 .. 2)
    {
//        result[j][i] = a[p++]; 
    }

    return result;
}

static assert ( split([1, 2, 3, 4, 5, 6]) == [[1, 2], [3, 4], [5, 6]] );
