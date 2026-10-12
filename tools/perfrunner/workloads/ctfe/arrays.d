// CTFE workload: array appends, slices and indexing.
long run(int n)
{
    int[] a;
    foreach (i; 0 .. n)
        a ~= i;

    long sum;
    foreach (i; 0 .. n / 4)
    {
        auto slice = a[i .. i + n / 2];
        sum += slice[0] + slice[$ - 1] + slice.length;
    }
    return sum;
}

// The baseline evaluates a trivial input, so that both compiles do the same
// semantic analysis and differ only in the interpreting.
version (Baseline)
    enum result = run(1);
else
    enum result = run(8_000);
