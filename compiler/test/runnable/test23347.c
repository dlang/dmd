/* DISABLED: osx32 osx64 win32 win64
 * TEST_OUTPUT:
---
---
 */

// https://issues.dlang.org/show_bug.cgi?id=23347

void fork() { }

#pragma pack(push, 4)
void spoon() asm("fork");
#pragma pack(pop);

int main()
{
    spoon();
    return 0;
}
