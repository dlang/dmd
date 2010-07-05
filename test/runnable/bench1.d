// REQUIRED_ARGS: -d
// EXECUTE_ARGS: 10000

import std.c.stdio;
import std.string;

    int main (string[] argv)
    {
        string s = "";
        int count, loop;

        count = atoi (argv [1]);
        if (count == 0)
            count = 1;

        for (loop = 0; loop < count; loop ++)
            s ~= "hello\n";
        for (loop = 0; loop < count; loop ++)
            s ~= "h";
        printf ("%d\n", s.length);
	//printf("%.*s\n", s[0..100]);
	assert(s.length == count * (6 + 1));
	s.length = 3;
	s.length = 10;
	s.length = 0;
	s.length = 1000;
        return 0;
    }

