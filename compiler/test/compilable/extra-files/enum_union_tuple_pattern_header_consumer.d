module enum_union_tuple_pattern_header_consumer;

import enum_union_tuple_pattern_header;

int use(Value value)
{
    return inspect!void(value);
}