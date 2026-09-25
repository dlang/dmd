module enum_union_tag_header_roundtrip_consumer;

import enum_union_tag_header_roundtrip;

ubyte tag(ref Message message)
{
    static assert(!__traits(compiles, message.__tag = 0));
    return message.__tag;
}