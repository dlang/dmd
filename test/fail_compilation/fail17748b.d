/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail17748b.d(9): Deprecation: class LeClass cannot be marked as "extern (C)".
---
*/

extern (C) class LeClass {}

void main()
{}
