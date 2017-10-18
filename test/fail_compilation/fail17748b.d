/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail17748b.d(10): Deprecation: class LeClass cannot be marked as "extern (C)".
fail_compilation/fail17748b.d(12): Deprecation: struct LeStruct cannot be marked as "extern (C)".
---
*/

extern (C) class LeClass {}

extern (C) struct LeStruct {}

void main()
{}
