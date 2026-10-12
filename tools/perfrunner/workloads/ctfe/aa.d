// CTFE workload: associative array inserts, lookups and iteration.
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
        byString["k" ~ "x"] = "v";
    return sum + byInt.length + byString.length;
}

version (Baseline) {} else
enum result = run(2_500);
