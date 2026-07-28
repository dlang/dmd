/*
REQUIRED_ARGS: -verrors=simple
TEST_OUTPUT:
---
compilable/deprecated_enum_member.d(33): Deprecation: enum member `deprecated_enum_member.anon` is deprecated
compilable/deprecated_enum_member.d(28):        `anon` is declared here
compilable/deprecated_enum_member.d(36): Deprecation: enum member `deprecated_enum_member.E.named` is deprecated
compilable/deprecated_enum_member.d(29):        `named` is declared here
compilable/deprecated_enum_member.d(39): Deprecation: enum member `deprecated_enum_member.E.named` is deprecated
compilable/deprecated_enum_member.d(29):        `named` is declared here
compilable/deprecated_enum_member.d(42): Deprecation: enum member `deprecated_enum_member.F.withMsg` is deprecated - use namedB
compilable/deprecated_enum_member.d(30):        `withMsg` is declared here
compilable/deprecated_enum_member.d(43): Deprecation: enum member `deprecated_enum_member.F.withMsg` is deprecated - use namedB
compilable/deprecated_enum_member.d(30):        `withMsg` is declared here
compilable/deprecated_enum_member.d(47): Deprecation: enum member `deprecated_enum_member.anon` is deprecated
compilable/deprecated_enum_member.d(28):        `anon` is declared here
compilable/deprecated_enum_member.d(47): Deprecation: enum member `deprecated_enum_member.anon` is deprecated
compilable/deprecated_enum_member.d(28):        `anon` is declared here
---
*/

// A deprecated enum member must emit its deprecation diagnostic exactly once per
// use, regardless of how it is named. Previously an enum member accessed by its
// unqualified name (an anonymous-enum member, a member found via `with`, or an
// ImportC enumerator) reported the deprecation twice, because the symbol was
// checked both during name resolution and again in getVarExp(). See issue 23241.

enum { deprecated anon = 0, anonB }
enum E { deprecated named = 0, namedB }
enum F { deprecated("use namedB") withMsg = 0, plain }

// Anonymous enum member, accessed by its unqualified name.
int useAnon() { return anon; }

// Named enum member, accessed by its fully qualified name.
int useNamedQualified() { return E.named; }

// Named enum member, accessed by its unqualified name brought into scope by `with`.
int useNamedWith() { E e; with (e) return named; }

// A deprecated member carrying an explicit message reproduces that message.
int useWithMsgQualified() { return F.withMsg; }
int useWithMsgWith() { F f; with (f) return withMsg; }

// Each separate use emits its own diagnostic (the fix removes a duplicate per use,
// it does not globally deduplicate distinct uses).
int useAnonAgain() { return anon + anon; }

// Non-deprecated members of the same enums emit nothing.
int useClean() { return anonB + E.namedB + F.plain; }

// A use from within a deprecated scope is suppressed entirely.
deprecated int useFromDeprecated() { return anon + E.named + F.withMsg; }
