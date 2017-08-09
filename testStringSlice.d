string slice(string s, uint lwr, uint upr)
{
    return s[lwr .. upr];
}

static assert(slice("Hello World", 6, 11) == "World");
