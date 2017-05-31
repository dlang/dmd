uint sum(string s)
{
    uint sum;
    foreach(i, char c; s)
    {
        sum += c;
    }
    return sum;
}

static assert(sum("newCTFE") == 620);
