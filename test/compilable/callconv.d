// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
compilable/callconv.d(21): Deprecation: `extern(Pascal)` is deprecated. You might want to use `extern(Windows)` instead.
compilable/callconv.d(30): Deprecation: `extern(Pascal)` is deprecated. You might want to use `extern(Windows)` instead.
---
*/

import core.stdc.stdarg;

struct ABC
{
	int[4] x;
}

ABC abc;

int x,y,z;

extern (Pascal):
ABC test1(int xx, int yy, int zz)
{
    x = xx;
    y = yy;
    z = zz;
    return abc;
}

extern (Pascal):
ABC test1v(int xx, int yy, int zz, ...)
{
    x = xx;
    y = yy;
    z = zz;
    return abc;
}

extern (C):
ABC test2v(int xx, int yy, int zz, ...)
{
    x = xx;
    y = yy;
    z = zz;
    return abc;
}

extern (C++):
ABC test3(int xx, int yy, int zz)
{
    x = xx;
    y = yy;
    z = zz;
    return abc;
}

ABC test3v(int xx, int yy, int zz, ...)
{
    x = xx;
    y = yy;
    z = zz;
    return abc;
}

extern (D):
ABC test4(int xx, int yy, int zz)
{
    x = xx;
    y = yy;
    z = zz;
    return abc;
}

ABC test4v(int xx, int yy, int zz, ...)
{
    x = xx;
    y = yy;
    z = zz;
    return abc;
}


