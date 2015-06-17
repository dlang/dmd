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
// 10629

class Foo10629 {}

struct Bar10629
{
    void[__traits(classInstanceSize, Foo10629)] x;
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
// 13505

class C13505 { void[10] x; }
struct S13505 { void[10] x; }

void test13505()
{
    auto c = new C13505();
    auto s = S13505();
}

/******************************************/
// 14699

struct S14699a { ubyte[0][10] values; }
struct S14699b { S14699a tbl; }     
// +/

ubyte[0][1] sa14699;

void test14699()
{
    //auto p = &sa14699;  // Cannot work in Win32 (OMF)
}

/******************************************/

int main()
{
    test1();
    test11672();

    return 0;
}
