// REQUIRED_ARGS:

// Test array bounds checking

import core.exception;
extern(C) int printf(const char*, ...);

/******************************************/

const int foos[10] = [1,2,3,4,5,6,7,8,9,10];
const int food[]   = [21,22,23,24,25,26,27,28,29,30];
const int *foop    = cast(int*) foos;

static int x = 2;

int index()
{
    return x++;
}

int tests(int i)
{
    return foos[index()];
}

int testd(int i)
{
    return food[index()];
}

int testp(int i)
{
    return foop[i];
}

const(int)[] slices(int lwr, int upr)
{
    return foos[lwr .. upr];
}

const(int)[] sliced(int lwr, int upr)
{
    return food[lwr .. upr];
}

const(int)[] slicep(int lwr, int upr)
{
    return foop[lwr .. upr];
}

void test1()
{
    int i;

    i = tests(0);
    assert(i == 3);

    i = testd(0);
    assert(i == 24);

    i = testp(1);
    assert(i == 2);

    x = 10;
    try
    {
        i = tests(0);
    }
    catch (RangeError a)
    {
        i = 73;
    }
    assert(i == 73);

    x = -1;
    try
    {
        i = testd(0);
    }
    catch (RangeError a)
    {
        i = 37;
    }
    assert(i == 37);

    const(int)[] r;

    r = slices(3,5);
    assert(r[0] == foos[3]);
    assert(r[1] == foos[4]);

    r = sliced(3,5);
    assert(r[0] == food[3]);
    assert(r[1] == food[4]);

    r = slicep(3,5);
    assert(r[0] == foos[3]);
    assert(r[1] == foos[4]);

    try
    {
        i = 7;
        r = slices(5,3);
    }
    catch (RangeError a)
    {
        i = 53;
    }
    assert(i == 53);

    try
    {
        i = 7;
        r = slices(5,11);
    }
    catch (RangeError a)
    {
        i = 53;
    }
    assert(i == 53);

    try
    {
        i = 7;
        r = sliced(5,11);
    }
    catch (RangeError a)
    {
        i = 53;
    }
    assert(i == 53);

    try
    {
        i = 7;
        r = slicep(5,3);
    }
    catch (RangeError a)
    {
        i = 53;
    }
    assert(i == 53);

    // Take side effects into account
    x = 1;
    r = foos[index() .. 3];
    assert(x == 2);
    assert(r[0] == foos[1]);
    assert(r[1] == foos[2]);

    r = foos[1 .. index()];
    assert(r.length == 1);
    assert(x == 3);
    assert(r[0] == foos[1]);

    x = 1;
    r = food[index() .. 3];
    assert(x == 2);
    assert(r[0] == food[1]);
    assert(r[1] == food[2]);

    r = food[1 .. index()];
    assert(r.length == 1);
    assert(x == 3);
    assert(r[0] == food[1]);

    x = 1;
    r = foop[index() .. 3];
    assert(x == 2);
    assert(r[0] == foop[1]);
    assert(r[1] == foop[2]);

    r = foop[1 .. index()];
    assert(r.length == 1);
    assert(x == 3);
    assert(r[0] == foop[1]);
}

/******************************************/
// 13976

void test13976()
{
    int[] da = new int[](10);
    int[10] sa;
    size_t l = 0;               // upperInRange
    size_t u = 9;               // | lowerLessThan
                                // | |  check code
    { auto s = da[l .. u];   }  // 0 0  (u <= 10 && l <= u  )
    { auto s = da[1 .. u];   }  // 0 0  (u <= 10 && l <= u  )
    { auto s = da[l .. 10];  }  // 0 0  (u <= 10 && l <= u  )
    { auto s = da[1 .. u%5]; }  // 0 0  (u <= 10 && l <= u%5)

    { auto s = da[l .. u];   }  // 0 0  (u   <= 10 && l <= u)
    { auto s = da[0 .. u];   }  // 0 1  (u   <= 10          )
    { auto s = da[l .. 10];  }  // 0 0  (u   <= 10 && l <= u)
    { auto s = da[0 .. u%5]; }  // 0 1  (u%5 <= 10          )

    { auto s = sa[l .. u];   }  // 0 0  (u <= 10 && l <= u  )
    { auto s = sa[1 .. u];   }  // 0 0  (u <= 10 && l <= u  )
    { auto s = sa[l .. 10];  }  // 1 0  (           l <= u  )
    { auto s = sa[1 .. u%5]; }  // 1 0  (           l <= u%5)

    { auto s = sa[l .. u];   }  // 0 0  (u <= 10 && l <= u )
    { auto s = sa[0 .. u];   }  // 0 1  (u <= 10           )
    { auto s = sa[l .. 10];  }  // 1 0  (           l <= 10)
    { auto s = sa[0 .. u%5]; }  // 1 1  NULL

    int* p = new int[](10).ptr;
    { auto s = p[0 .. u];    }  // 1 1  NULL
    { auto s = p[l .. u];    }  // 1 0  (l <= u)
    { auto s = p[0 .. u%5];  }  // 1 1  NULL
    { auto s = p[1 .. u%5];  }  // 1 0  (l <= u%5)
}

/******************************************/

int main()
{
    test1();
    test13976();

    printf("Success\n");
    return 0;
}
