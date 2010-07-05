// 1537

void foo(char[] s)
{
    int x = -1;

    while (s.length)
    {
        char c = s[0];

        if (c == '}')
           break;

        assert (c >= '0' && c <= '9', s[0..$]);

        if (x == -1)
            x = 0;
    }
}

