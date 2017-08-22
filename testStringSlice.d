string[] stringSlice1()
{
    return ["for", "the", "love", "of", "god"];
}

string[] stringSlice2()
{
    string[] v = stringSlice1();
    return v[0 .. $-1];
}

string stringSlice3()
{
    string[] v = stringSlice2();
    return v[$-2];
}

pragma(msg, stringSlice1());
pragma(msg, stringSlice3());
