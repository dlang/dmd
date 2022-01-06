/* REQUIRED_ARGS: -w
TEST_OUTPUT:
---
fail_compilation/pragma2.c(11): Warning: current pack attribute is default
fail_compilation/pragma2.c(14): Error: unrecognized `#pragma pack(&)`
fail_compilation/pragma2.c(13): Error: right parenthesis expected to close `#pragma pack(`
fail_compilation/pragma2.c(12): Error: left parenthesis expected to follow `#pragma pack`
---
*/

#pragma pack(show)
#pragma pack
#pragma pack(pop,a,b,4,8,c
#pragma pack(&)
#pragma pack() ;a

int x;
