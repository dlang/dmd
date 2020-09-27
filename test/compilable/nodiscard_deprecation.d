/*
TEST_OUTPUT
---
compilable/nodiscard_deprecation.d(8): Deprecation: use of `@nodiscard` as a user-defined attribute is deprecated.
---
*/
struct nodiscard {}
@nodiscard extern int func();
