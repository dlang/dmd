
__gshared long var;
void main()
{
    version(X86_64)
    asm{ mov [var], RAX; }
}
