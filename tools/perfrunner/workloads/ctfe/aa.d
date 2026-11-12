// CTFE workload: associative array inserts, lookups and iteration.
// A distinct string key for each `i`
string key(int i)
{
    string s = "k";
    do
    {
        s ~= cast(char) ('0' + i % 10);
        i /= 10;
    } while (i);
    return s;
}

long run(int n)
{
    long[long] byInt;
    foreach (i; 0 .. n)
        byInt[i * 7] = i;

    long sum;
    foreach (i; 0 .. n)
        if (auto p = (i * 7) in byInt)
            sum += *p;
    foreach (k, v; byInt)
        sum += k ^ v;

    string[string] byString;
    foreach (i; 0 .. n / 10)
        byString[key(i)] = "v";
    foreach (i; 0 .. n / 10)
        if (auto p = key(i) in byString)
            sum += p.length;
    return sum + byInt.length + byString.length;
}

// The baseline evaluates a trivial input, so that both compiles do the same
// semantic analysis and differ only in the interpreting.
version (Baseline)
    enum result = run(1);
else
    enum result = run(2_500);
