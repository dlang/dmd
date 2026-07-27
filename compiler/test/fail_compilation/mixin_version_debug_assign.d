/*
TEST_OUTPUT:
---
fail_compilation/mixin_version_debug_assign.d-mixin-15(15): Error: version `foo` declaration must be at module level
fail_compilation/mixin_version_debug_assign.d(15):        while parsing string mixin statement
fail_compilation/mixin_version_debug_assign.d-mixin-20(20): Error: identifier expected, not `1`
fail_compilation/mixin_version_debug_assign.d(20):        while parsing string mixin statement
---
*/

void main()
{
    // Previously crashed dmd with ACCESS_VIOLATION: parseStatement returned null,
    // then string-mixin semantic did errorSupplemental(s.loc, ...).
    mixin("version = foo;");
}

void other()
{
    mixin("debug = 1;");
}
