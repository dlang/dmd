/* TEST_OUTPUT:
---
fail_compilation/alignedext.i(10): Error: __decspec(align(123)) must be an integer positive power of 2 and be <= 8,192
fail_compilation/alignedext.i(11): Error: __decspec(align(16384)) must be an integer positive power of 2 and be <= 8,192
fail_compilation/alignedext.i(13): Error: __attribute__((aligned(123))) must be an integer positive power of 2 and be <= 32,768
fail_compilation/alignedext.i(14): Error: __attribute__((aligned(65536))) must be an integer positive power of 2 and be <= 32,768
---
*/

typedef struct __declspec(align(123)) S { int a; } S;
struct __declspec(align(16384)) T { int a; };

typedef struct __attribute__((aligned(123))) U { int a; } S;
struct __attribute__((aligned(65536))) V { int a; };
