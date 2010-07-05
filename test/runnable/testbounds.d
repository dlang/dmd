// PERMUTE_ARGS:

// Test array bounds checking

import core.exception;

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

int main()
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


    return 0;
}
