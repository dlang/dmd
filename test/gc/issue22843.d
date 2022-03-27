void main()
{
    string[string] aa;
    string key = "a";

    foreach (i; 0..100)
    {
        aa[key] = key;
        key ~= "a";
    }
}
