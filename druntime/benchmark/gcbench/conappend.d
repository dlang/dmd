/**
 * The goal of this program is to do concurrent allocations in threads
 *
 * Copyright: Copyright Leandro Lucarella 2014.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Leandro Lucarella
 */
import core.thread;
import core.atomic;
import std.conv;
import std.file;
import std.exception;

__gshared int N = 10000;
__gshared int NT = 4;

__gshared ubyte[] BYTES;
shared(int) running; // Atomic

void main(string[] args)
{
    auto fname = "extra-files/dante.txt";
    if (args.length > 3)
        fname = args[3];
    if (args.length > 2)
        NT = to!(int)(args[2]);
    if (args.length > 1)
        N = to!(int)(args[1]);
    N /= NT;

    atomicStore(running, NT);
    BYTES = cast(ubyte[]) std.file.read(fname);
    auto threads = new Thread[NT];
    foreach(ref thread; threads)
    {
        thread = new Thread(&doAppend);
        thread.start();
    }
    while (atomicLoad(running))
    {
        auto a = new ubyte[](BYTES.length);
        a[] = cast(ubyte[]) BYTES[];
        Thread.yield();
    }
    foreach(thread; threads)
        thread.join();
}

void doAppend()
{
    for (size_t i = 0; i < N; i++)
    {
        int[] arr;
        for (int j = 0; j < 1000; j++)
            arr ~= j;

        int sum = 0;
        foreach (a; arr)
            sum += a;
        enforce(sum == 1000 * 999 / 2, "bad sum");
    }
    import core.atomic : atomicOp;
    atomicOp!"-="(running, 1);
}
