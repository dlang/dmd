/*
TEST_OUTPUT:
---
fail_compilation/fail18417.d(10): Error: postblit cannot be `const`/`immutable`/`shared`/`static`
fail_compilation/fail18417.d(11): Error: postblit cannot be `const`/`immutable`/`shared`/`static`
fail_compilation/fail18417.d(12): Error: postblit cannot be `const`/`immutable`/`shared`/`static`
---
*/

struct A { this(this) const {} }
struct B { this(this) immutable {} }
struct C { this(this) shared {} }
