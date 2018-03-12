// PERMUTE_ARGS:

version (D_InlineAsm_X86_64)
{
    void b18553()
    {
        asm
        {
            mov RAX, CR0;
            mov RAX, CR2;
            mov RAX, CR3;
            mov RAX, CR4;
            mov CR0, RAX;
            mov CR2, RAX;
            mov CR3, RAX;
            mov CR4, RAX;

            mov CR8, RAX;
            mov RAX, CR8;
        }
    }
}

int main() { return 0; }
