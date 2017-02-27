/*
TEST_OUTPUT
---
fail_compilation/fail9701.d(11): Error: only user defined attributes can appear in enums, not @nogc
fail_compilation/fail9701.d(11): Error: only user defined attributes can appear in enums, not @disable
---
*/

enum Enum
{
    @("string") @nogc @(117) @disable @("value", 2525) value,
}
