// REQUIRED_ARGS: -c -o-

class C7568 {}
struct S7568 { C7568 c; }
auto test7568a() { return [new C7568]; }
auto test7568b() { return S7568(new C7568); }

pragma(msg, test7568a());
pragma(msg, test7568b());


 