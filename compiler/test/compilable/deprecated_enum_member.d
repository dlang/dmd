/*
REQUIRED_ARGS: -verrors=simple
TEST_OUTPUT:
---
compilable/deprecated_enum_member.d(20): Deprecation: enum member `deprecated_enum_member.anon` is deprecated
compilable/deprecated_enum_member.d(17):        `anon` is declared here
compilable/deprecated_enum_member.d(21): Deprecation: enum member `deprecated_enum_member.E.named` is deprecated
compilable/deprecated_enum_member.d(18):        `named` is declared here
---
*/

// A deprecated enum member accessed by name must emit the deprecation diagnostic
// exactly once. Previously an anonymous-enum member (or an ImportC enumerator)
// accessed by its unqualified name reported the deprecation twice, because the symbol
// was checked both during name resolution and again in getVarExp().

enum { deprecated anon = 0, anonB }
enum E { deprecated named = 0, namedB }

int useAnon()  { return anon; }
int useNamed() { return E.named; }
