// PERMUTE_ARGS:
// REQUIRED_ARGS: -d

import std.c.stdio;
import std.random;

auto rand()
{
    auto value = rndGen().front;
    rndGen.popFront();
    return value;
}

void main()
{
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

