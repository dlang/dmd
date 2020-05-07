// PERMUTE_ARGS: -fPIC

/* Test associative arrays */

extern(C) int printf(const char*, ...);

import core.memory;  // for GC.collect
import std.random;   // for uniform random numbers

/************************************************/

void test16()
{
    int[int] aa;

    Random gen;
    for (int i = 0; i < 50000; i++)
    {
        int key = uniform(0, int.max, gen);
        int value = uniform(0, int.max, gen);

        aa[key] = value;
    }

    int[] keys = aa.keys;
    assert(keys.length == aa.length);

    int j;
    foreach (k; keys)
    {
        assert(k in aa);
        j += aa[k];
    }
    printf("test16 = %d\n", j);

    int m;
    foreach (k, v; aa)
    {
        assert(k in aa);
        assert(aa[k] == v);
        m += v;
    }
    assert(j == m);

    m = 0;
    foreach (v; aa)
    {
        m += v;
    }
    assert(j == m);

    int[] values = aa.values;
    assert(values.length == aa.length);

    foreach(k; keys)
    {
        aa.remove(k);
    }
    assert(aa.length == 0);

    for (int i = 0; i < 1000; i++)
    {
        int key2 = uniform(0, int.max, gen);
        int value2 = uniform(0, int.max, gen);

        aa[key2] = value2;
    }
    foreach(k; aa)
    {
        if (k < 1000)
            break;
    }
    foreach(k, v; aa)
    {
        if (k < 1000)
            break;
    }
}

/************************************************/

int main()
{
    printf("before test 16\n");   test16();

    printf("Success\n");
    return 0;
}
