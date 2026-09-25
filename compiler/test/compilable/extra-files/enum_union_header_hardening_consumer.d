module enum_union_header_hardening_consumer;

import enum_union_header_hardening;

static assert(__traits(getAttributes, Value.None)[0].name == "none");
static assert(__traits(getAttributes, Value.Some)[0].name == "some");
static assert(inspect!void(Value.Some(7)) == 7);