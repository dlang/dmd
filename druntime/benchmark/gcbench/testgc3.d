/**
 * taken from the dmd test suite, added options to run multiple times
 *
 * This test creates 10000 associative arrays uint[uint] multiple times
 * collecting arrays created in previous iterations.
 * A 32-bit process can be sensitive to false pointers as hash values
 * in the AAs can reference arbitrary addresses.
 */
import std.conv;
import std.exception;

int main(string[] args)
{
    int cnt = 4;
    int num = 200;
    if (args.length > 1)
        cnt = to!int(args[1]);
    if (args.length > 2)
        num = to!int(args[2]);
    ulong sum;
    for(int n = 0; n < cnt; n++)
    {
        uint[uint][] aa;
        aa.length = 10000;
        int aacnt = num * 10000;
        for(int i = 0; i < aacnt; i++)
        {
            size_t j = i % aa.length;
            uint k = i;
            uint l = i;
            aa[j][k] = l;
        }
        sum = 0;
        foreach(s; aa[4711])
            sum += s;
        enforce(sum == 4711 * num + 10000 * num * (num - 1) / 2);
        aa[] = null;
    }
    return 0;
}
