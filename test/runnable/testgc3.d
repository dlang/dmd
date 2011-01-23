// PERMUTE_ARGS:
// REQUIRED_ARGS: -d

import std.c.stdio;
import std.random;

void main()
{
    rand_seed(1, 2);
    uint[uint][] aa;
    aa.length = 10000;
    for(int i = 0; i < 10_000_000; i++)
    {
	size_t j = rand() % aa.length;
	uint k = rand();
	uint l = rand();
	aa[j][k] = l;
    }
    printf("finished\n");
    aa[] = null;
}

