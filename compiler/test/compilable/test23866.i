// https://issues.dlang.org/show_bug.cgi?id=23866

struct __declspec(align(16)) __declspec(no_init_all) S { };

typedef struct __attribute__((aligned(16))) __declspec(no_init_all) S2 { } S2;
