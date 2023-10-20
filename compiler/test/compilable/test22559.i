// https://gcc.gnu.org/onlinedocs/gcc/Case-Ranges.html

int alpha(char c)
{
    switch (c)
    {
	case 'A' ... 'Z': return 1;
	case 'a' ... 'z': return 1;
	default:          return 0;
    }
}

_Static_assert(alpha('A') == 1, "1");
_Static_assert(alpha('B') == 1, "2");
_Static_assert(alpha('z') == 1, "3");
_Static_assert(alpha('z' + 1) == 0, "3");
_Static_assert(alpha('0') == 0, "4");
