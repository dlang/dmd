/*
REQUIRED_ARGS: -o-
PERMUTE_ARGS:
TEST_OUTPUT:
DISABLED: freebsd32 linux32 osx32 win32
---
fail_compilation/vector_types.d(16): Error: 32 byte vector type `__vector(double[4])` is not supported on this platform
fail_compilation/vector_types.d(17): Error: 32 byte vector type `__vector(float[8])` is not supported on this platform
fail_compilation/vector_types.d(18): Error: 32 byte vector type `__vector(ulong[4])` is not supported on this platform
fail_compilation/vector_types.d(19): Error: 32 byte vector type `__vector(uint[8])` is not supported on this platform
fail_compilation/vector_types.d(20): Error: 32 byte vector type `__vector(ushort[16])` is not supported on this platform
fail_compilation/vector_types.d(21): Error: 32 byte vector type `__vector(ubyte[32])` is not supported on this platform
---
*/
version (D_SIMD):
alias a = __vector(double[4]);
alias b = __vector(float[8]);
alias c = __vector(ulong[4]);
alias d = __vector(uint[8]);
alias e = __vector(ushort[16]);
alias f = __vector(ubyte[32]);

