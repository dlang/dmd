
/* Eratosthenes Sieve prime number calculation. */

import std.stdio;


int main()
{
    writefln("10 iterations");

    foreach (iter; 0..10)
    {
        size_t count;
        auto flags = new bool[8191];
        flags[] = true;

        foreach (i; 0..flags.length)
        {
            if (flags[i])
            {
                auto prime = i + i + 3;
                auto k     = i + prime;

                while (k < flags.length)
                {
                    flags[k] = false;
                    k       += prime;
                }

                count += 1;
            }
        }
        writefln("%d primes", count);
    }

    return 0;
}
