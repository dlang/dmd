// https://issues.dlang.org/show_bug.cgi?id=22812
/* TEST_OUTPUT:
---
fail_compilation/fail22812.c(11): Error: left parenthesis expected to follow `#pragma pack`
fail_compilation/fail22812.c(12): Error: unrecognized `#pragma pack(\n)`
fail_compilation/fail22812.c(13): Error: pack must be an integer positive power of 2, not 0x3
fail_compilation/fail22812.c(13): Error: right parenthesis expected to close `#pragma pack(`
---
*/
#pragma
#pragma pack
#pragma pack(
#pragma pack(3
