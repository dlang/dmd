/* https://issues.dlang.org/show_bug.cgi?id=20012
TEST_OUTPUT:
---
fail_compilation/fail20012.d(8): Error: array cast from `string` to `dstring` is not supported at compile time
fail_compilation/fail20012.d(9): Error: array cast from `string` to `dstring` is not supported at compile time
---
*/
enum a = cast(dstring) "what"c;
@(cast(dstring) "huh"c) int x;
