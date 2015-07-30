import link14834a;

void main()
{
    foreach (n; dirEntries("."))
    {
        assert(n == 10);
    }
}
