module serializer.basic_types;

import dmd.root.serializer : serialize;

@("bool, true")
unittest
{
    const result = serialize(true);
    assert(result == "--- true", result);
}

@("bool, false")
unittest
{
    const result = serialize(false);
    assert(result == "--- false", result);
}

@("char")
unittest
{
    const result = serialize('a');
    assert(result == "--- a", result);
}

@("wchar")
unittest
{
    const result = serialize('ö');
    assert(result == "--- ö", result);
}

@("dchar")
unittest
{
    const result = serialize('🍺');
    assert(result == "--- 🍺", result);
}

@("byte")
unittest
{
    const byte value = 3;
    const result = serialize(value);

    assert(result == "--- 3", result);
}

@("ubyte")
unittest
{
    const ubyte value = 3;
    const result = serialize(value);

    assert(result == "--- 3", result);
}

@("short")
unittest
{
    const short value = 3;
    const result = serialize(value);

    assert(result == "--- 3", result);
}

@("short")
unittest
{
    const ushort value = 3;
    const result = serialize(value);

    assert(result == "--- 3", result);
}

@("int")
unittest
{
    const result = serialize(3);
    assert(result == "--- 3", result);
}

@("uint")
unittest
{
    const result = serialize(3u);
    assert(result == "--- 3", result);
}

@("long")
unittest
{
    const result = serialize(10_000_000_000);
    assert(result == "--- 10000000000", result);
}

@("ulong")
unittest
{
    const result = serialize(10_000_000_000u);
    assert(result == "--- 10000000000", result);
}

@("double")
unittest
{
    const result = serialize(3.1);
    assert(result == "--- 3.1", result);
}

@("float")
unittest
{
    const result = serialize(3.1f);
    assert(result == "--- 3.1", result);
}

@("real")
unittest
{
    const result = serialize(3.1L);
    assert(result == "--- 3.1", result);
}
