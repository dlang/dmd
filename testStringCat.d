string cat(string s1, string s2)
{
    return s1 ~ s2;
}

string[3] cat3(string s1, string s2)
{
    return [s1 ~ s2, s1, s2];
}

static assert(cat("hello","world") == "helloworld");
static assert(cat(null, null) is null);
