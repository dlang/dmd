/*
*/
extern(C++, std.__overloadset) void ice_std_keyword();

/*
TEST_OUTPUT:
---
fail_compilation/ice17074.d(19): Error: identifier expected for C++ namespace
extern(C++, std.*) void ice_std_token();
                ^
fail_compilation/ice17074.d(19): Error: found `*` when expecting `)`
extern(C++, std.*) void ice_std_token();
                ^
fail_compilation/ice17074.d(19): Error: declaration expected, not `)`
extern(C++, std.*) void ice_std_token();
                 ^
---
*/
extern(C++, std.*) void ice_std_token();
