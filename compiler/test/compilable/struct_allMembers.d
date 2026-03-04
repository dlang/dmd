/*
TEST_OUTPUT:
---
S2: AliasSeq!("__dtor", "__xdtor", "opAssign")
S3: AliasSeq!("field", "__xdtor", "opAssign")
---
*/

// allMembers should include __xdtor
pragma(msg, "S2: ", __traits(allMembers, S2));
pragma(msg, "S3: ", __traits(allMembers, S3));

static struct S2 { ~this() {} }
static struct S3 { S2 field; }
