/* https://issues.dlang.org/show_bug.cgi?id=22546
DISABLED: linux32 win32
TEST_OUTPUT:
---
fail_compilation/fail20012.d(10): Error: array cast from `string` to `dstring` is not supported at compile time
$p:druntime/import/core/internal/array/casting.d$($n$): Error: `immutable(char)[]` of length 3 cannot be cast to `immutable(dchar)[]` as its length in bytes (3) is not a multiple of `immutable(dchar).sizeof` (4).
$p:druntime/import/core/internal/array/casting.d$($n$):        called from here: `onArrayCastError("immutable(char)", fromSize, from.length, "immutable(dchar)", 4LU)`
fail_compilation/fail20012.d(11):        called from here: `__ArrayCast("huh"c)`
---
*/
enum a = cast(dstring) "what"c;
@(cast(dstring) "huh"c) int x;
