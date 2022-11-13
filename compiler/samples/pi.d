import std.stdio;
import std.conv;
import core.stdc.stdlib;
import core.stdc.time;

const int LONG_TIME = 4000;

byte[] p;
byte[] t;
int q;

int main(string[] args)
{
    time_t startime, endtime;
    int i;

    if (args.length == 2)
    {
        q = to!int(args[1]);
    }
    else
    {
        writeln("Usage: pi [precision]");
        exit(55);
    }

    if (q < 0)
    {
        writeln("Precision was too low, running with precision of 0.");
        q = 0;
    }

    if (q > LONG_TIME)
    {
        writeln("Be prepared to wait a while...");
    }

    // Compute one more digit than we display to compensate for rounding
    q++;

    p.length = q + 1;
    t.length = q + 1;

    /* compute pi */
    core.stdc.time.time(&startime);
    arctan(2);
    arctan(3);
    mul4();
    core.stdc.time.time(&endtime);

    // Return to the number of digits we want to display
    q--;

    /* print pi */

    writef("pi = %d.", cast(int) (p[0]));

    for (i = 1; i <= q; i++)
        writef("%d", cast(int) (p[i]));

    writeln();
    writefln("%s seconds to compute pi with a precision of %s digits.", endtime - startime, q);

    return 0;
}

void arctan(int s)
{
    int n;

    t[0] = 1;
    div(s);     /* t[] = 1/s */
    add();
    n = 1;

    do
    {
        mul(n);
        div(s * s);
        div(n += 2);

        if (((n - 1) / 2) % 2 == 0)
            add();
        else
            sub();
    } while (!tiszero());
}

void add()
{
    int j;

    for (j = q; j >= 0; j--)
    {
        if (t[j] + p[j] > 9)
        {
            p[j]     += t[j] - 10;
            p[j - 1] += 1;
        }
        else
            p[j] += t[j];
    }
}

void sub()
{
    int j;

    for (j = q; j >= 0; j--)
    {
        if (p[j] < t[j])
        {
            p[j]     -= t[j] - 10;
            p[j - 1] -= 1;
        }
        else
            p[j] -= t[j];
    }

}

void mul(int multiplier)
{
    int b;
    int i;
    int carry = 0, digit = 0;

    for (i = q; i >= 0; i--)
    {
        b     = (t[i] * multiplier + carry);
        digit = b % 10;
        carry = b / 10;
        t[i]  = cast(byte) digit;
    }
}

/* t[] /= l */
void div(int divisor)
{
    int i, b;
    int quotient, remainder = 0;

    foreach (ref x; t)
    {
        b         = (10 * remainder + x);
        quotient  = b / divisor;
        remainder = b % divisor;
        x         = cast(byte) quotient;
    }
}

void div4()
{
    int i, c, d = 0;

    for (i = 0; i <= q; i++)
    {
        c    = (10 * d + p[i]) / 4;
        d    = (10 * d + p[i]) % 4;
        p[i] = cast(byte) c;
    }
}

void mul4()
{
    int i, c, d;

    d = c = 0;

    for (i = q; i >= 0; i--)
    {
        d    = (p[i] * 4 + c) % 10;
        c    = (p[i] * 4 + c) / 10;
        p[i] = cast(byte) d;
    }
}

int tiszero()
{
    int k;

    for (k = 0; k <= q; k++)
        if (t[k] != 0)
            return false;

    return true;
}
