/* DISABLED: win32 win32mscoff win64
 */

/* https://issues.dlang.org/show_bug.cgi?id=23011
 */

extern char **myenviron asm("environ");
int myprintf(char *, ...) asm("printf");
int main()
{
    void *p = &myenviron;
    myprintf("%p\n", p);
    return 0;
}
