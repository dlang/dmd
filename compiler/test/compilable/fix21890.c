// https://github.com/dlang/dmd/issues/21890
// a local variable or parameter hides a typedef of the same name (C11 6.2.1-4)

typedef unsigned char byte;
typedef unsigned char sljit_u8;
#define U8(v) ((sljit_u8)(v))

void local(void)
{
    sljit_u8 byte = 1;
    byte = U8(byte | (byte << 2));
}

int param(int byte)
{
    return (byte | 1) + (byte << 2);
}

void nested(void)
{
    {
        int byte = 1;
        byte = byte | (byte << 2);
    }
    byte after = (byte)3;       // typedef is visible again after the block
}

int loop(void)
{
    int t = 0;
    for (int byte = 0; byte < 3; byte = byte | 1)
        t += (byte | 2);
    byte q = (byte)1;           // and after the for statement
    return t + q;
}

byte global = (byte)255;
