/*
TEST_OUTPUT:
---
fail_compilation/diag15235.d(13): Error: cannot have two symbols in addressing mode
        mov [EBX+EBX+EBX], EAX; // prints the same error message 20 times
                              ^
---
*/

void main()
{
    asm {
        mov [EBX+EBX+EBX], EAX; // prints the same error message 20 times
    }
}
