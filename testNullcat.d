string scat(string a, string b)
{
    return a ~ b; 
}

int[] cat(int[] a, int[] b)
{
    return a ~ b;
}

static assert (cat(null, null) == null);
static assert (scat(null, null) is null);
pragma(msg, cat([1,2,3,4], [5,6,7,8]));
pragma(msg, cat(null, null));

