/*
TEST_OUTPUT:
---
fail_compilation/fail254.d(12): Error: cannot implicitly convert expression `cast(cent)((cast(cent)0xffffffffffffffffULL << 64) | 0xff...` of type `cent` to `ulong`
fail_compilation/fail254.d(13): Error: cannot implicitly convert expression `cast(cent)((cast(cent)0x1ULL << 64) | 0x0ULL)` of type `cent` to `ulong`
fail_compilation/fail254.d(14): Error: cannot implicitly convert expression `cast(cent)((cast(cent)0x1ULL << 64) | 0xffffffffffffffffULL)` of type `cent` to `ulong`
fail_compilation/fail254.d(15): Error: cannot implicitly convert expression `cast(cent)((cast(cent)0x7ULL << 64) | 0xffffffffffffffffULL)` of type `cent` to `ulong`
fail_compilation/fail254.d(16): Error: cannot implicitly convert expression `cast(cent)((cast(cent)0x1ULL << 64) | 0xffffffffffffULL)` of type `cent` to `ulong`
---
*/

ulong v1 = 0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
ulong v2 = 0x1_0000_0000_0000_0000;
ulong v3 = 0x1_FFFF_FFFF_FFFF_FFFF;
ulong v4 = 0x7_FFFF_FFFF_FFFF_FFFF;
ulong v5 = 0x1_0000_FFFF_FFFF_FFFF;
