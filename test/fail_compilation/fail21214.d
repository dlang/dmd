/*
REQUIRED_ARGS: -m64
TEST_OUTPUT:
---
fail_compilation/fail21214.d(12): Error: 8 byte vector type `__vector(int[2])` is not supported on this platform
fail_compilation/fail21214.d(13): Error: 8 byte vector type `__vector(int[2])` is not supported on this platform
fail_compilation/fail21214.d(14): Error: vector type `__vector(__vector(int[4])[2])` is not supported on this platform
fail_compilation/fail21214.d(15): Error: vector type `__vector(__vector(int[4])[4])` is not supported on this platform
---
*/

__vector(__vector(int[2])[2]) v2x2;
__vector(__vector(int[2])[4]) v2x4;
__vector(__vector(int[4])[2]) v4x2;
__vector(__vector(int[4])[4]) v4x4;
