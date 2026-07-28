module issue20439a;

// Reduced, Phobos-free form of the bug. The original trigger was `SysTime.max`, which
// bakes a CTFE-allocated immutable class instance (its time zone) into a struct's
// `.init`; a plain `new C` reproduces the same toSymbol(ClassReferenceExp) path. The
// `new Inner` field additionally covers the toSymbol(StructLiteralExp) path.
class C { int x = 42; }
struct S { C c = new C; }

struct Inner { int y = 7; }
struct T { Inner* p = new Inner; }
