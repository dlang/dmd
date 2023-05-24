// REQUIRED_ARGS: -define:traits_getCmdlineConstant.test1=some_text=test -define:traits_getCmdlineConstant.test2=123 -define:traits_getCmdlineConstant.test3=123.456 "-define:traits_getCmdlineConstant.test4=Foo(4)" "-define:traits_getCmdlineConstant.test5=\"test\"" -define:test6=test -define:another_module.test7=some

// Fail compilation test for traits getCmdlineConstant

/*
TEST_OUTPUT:
---
fail_compilation/traits_getCmdlineConstant.d(36): Error: Cmdline constant `traits_getCmdlineConstant.__no_def` was not passed to the compiler arguments
fail_compilation/traits_getCmdlineConstant.d(37): Error: Cmdline constant `traits_getCmdlineConstant.__no_def` was not passed to the compiler arguments
fail_compilation/traits_getCmdlineConstant.d(39): Error: undefined identifier `some_text`
fail_compilation/traits_getCmdlineConstant.d(40): Error: undefined identifier `some_text`
fail_compilation/traits_getCmdlineConstant.d(42): Error: The cmdline constant expected a `int` type but received `123.456` which is a type `double`
fail_compilation/traits_getCmdlineConstant.d(44): Error: The cmdline constant expected a `double` type but received `Foo(4)` which is a type `Foo`
fail_compilation/traits_getCmdlineConstant.d(45): Error: The cmdline constant expected a `Foo` type but received `123.456` which is a type `double`
fail_compilation/traits_getCmdlineConstant.d(47): Error: The cmdline constant expected a `double` type but received `Foo(4)` which is a type `Foo`
fail_compilation/traits_getCmdlineConstant.d(48): Error: The cmdline constant expected a `int` type but received `"test"` which is a type `string`
fail_compilation/traits_getCmdlineConstant.d(50): Error: The second trait argument accepts only D types or false
fail_compilation/traits_getCmdlineConstant.d(51): Error: The second trait argument accepts only D types or false
fail_compilation/traits_getCmdlineConstant.d(52): Error: The second trait argument accepts only D types or false
fail_compilation/traits_getCmdlineConstant.d(54): Error: Cmdline constant `traits_getCmdlineConstant.test6` was not passed to the compiler arguments
fail_compilation/traits_getCmdlineConstant.d(55): Error: Cmdline constant `traits_getCmdlineConstant.test6` was not passed to the compiler arguments
fail_compilation/traits_getCmdlineConstant.d(56): Error: Cmdline constant `traits_getCmdlineConstant.test6` was not passed to the compiler arguments
fail_compilation/traits_getCmdlineConstant.d(58): Error: The cmdline constant expected a `string` type but received `1` which is a type `int`
fail_compilation/traits_getCmdlineConstant.d(59): Error: undefined identifier `not_at_string`
fail_compilation/traits_getCmdlineConstant.d(61): Error: undefined identifier `some_text`
fail_compilation/traits_getCmdlineConstant.d(62): Error: undefined identifier `some_text`
fail_compilation/traits_getCmdlineConstant.d(64): Error: Cmdline constant `traits_getCmdlineConstant.test7` was not passed to the compiler arguments
fail_compilation/traits_getCmdlineConstant.d(65): Error: Cmdline constant `traits_getCmdlineConstant.another_module.test7` was not passed to the compiler arguments
---
*/

struct Foo {
    int a;
}

enum TEST_1 = __traits(getCmdlineConstant, "__no_def");
enum TEST_2 = __traits(getCmdlineConstant, "__no_def", int);

enum TEST_3 = __traits(getCmdlineConstant, "test1", int);
enum TEST_4 = __traits(getCmdlineConstant, "test1", int, 3);

enum TEST_5 = __traits(getCmdlineConstant, "test3", int);

enum TEST_7 = __traits(getCmdlineConstant, "test4", double);
enum TEST_8 = __traits(getCmdlineConstant, "test3", Foo);

enum TEST_9 = __traits(getCmdlineConstant, "test4", double);
enum TEST_10 = __traits(getCmdlineConstant, "test5", int);

enum TEST_11 = __traits(getCmdlineConstant, "test1", true);
enum TEST_12 = __traits(getCmdlineConstant, "test1", true, 4);
enum TEST_13 = __traits(getCmdlineConstant, "__no_def", true, 4);

enum TEST_14 = __traits(getCmdlineConstant, "test6");
enum TEST_15 = __traits(getCmdlineConstant, "test6", int);
enum TEST_16 = __traits(getCmdlineConstant, "test6", string);

enum TEST_17 = __traits(getCmdlineConstant, "__no_def", false, 1);
enum TEST_18 = __traits(getCmdlineConstant, "__no_def", false, not_at_string);

enum TEST_19 = __traits(getCmdlineConstant, "test1", int);
enum TEST_20 = __traits(getCmdlineConstant, "test1", string);

enum TEST_21 = __traits(getCmdlineConstant, "test7", string);
enum TEST_22 = __traits(getCmdlineConstant, "another_module.test7", string);
