/*
TEST_OUTPUT:
---
fail_compilation/ice15127.d(29): Error: basic type expected, not `struct`
    enum ExampleTemplate(struct ExampleStruct(K)) = K;
                         ^
fail_compilation/ice15127.d(29): Error: identifier expected for template value parameter
    enum ExampleTemplate(struct ExampleStruct(K)) = K;
                         ^
fail_compilation/ice15127.d(29): Error: found `struct` when expecting `)`
    enum ExampleTemplate(struct ExampleStruct(K)) = K;
                         ^
fail_compilation/ice15127.d(29): Error: found `ExampleStruct` when expecting `=`
    enum ExampleTemplate(struct ExampleStruct(K)) = K;
                                ^
fail_compilation/ice15127.d(29): Error: semicolon expected following auto declaration, not `)`
    enum ExampleTemplate(struct ExampleStruct(K)) = K;
                                                ^
fail_compilation/ice15127.d(29): Error: declaration expected, not `)`
    enum ExampleTemplate(struct ExampleStruct(K)) = K;
                                                ^
---
*/

struct ExampleStruct(S) { }

template ExampleTemplate(K)
{
    enum ExampleTemplate(struct ExampleStruct(K)) = K;
}

void main() {}
