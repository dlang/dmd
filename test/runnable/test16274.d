/******************************************/
// https://issues.dlang.org/show_bug.cgi?id=16274

// These tests inspect the value of EDI parameter register.
// Integer promotions should have been done on:
//  - extern(C):   Yes (X86 and X86_64, shorts and bytes passed in EDI).
//  - extern(C++): Yes (X86 and X86_64, shorts and bytes passed in EDI).
//  - extern(D):   No  (shorts passed in DI, bytes in DIL, however EDI is used with -O).
//
// N.B: extern(D) tests are really UB, as the caller is free to pass
// parameters as any size if it so pleases.
//
// On x86, parameters are pushed as 32-bit integers on the stack,
// but we don't test for that.
version (D_InlineAsm_X86_64)
{
    version (Posix)
        version = SysV_X64_ABI;
}
extern(C) void test16274_cshort(short a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0xFFFFFFFF);
    }
    assert(a == -1);
}

extern(C) void test16274_cushort(ushort a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0x00000002);
    }
    assert(a == 2);
}

extern(C) void test16274_cbyte(byte a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0xFFFFFFFD);
    }
    assert(a == -3);
}

extern(C) void test16274_cubyte(ubyte a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0x00000004);
    }
    assert(a == 4);
}

extern(C++) void test16274_cppshort(short a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0xFFFFFFFF);
    }
    assert(a == -1);
}

extern(C++) void test16274_cppushort(ushort a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0x00000002);
    }
    assert(a == 2);
}

extern(C++) void test16274_cppbyte(byte a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0xFFFFFFFD);
    }
    assert(a == -3);
}

extern(C++) void test16274_cppubyte(ubyte a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0x00000004);
    }
    assert(a == 4);
}

extern(D) void test16274_dshort(short a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0xDEADFFFF || z == 0xFFFFFFFF);
    }
    assert(a == -1);
}

extern(D) void test16274_dushort(ushort a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0xDEAD0002 || z == 0x00000002);
    }
    assert(a == 2);
}

extern(D) void test16274_dbyte(byte a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0xDEADBEFD || z == 0x000000FD);
    }
    assert(a == -3);
}

extern(D) void test16274_dubyte(ubyte a)
{
    version (SysV_X64_ABI)
    {
        uint z = void;
        asm { mov z, EDI; }
        assert(z == 0xDEADBE04 || z == 0x00000004);
    }
    assert(a == 4);
}

// Fill the registers used to pass parameters
void test16274_fill()
{
    version (SysV_X64_ABI)
    {
        asm { mov EDI, 0xDEADBEEF; }
    }
}

void test_short()
{
    short a = -1;
    static foreach(lang; ["c", "cpp", "d"])
    {
        test16274_fill();
        mixin("test16274_"~lang~"short(a);");
    }
}

void test_ushort()
{
    ushort a = 2;
    static foreach(lang; ["c", "cpp", "d"])
    {
        test16274_fill();
        mixin("test16274_"~lang~"ushort(a);");
    }
}

void test_byte()
{
    byte a = -3;
    static foreach(lang; ["c", "cpp", "d"])
    {
        test16274_fill();
        mixin("test16274_"~lang~"byte(a);");
    }
}

void test_ubyte()
{
    ubyte a = 4;
    static foreach(lang; ["c", "cpp", "d"])
    {
        test16274_fill();
        mixin("test16274_"~lang~"ubyte(a);");
    }
}

void main()
{
    test_short();
    test_ushort();
    test_byte();
    test_ubyte();
}
