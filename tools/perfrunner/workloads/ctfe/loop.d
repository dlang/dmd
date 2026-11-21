// CTFE workload: integer arithmetic and assignments in a tight loop.
long run(long n)
{
    long sum = 0;
    foreach (i; 0 .. n)
    {
        sum += (i * 31 + 7) % 13;
        sum ^= i;
    }
    return sum;
}

// The baseline evaluates a trivial input, so that both compiles do the same
// semantic analysis and differ only in the interpreting.
version (Baseline)
    enum result = run(1);
else
    enum result = run(200_000);
