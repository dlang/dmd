// https://issues.dlang.org/show_bug.cgi?id=22812
/* TEST_OUTPUT:
---
fail_compilation/fail22812.c(19): Error: left parenthesis expected to follow `#pragma pack`
#pragma pack
        ^
fail_compilation/fail22812.c(20): Error: unrecognized `#pragma pack(\n)`
#pragma pack(
        ^
fail_compilation/fail22812.c(21): Error: pack must be an integer positive power of 2, not 0x3
#pragma pack(3
        ^
fail_compilation/fail22812.c(21): Error: right parenthesis expected to close `#pragma pack(`
#pragma pack(3
        ^
---
*/
#pragma
#pragma pack
#pragma pack(
#pragma pack(3
