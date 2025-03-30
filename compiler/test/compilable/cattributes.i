/* Smoke test dllimport, dllexport, and naked attributes */

__declspec(dllimport) int abc;

__declspec(dllimport) int def();

__declspec(dllexport) int ghi() { return 3; }

__declspec(dllexport) int jkl;

__declspec(naked) __declspec(dllexport)
int test(int a, int b, int c, int d, int e, int f)
{
    return a + b + c + d + e + f + abc + def() + ghi() + jkl;
}

/*****************************************/

__attribute__((dllimport)) int abcx;

__attribute__((dllimport)) int defx();

__attribute__((dllexport)) int ghix() { return 3; }

__attribute__((dllexport)) int jklx;

__attribute__((naked)) __attribute__((dllexport))
int testx(int a, int b, int c, int d, int e, int f)
{
    return a + b + c + d + e + f + abcx + defx() + ghix() + jklx;
}

/*****************************************/

// https://issues.dlang.org/show_bug.cgi?id=24094

void test24094() {
    __declspec(align(16)) short data[64];
}
