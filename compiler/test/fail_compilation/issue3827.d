// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/issue3827.d(18): Error: implicit string concatenation is error-prone and disallowed in D
    string[] arr = [ "Hello" "World" ];
                             ^
fail_compilation/issue3827.d(18):        Use the explicit syntax instead (concatenating literals is `@nogc`): "Hello" ~ "World"
fail_compilation/issue3827.d(19): Error: implicit string concatenation is error-prone and disallowed in D
    auto foo = "A" "B";
                   ^
fail_compilation/issue3827.d(19):        Use the explicit syntax instead (concatenating literals is `@nogc`): "A" ~ "B"
---
*/

void main ()
{
    string[] arr = [ "Hello" "World" ];
    auto foo = "A" "B";
}
