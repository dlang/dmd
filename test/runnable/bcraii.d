/* REQUIRED_ARGS: -betterC
 * PERMUTE_ARGS:
 */

import core.stdc.stdio;

extern (C) int main()
{
    auto j = test(1);
    assert(j == 3);
    return 0;
}

int test(int i) nothrow
{
  {
    int j = i ? S(3).i : 3;
    printf("inside\n");
    assert(Sctor == 1);
    assert(Sdtor == 1);
    return j;
  }
  printf("done\n");
  return -1;
}

__gshared int Sctor;
__gshared int Sdtor;

struct S
{
    int i;
    this(int i) nothrow
    {
        this.i += i;
        printf("S.this()\n");
        ++Sctor;
    }

    ~this() nothrow
    {
        assert(i == 3);
        i = 0;
        printf("S.~this()\n");
        ++Sdtor;
    }
}
