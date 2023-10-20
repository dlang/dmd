
__attribute__((noinline)) int abc() { return 1; }
__declspec(noinline)      int def() { return 2; }
inline                    int ghi() { return 3; }

int test()
{
    return abc() + def() + ghi();
}
