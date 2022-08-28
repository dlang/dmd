/*
PERMUTE_ARGS:
REQUIRED_ARGS: -cov
POST_SCRIPT: runnable/extra-files/coverage-postscript.sh
EXECUTE_ARGS: ${RESULTS_DIR}/runnable
RUN_OUTPUT:
---
10 iterations
1899 primes
---
*/

/* Eratosthenes Sieve prime number calculation. */

import core.stdc.stdio;

bool[8191] flags;

int sieve()
{
    int count;

    printf("10 iterations\n");
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
    printf("%d primes\n", count);
    return 0;
}

extern(C) void dmd_coverDestPath(string path);

int main(string[] args)
{

    dmd_coverDestPath(args[1]);

    sieve();

    return 0;
}
