// REQUIRED_ARGS: -g

// If this is failing, you need optlink 8.00.14 or higher

string repeatString(string s, uint repeatCount)
{
    char[] result;
    uint sLength = cast(uint) s.length;

    result.length = sLength * repeatCount;
    uint p1 = 0;
    uint p2 = sLength;

    foreach(rc;0 .. repeatCount)
    {
        result[p1 .. p2] = s[0 .. sLength];
        p1 += sLength;
        p2 += sLength;
    }

    return cast(string) result;
}

string gen()
{
   return repeatString("mixin(\"assert(0);\n\n\n\n\");\n", 4096);
}

void main()
{
    mixin(gen());
}
