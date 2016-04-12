// REQUIRED_ARGS: -O
// https://issues.dlang.org/show_bug.cgi?id=15861

import std.format;

void main()
{
    assert(format("%.18g", 4286853117.0) == "4286853117");
}

