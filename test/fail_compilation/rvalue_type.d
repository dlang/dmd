/* REQUIRED_ARGS: -preview=rvaluetype
TEST_OUTPUT:
---
fail_compilation/rvalue_type.d(18): Error: functions cannot be `@rvalue`
fail_compilation/rvalue_type.d(19): Error: `@rvalue` cannot appear as postfix
fail_compilation/rvalue_type.d(19): Error: function literal cannot be `@rvalue`
fail_compilation/rvalue_type.d(20): Error: `@rvalue` cannot appear as postfix
fail_compilation/rvalue_type.d(20): Error: function literal cannot be `@rvalue`
fail_compilation/rvalue_type.d(24): Error: constructor cannot be `@rvalue`
fail_compilation/rvalue_type.d(25): Error: postblit cannot be `@rvalue`
fail_compilation/rvalue_type.d(26): Error: functions cannot be `@rvalue`
---
*/

static if (0) // parser only
{

@rvalue int fun();
auto a = function () @rvalue {};
auto a = () @rvalue {};

struct S
{
    @rvalue this() {}
    @rvalue this(this) {}
    @rvalue int get() {}
}

}
