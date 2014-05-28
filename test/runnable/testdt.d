// PERMUTE_ARGS:

/******************************************/

static int bigarray[100][100];

void test1()
{
  for (int i = 0; i < 100; i += 1)
  {
    for (int j = 0; j < 100; j += 1)
    {
      //printf("Array %i %i\n", i, j);
      bigarray[i][j] = 0;
    }
  }
}

/******************************************/
// 11233

struct S11233
{
    uint[0x100000] arr;
}

/******************************************/
// 11672

void test11672()
{
    struct V { float f; }
    struct S
    {
        V[3] v = V(1);
    }

    S s;
    assert(s.v == [V(1), V(1), V(1)]); /* was [V(1), V(nan), V(nan)] */
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

int main()
{
    test1();
    test11672();

    return 0;
}
