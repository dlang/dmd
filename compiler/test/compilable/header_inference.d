/*
TEST_OUTPUT:
---
// D import file generated from 'header_inference.d'
module header_inference;
auto pure nothrow @nogc @safe int add(int a, int b)
{
	return a + b;
}
---
*/

// REQUIRED_ARGS: -H -Hf- -o-
// PERMUTE_ARGS:

module header_inference;

auto add(int a, int b)
{
    return a + b;
}
