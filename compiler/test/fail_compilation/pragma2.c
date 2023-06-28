/* REQUIRED_ARGS: -w
TEST_OUTPUT:
---
fail_compilation/pragma2.c(101): Warning: current pack attribute is default
fail_compilation/pragma2.c(102): Error: left parenthesis expected to follow `#pragma pack`
fail_compilation/pragma2.c(103): Error: right parenthesis expected to close `#pragma pack(`
fail_compilation/pragma2.c(104): Error: unrecognized `#pragma pack(&)`
fail_compilation/pragma2.c(106): Error: identifier or alignment value expected following `#pragma pack(pop,` not `"foo"`
---
*/

#line 100

#pragma pack(show)
#pragma pack
#pragma pack(pop,a,b,4,8,c
#pragma pack(&)
#pragma pack() ;a
#pragma pack (pop, "foo");

int x;
