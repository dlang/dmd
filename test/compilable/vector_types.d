/*
REQUIRED_ARGS: -o-
PERMUTE_ARGS:
TEST_OUTPUT:
DISABLED: freebsd32 linux32 osx32 win32
---
compilable/vector_types.d(22): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(22): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(23): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(23): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(24): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(24): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(25): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(25): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(26): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(26): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(27): Deprecation: 32 byte vector types are only supported with -mcpu=avx
compilable/vector_types.d(27): Deprecation: 32 byte vector types are only supported with -mcpu=avx
---
*/
version (D_SIMD):
alias a = __vector(double[4]);
alias b = __vector(float[8]);
alias c = __vector(ulong[4]);
alias d = __vector(uint[8]);
alias e = __vector(ushort[16]);
alias f = __vector(ubyte[32]);
