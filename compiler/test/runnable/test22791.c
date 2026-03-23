int printf(const char *, ...);

void test_memcpy() {
    char dest[20];
    char src[] = "Hello World";
    __builtin_memcpy(dest, src, 12);
    if (__builtin_memcmp(dest, src, 12) != 0) {
        printf("Error: memcmp failed\n");
    }
}

int main() {
    test_memcpy();
    return 0;
}
