module enum_union_header_roundtrip_consumer;

import enum_union_header_roundtrip;

// 1. Tag access assertions
ubyte testTag(ref Message message)
{
    static assert(!__traits(compiles, message.__tag = 0));
    return message.__tag;
}

// 2. Case UDA and template function call
static assert(__traits(getAttributes, HardenedValue.None)[0].name == "none");
static assert(__traits(getAttributes, HardenedValue.Some)[0].name == "some");
static assert(inspect!void(HardenedValue.Some(7)) == 7);

// 3. Tuple pattern call
int useTuple(TupleValue value)
{
    return inspectTuple!void(value);
}
