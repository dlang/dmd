// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
MT()
RT()
RT!()
---
*/

mixin template MT() {}
template RT() {}

pragma(msg, MT);
pragma(msg, RT);
pragma(msg, RT!());
