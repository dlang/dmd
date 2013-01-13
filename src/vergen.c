#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

int main() {
    int c;

    printf("\"", c);
    while ((c = fgetc(stdin)) != EOF) {
        if (c == '\n') break;
        printf("%c", c);
    }
    printf("\"");

    return EXIT_SUCCESS;
}
