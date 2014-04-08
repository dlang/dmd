// PERMUTE_ARGS:

/******************************************/
// 11233

struct S11233
{
    uint[0x100000] arr;
}

/******************************************/
// 12509

struct A12509
{
    int member;
}
struct B12509
{
    A12509[0x10000] array;
}

/******************************************/

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
