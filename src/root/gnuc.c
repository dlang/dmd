
// Put functions in here missing from gnu C

#include "gnuc.h"

int memicmp(const char *s1, const char *s2, int n)
{
    int result = 0;

    for (int i = 0; i < n; i++)
    {   char c1 = s1[i];
        char c2 = s2[i];

        result = c1 - c2;
        if (result)
        {
            if ('A' <= c1 && c1 <= 'Z')
                c1 += 'a' - 'A';
            if ('A' <= c2 && c2 <= 'Z')
                c2 += 'a' - 'A';
            result = c1 - c2;
            if (result)
                break;
        }
    }
    return result;
}

int stricmp(const char *s1, const char *s2)
{
    int result = 0;

    for (;;)
    {   char c1 = *s1;
        char c2 = *s2;

        result = c1 - c2;
        if (result)
        {
            if ('A' <= c1 && c1 <= 'Z')
                c1 += 'a' - 'A';
            if ('A' <= c2 && c2 <= 'Z')
                c2 += 'a' - 'A';
            result = c1 - c2;
            if (result)
                break;
        }
        if (!c1)
            break;
        s1++;
        s2++;
    }
    return result;
}

