/* RUN_OUTPUT:
---
xx need dictionary
---
 */

// issues.dlang.org/show_bug.cgi?id=22376

int printf(const char *, ...);

char * const errmsg[1] = {
    (char*)"need dictionary",
};

int main()
{
    printf("xx %s\n", errmsg[0]);
    return 0;
}
