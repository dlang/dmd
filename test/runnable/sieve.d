// PERMUTE_ARGS:
// REQUIRED_ARGS: -cov
// POST_SCRIPT: runnable/extra-files/sieve-postscript.sh
// EXECUTE_ARGS: ${RESULTS_DIR}/runnable

/* Eratosthenes Sieve prime number calculation. */

import std.stdio;

bool[8191] flags;

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

int main(string[] args)
{

    dmd_coverDestPath(args[1]);

    sieve();

    return 0;
}
