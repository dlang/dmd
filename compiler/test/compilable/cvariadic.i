int abc() { return 1; }
int def(const char *p, ...) { return 2; }
int ghi(const char *p, int i) { return 3; }

int main()
{
    abc("hello world %d\n", 1);
    def("hello world %d\n", 2);
    ghi("hello world %d\n", 3);
    return 0;
}
