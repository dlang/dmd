__const__ int f(int x) { return x * 2; }
__const int g(int x) { return x * 3; }
__attribute__((__const__)) int h(int x) { return x * 4; }
static __const__ char *__const__ p = "hi";
typedef __const__ int cint_t;

int main(void)
{
    if (f(2) != 4) return 1;
    if (g(2) != 6) return 2;
    if (h(2) != 8) return 3;
    if (p[0] != 'h') return 4;
    cint_t c = 5;
    if (c != 5) return 5;
    return 0;
}
