/*
REQUIRED_ARGS: -m64 -o-
TEST_OUTPUT:
---
fail_compilation/diag8425.d(20): Error: T in __vector(T) must be a static array, not `void`
alias a = __vector(void); // not static array
^
fail_compilation/diag8425.d(21): Error: 1 byte vector type `__vector(void[1])` is not supported on this platform
alias b = __vector(void[1]); // wrong size
^
fail_compilation/diag8425.d(22): Error: 99 byte vector type `__vector(void[99])` is not supported on this platform
alias c = __vector(void[99]); // wrong size
^
fail_compilation/diag8425.d(23): Error: vector type `__vector(void*[4])` is not supported on this platform
alias d = __vector(void*[4]); // wrong base type
^
---
*/

alias a = __vector(void); // not static array
alias b = __vector(void[1]); // wrong size
alias c = __vector(void[99]); // wrong size
alias d = __vector(void*[4]); // wrong base type
