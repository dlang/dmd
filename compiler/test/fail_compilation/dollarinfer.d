/*
REQUIRED_ARGS:
TEST_OUTPUT:
---
fail_compilation/dollarinfer.d(29): Error: `dollarinfer.ambig` with inferred type from `$` matches multiple overloads:
fail_compilation/dollarinfer.d(25):     `dollarinfer.ambig(Data d)`
and:
fail_compilation/dollarinfer.d(26):     `dollarinfer.ambig(Other o)`
`$` type inference is ambiguous - consider using an explicit type cast
fail_compilation/dollarinfer.d(31): Error: variable `dollarinfer.main.unknown` - `$` requires a known type context for inference, but type is inferred from initializer `dollar.VALUE_A`
fail_compilation/dollarinfer.d(31):        `auto` does not provide a type context for `$` - consider using an explicit type like `unknown = MyType.value`
fail_compilation/dollarinfer.d(33): Error: no property `VALUE_C` for type `MyEnum`. Did you mean `MyEnum.VALUE_A` ?
fail_compilation/dollarinfer.d(19):        enum `MyEnum` defined here
fail_compilation/dollarinfer.d(35): Error: type `int` has no value
fail_compilation/dollarinfer.d(35):        perhaps use `int.init`
---
*/

enum MyEnum { VALUE_A, VALUE_B }
struct Data { int x, y; }
struct Other { int x, y; }

void call(MyEnum m) {}
void call(int i) {}
void ambig(Data d) {}
void ambig(Other o) {}

void main() {
    ambig($(1, 2));

    auto unknown = $.VALUE_A;

    MyEnum m = $.VALUE_C;

    int x = $;
}
