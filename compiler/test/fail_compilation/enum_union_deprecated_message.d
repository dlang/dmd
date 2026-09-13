/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/enum_union_deprecated_message.d(17): Deprecation: enum union `enum_union_deprecated_message.OldValue` is deprecated - use NewValue
fail_compilation/enum_union_deprecated_message.d(12):        `OldValue` is declared here
fail_compilation/enum_union_deprecated_message.d(17): Deprecation: enum union `enum_union_deprecated_message.OldValue` is deprecated - use NewValue
fail_compilation/enum_union_deprecated_message.d(12):        `OldValue` is declared here
---
*/

deprecated("use NewValue") enum union OldValue
{
	case None(),
}

OldValue value;