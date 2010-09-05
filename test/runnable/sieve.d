// PERMUTE_ARGS:
// REQUIRED_ARGS: -cov
// POST_SCRIPT: runnable/extra-files/sieve-postscript.sh

/* Eratosthenes Sieve prime number calculation. */

import std.stdio;
 
bool flags[8191];
 
int sieve()
{
    int count;

    writefln("10 iterations");
    for (int iter = 1; iter <= 10; iter++)
    {
        count = 0;
	flags[] = true;
	for (int i = 0; i < flags.length; i++)
	{
            if (flags[i])
	    {
                int prime = i + i + 3;
		int k = i + prime;
		while (k < flags.length)
		{
		    flags[k] = false;
		    k += prime;
		}
		count += 1;
	    }
	}
    }
    writefln("%d primes", count);
    return 0;
}

extern(C) void dmd_coverDestPath(string path);

int main()
{

    dmd_coverDestPath("test_results/runnable/");

    sieve();

    return 0;
}
