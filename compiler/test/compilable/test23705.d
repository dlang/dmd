// https://issues.dlang.org/show_bug.cgi?id=23705

// DISABLED: win32

void main ()
{
    ubyte [0x7fff_fffe] x;
}
