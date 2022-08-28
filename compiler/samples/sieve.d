/* Eratosthenes Sieve prime number calculation. */

import std.conv;
import std.stdio;
import std.range;

void main(string[] args)
{
    immutable max = (1 < args.length)
        ? args[1].to!size_t
        : 0x4000;
    size_t count = 1; // we have 2.
    // flags[i] = isPrime(2 * i + 3)
    auto flags = new bool[(max - 1) / 2];
    flags[] = true;

    foreach (i; 0..flags.length)
    {
        if (!flags[i])
            continue;
        auto prime = i + i + 3;
        foreach (k; iota(i + prime, flags.length, prime))
            flags[k] = false;

        count++;
    }
    writefln("%d primes", count);
}
