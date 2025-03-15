#include <stdio.h>

void cdind() {
    struct ABC {
        int y;
    } *p;

    {
        struct ABC { int x; } abc;
        abc.x = 1;  // Should NOT give an error now
        printf("abc.x = %d\n", abc.x);
    }
}

int main() {
    cdind();  // Call the function
    return 0;
}

