// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail18417.d(17): Deprecation: `const` postblit is deprecated. Please use an unqualified postblit.
struct A { this(this) const {} }
                            ^
fail_compilation/fail18417.d(18): Deprecation: `immutable` postblit is deprecated. Please use an unqualified postblit.
struct B { this(this) immutable {} }
                                ^
fail_compilation/fail18417.d(19): Deprecation: `shared` postblit is deprecated. Please use an unqualified postblit.
struct C { this(this) shared {} }
                             ^
---
*/

struct A { this(this) const {} }
struct B { this(this) immutable {} }
struct C { this(this) shared {} }
