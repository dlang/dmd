/*
REQUIRED_ARGS: -preview=rvalueattribute
TEST_OUTPUT:
---
fail_compilation/rvalue_attrib.d(31): Error: `@rvalue ref` for module declaration is not supported
fail_compilation/rvalue_attrib.d(35): Error: `ref` expected after `@rvalue`, not `int`
fail_compilation/rvalue_attrib.d(35): Error: function declaration without return type. (Note that constructors are always named `this`)
fail_compilation/rvalue_attrib.d(35): Error: no identifier for declarator `func()`
fail_compilation/rvalue_attrib.d(36): Error: `ref` expected after `@rvalue`, not `int`
fail_compilation/rvalue_attrib.d(36): Error: basic type expected, not `)`
fail_compilation/rvalue_attrib.d(38): Error: `@rvalue ref` cannot appear as postfix
fail_compilation/rvalue_attrib.d(39): Error: `@rvalue ref` cannot appear as postfix
fail_compilation/rvalue_attrib.d(41): Error: found `fun` when expecting function literal following `@rvalue ref`
fail_compilation/rvalue_attrib.d(41): Error: semicolon expected following auto declaration, not `=>`
fail_compilation/rvalue_attrib.d(41): Error: declaration expected, not `=>`
fail_compilation/rvalue_attrib.d(42): Error: found `0` when expecting function literal following `@rvalue ref`
fail_compilation/rvalue_attrib.d(44): Error: redundant attribute `@rvalue ref`
fail_compilation/rvalue_attrib.d(45): Error: incompatible parameter storage classes
fail_compilation/rvalue_attrib.d(46): Error: variadic argument cannot be `@rvalue ref`
fail_compilation/rvalue_attrib.d(48): Error: found `)` when expecting `ref` following `@rvalue`
fail_compilation/rvalue_attrib.d(49): Error: found `int` when expecting `)` following `cast(@rvalue ref`
fail_compilation/rvalue_attrib.d(50): Error: found `const` when expecting `)` following `cast(@rvalue ref`
fail_compilation/rvalue_attrib.d(50): Error: basic type expected, not `)`
fail_compilation/rvalue_attrib.d(51): Error: basic type expected, not `@`
fail_compilation/rvalue_attrib.d(51): Error: found `@` when expecting `)`
fail_compilation/rvalue_attrib.d(51): Error: semicolon expected following auto declaration, not `ref`
fail_compilation/rvalue_attrib.d(51): Error: declaration expected, not `)`
---
*/

@rvalue ref module test;

static if (0) // test the parser only
{
@rvalue int func();
void func(@rvalue int);

void func() @rvalue ref;
void func(int @rvalue ref);

auto a = @rvalue ref fun => 0;
auto b = @rvalue ref 0;

void func(@rvalue ref @rvalue ref int);
void func(ref @rvalue ref int);
void func(@rvalue ref p ...);

auto c = cast(@rvalue) 0;
auto c = cast(@rvalue ref int) 0;
auto c = cast(@rvalue ref const) 0;
auto c = cast(const @rvalue ref) 0;
}
