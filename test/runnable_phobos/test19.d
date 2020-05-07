// REQUIRED_ARGS: -unittest

extern(C) int printf(const char*, ...);

/* ================================ */

import std.algorithm: cmp;

char[] tolower13(ref char[] s)
{
    int i;

    for (i = 0; i < s.length; i++)
    {
        char c = s[i];
        if ('A' <= c && c <= 'Z')
            s[i] = cast(char)(c + (cast(char)'a' - 'A'));
    }
    return s;
}

void test13()
{
    char[] s1 = "FoL".dup;
    char[] s2;

    s1 = s1.dup;
    s2 = tolower13(s1);
    assert(cmp(s2, "fol") == 0);
    assert(s2 == s1);
}

/* ================================ */


int main()
{
    test13();
    printf("Success\n");
    return 0;
}
