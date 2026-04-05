/*
REQUIRED_ARGS:
TEST_OUTPUT:
---
fail_compilation/dollarinfer.d(28): Error: `dollarinfer.ambig` with inferred type from `$` matches multiple overloads:
fail_compilation/dollarinfer.d(24):     `dollarinfer.ambig(Data d)`
and:
fail_compilation/dollarinfer.d(25):     `dollarinfer.ambig(Other o)`
`$` type inference is ambiguous - consider using an explicit type cast
fail_compilation/dollarinfer.d(30): Error: variable `dollarinfer.main.unknown` - `$` requires a known type context for inference, but type is inferred from initializer `$.VALUE_A`
fail_compilation/dollarinfer.d(30):        `auto` does not provide a type context for `$`, consider using an explicit type
fail_compilation/dollarinfer.d(32): Error: no property `VALUE_C` for type `MyEnum`. Did you mean `MyEnum.VALUE_A` ?
fail_compilation/dollarinfer.d(18):        enum `MyEnum` defined here
fail_compilation/dollarinfer.d(34): Error: cannot cast expression `$` of type `void` to `int`
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
