// CTFE workload: building strings by appending and concatenating.
size_t run(int n)
{
    string s;
    foreach (i; 0 .. n)
    {
        s ~= "ab";
        s = s ~ "c";
    }

    string t;
    foreach (i; 0 .. n)
        t ~= s[i .. i + 3];
    return s.length + t.length;
}

version (Baseline) {} else
enum result = run(10_000);
