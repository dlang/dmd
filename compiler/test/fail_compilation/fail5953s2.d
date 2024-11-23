/*
TEST_OUTPUT:
---
fail_compilation/fail5953s2.d(18): Error: expression expected, not `,`
    S s3 = {,,,}; // invalid, but compiles
            ^
fail_compilation/fail5953s2.d(18): Error: expression expected, not `,`
    S s3 = {,,,}; // invalid, but compiles
             ^
fail_compilation/fail5953s2.d(18): Error: expression expected, not `,`
    S s3 = {,,,}; // invalid, but compiles
              ^
---
*/
void main()
{
    struct S{}
    S s3 = {,,,}; // invalid, but compiles
}
