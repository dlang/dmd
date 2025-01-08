/*
RUN_OUTPUT:
---
yes
yes
---
*/

// main.d -------------------------------------------------------

import core.stdc.stdio: printf;

int main(string[] args)
{
    enum K = 42;
    switch (K)
    {
        case 0  -> printf("A: no0\n");
        case 42 -> printf("A: yes\n");
        case 1  -> printf("A: no1\n");

        default -> printf("A: default\n");
    }
    switch (K)
    {
        case 0  -> { 
            printf("B: no0\n");
        }
        case 42 -> {
            printf("B: yes\n");
        }
        case 1  -> {
            printf("B: no1\n");
        }

        default -> {
            printf("B: default\n");
        }
    }
    switch (K)
    {
        case 0:  printf("C: no0\n"); break;
        case 42: printf("C: yes\n"); break;
        case 1:  printf("C: no1\n"); break;

        default: printf("C: default\n");
    }
}
