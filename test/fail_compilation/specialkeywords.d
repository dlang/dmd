/*
TEST_OUTPUT:
---
fail_compilation/specialkeywords.d(13): Error: cannot interpret `__FUNCTION__` at compile time
fail_compilation/specialkeywords.d(13):        while evaluating `pragma(msg, __FUNCTION__)`
fail_compilation/specialkeywords.d(14): Error: cannot interpret `__PRETTY_FUNCTION__` at compile time
fail_compilation/specialkeywords.d(14):        while evaluating `pragma(msg, __PRETTY_FUNCTION__)`
fail_compilation/specialkeywords.d(15): Error: cannot interpret `__MANGLED_FUNCTION__` at compile time
fail_compilation/specialkeywords.d(15):        while evaluating `pragma(msg, __MANGLED_FUNCTION__)`
---
*/

pragma(msg, __FUNCTION__);
pragma(msg, __PRETTY_FUNCTION__);
pragma(msg, __MANGLED_FUNCTION__);
