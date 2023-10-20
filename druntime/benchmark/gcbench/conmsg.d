/**
 * This benchmarks GC in a producer-consumer program.
 *
 * Copyright: Copyright Martin Nowak 2014 -.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Martin Nowak
 */
import std.algorithm, std.concurrency, std.conv, std.file, std.json, std.range;

JSONValue buildVal(in dchar[] word) pure
{
    JSONValue[string] res;
    res["word"] = word.to!string;
    res["length"] = word.length;
    auto pos = new size_t[word.length];
    foreach (i; 0 .. pos.length)
        pos[i] = i;
    res["array"] = pos;
    return JSONValue(res);
}

void producer(Tid consumer)
{
    auto text = cast(string)read("extra-files/dante.txt");
    foreach (word; text.splitter.map!(to!(dchar[])))
    {
        foreach (_; 0 .. 7)
        {
            immutable val = buildVal(word);
            consumer.send(val);
            if (!nextPermutation(word)) break;
        }
    }
}

void serialize(in JSONValue val, ref ubyte[] buf)
{
    with (JSONType) switch (val.type)
    {
    case object:
        foreach (k, v; val.object)
        {
            buf ~= cast(ubyte[])k;
            serialize(v, buf);
        }
        break;

    case array:
        foreach (v; val.array)
            serialize(v, buf);
        break;

    case uinteger:
        ulong v = val.uinteger;
        buf ~= (cast(ubyte*)&v)[0 .. v.sizeof];
        break;

    case string:
        buf ~= cast(ubyte[])val.str;
        break;

    default:
        assert(0);
    }
}

struct Socket
{
    static void send(ubyte[] buf) { _buf = buf; }
    static ubyte[] _buf; // keep a reference
}

void log(string s)
{
    __gshared size_t dummy;
    dummy = s.length;
}

void consumer()
{
    scope (failure) assert(0);
    while (true)
    {
        auto msg = receiveOnly!(Variant);
        if (msg.peek!OwnerTerminated) return;
        auto val = msg.get!(immutable JSONValue);
        ubyte[] buf; serialize(val, buf);
        Socket.send(buf);
    }
}

void main(string[] args)
{
    producer(spawn(&consumer));
}
