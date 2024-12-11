/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
DISABLED: freebsd32 openbsd32 linux32 osx32 win32
---
fail_compilation/vector_types.d(27): Error: 32 byte vector type `__vector(double[4])` is not supported on this platform
alias a = __vector(double[4]);
^
fail_compilation/vector_types.d(28): Error: 32 byte vector type `__vector(float[8])` is not supported on this platform
alias b = __vector(float[8]);
^
fail_compilation/vector_types.d(29): Error: 32 byte vector type `__vector(ulong[4])` is not supported on this platform
alias c = __vector(ulong[4]);
^
fail_compilation/vector_types.d(30): Error: 32 byte vector type `__vector(uint[8])` is not supported on this platform
alias d = __vector(uint[8]);
^
fail_compilation/vector_types.d(31): Error: 32 byte vector type `__vector(ushort[16])` is not supported on this platform
alias e = __vector(ushort[16]);
^
fail_compilation/vector_types.d(32): Error: 32 byte vector type `__vector(ubyte[32])` is not supported on this platform
alias f = __vector(ubyte[32]);
^
---
*/

alias a = __vector(double[4]);
alias b = __vector(float[8]);
alias c = __vector(ulong[4]);
alias d = __vector(uint[8]);
alias e = __vector(ushort[16]);
alias f = __vector(ubyte[32]);
