/**
 * Benchmark for array ops.
 *
 * Copyright: Copyright Martin Nowak 2016 -.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:    Martin Nowak
 */
import core.cpuid, std.algorithm, std.datetime, std.meta, std.stdio, std.string,
    std.range;

float[6] getLatencies(T, string op)()
{
    enum N = 256;
    auto a = new T[](N), b = new T[](N), c = new T[](N);
    a[] = 3;
    b[] = 2;
    c[] = 1;
    float[6] latencies = float.max;
    foreach (i, ref latency; latencies)
    {
        auto len = 1 << i;
        foreach (_; 1 .. 32)
        {
            auto sw = StopWatch(AutoStart.yes);
            foreach (off; 0 .. 1_024)
            {
                off &= 127;
                enum op = op.replace("const", "1").replace("a",
                        "a[off .. off + len]").replace("b",
                        "b[off .. off + len]").replace("c", "c[off .. off + len]");
                mixin(op ~ ";");
            }
            latency = min(latency, sw.peek.nsecs);
        }
    }
    float[6] res = latencies[] / 1024;
    return res;
}

float[4] getThroughput(T, string op)()
{
    enum N = (40 * 1024 * 1024 + 64) / T.sizeof;
    auto a = new T[](N), b = new T[](N), c = new T[](N);
    a[] = 3;
    b[] = 2;
    c[] = 1;
    float[4] latencies = float.max;
    size_t[4] lengths = [
        8 * 1024 / T.sizeof, 32 * 1024 / T.sizeof, 512 * 1024 / T.sizeof, 32 * 1024 * 1024 / T
        .sizeof
    ];
    foreach (i, ref latency; latencies)
    {
        auto len = lengths[i] / 64;
        foreach (_; 1 .. 4)
        {
            auto sw = StopWatch(AutoStart.yes);
            foreach (off; size_t(0) .. size_t(64))
            {
                off = off * len + (off % (64 / T.sizeof));
                enum op = op.replace("const", "1").replace("a",
                        "a[off .. off + len]").replace("b",
                        "b[off .. off + len]").replace("c", "c[off .. off + len]");
                mixin(op ~ ";");
            }
            latency = min(latency, sw.peek.nsecs);
        }
    }
    float[4] throughputs = T.sizeof * lengths[] / latencies[];
    return throughputs;
}

string[] genOps()
{
    string[] ops;
    foreach (op1; ["+", "-", "*", "/"])
    {
        ops ~= "a " ~ op1 ~ "= b";
        ops ~= "a " ~ op1 ~ "= const";
        foreach (op2; ["+", "-", "*", "/"])
        {
            ops ~= "a " ~ op1 ~ "= b " ~ op2 ~ " c";
            ops ~= "a " ~ op1 ~ "= b " ~ op2 ~ " const";
        }
    }
    return ops;
}

void runOp(string op)()
{
    foreach (T; AliasSeq!(ubyte, ushort, uint, ulong, byte, short, int, long, float,
            double))
        writefln("%s, %s, %(%.2f, %), %(%s, %)", T.stringof, op,
            getLatencies!(T, op), getThroughput!(T, op));
}

void main()
{
    writefln("type, op, %(latency%s, %), %-(throughput%s, %)", iota(6)
        .map!(i => 1 << i), ["8KB", "32KB", "512KB", "32MB"]);
    foreach (op; mixin("AliasSeq!(%(%s, %))".format(genOps)))
        runOp!op;
}
