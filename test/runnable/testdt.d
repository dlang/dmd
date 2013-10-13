// PERMUTE_ARGS:

struct S { uint[0x100000] arr; }    // Bugzilla 11233

static int bigarray[100][100];

int main(char[][] args)
{
  for (int i = 0; i < 100; i += 1)
  {
    for (int j = 0; j < 100; j += 1)
    {
      //printf("Array %i %i\n", i, j);
      bigarray[i][j] = 0;
    }
  }
  return 0;
}
