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

version (Baseline) {} else
enum result = run(200_000);
