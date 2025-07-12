/*
TEST_OUTPUT:
---
fail_compilation/b12504.d(34): Error: implicit conversion from `ulong` (64 bytes) to `ubyte` (8 bytes) may truncate value
fail_compilation/b12504.d(34):        Use an explicit cast (e.g., `cast(ubyte)expr`) to silence this.
fail_compilation/b12504.d(35): Error: index type `ubyte` cannot cover index range 0..257
fail_compilation/b12504.d(39): Error: implicit conversion from `ulong` (64 bytes) to `byte` (8 bytes) may truncate value
fail_compilation/b12504.d(39):        Use an explicit cast (e.g., `cast(byte)expr`) to silence this.
fail_compilation/b12504.d(40): Error: index type `byte` cannot cover index range 0..129
fail_compilation/b12504.d(44): Error: implicit conversion from `ulong` (64 bytes) to `ushort` (16 bytes) may truncate value
fail_compilation/b12504.d(44):        Use an explicit cast (e.g., `cast(ushort)expr`) to silence this.
fail_compilation/b12504.d(45): Error: index type `ushort` cannot cover index range 0..65537
fail_compilation/b12504.d(49): Error: implicit conversion from `ulong` (64 bytes) to `short` (16 bytes) may truncate value
fail_compilation/b12504.d(49):        Use an explicit cast (e.g., `cast(short)expr`) to silence this.
fail_compilation/b12504.d(50): Error: index type `short` cannot cover index range 0..32769
fail_compilation/b12504.d(54): Error: implicit conversion from `ulong` (64 bytes) to `ubyte` (8 bytes) may truncate value
fail_compilation/b12504.d(54):        Use an explicit cast (e.g., `cast(ubyte)expr`) to silence this.
fail_compilation/b12504.d(55): Error: index type `ubyte` cannot cover index range 0..257
fail_compilation/b12504.d(59): Error: implicit conversion from `ulong` (64 bytes) to `byte` (8 bytes) may truncate value
fail_compilation/b12504.d(59):        Use an explicit cast (e.g., `cast(byte)expr`) to silence this.
fail_compilation/b12504.d(60): Error: index type `byte` cannot cover index range 0..129
fail_compilation/b12504.d(64): Error: implicit conversion from `ulong` (64 bytes) to `ushort` (16 bytes) may truncate value
fail_compilation/b12504.d(64):        Use an explicit cast (e.g., `cast(ushort)expr`) to silence this.
fail_compilation/b12504.d(65): Error: index type `ushort` cannot cover index range 0..65537
fail_compilation/b12504.d(69): Error: implicit conversion from `ulong` (64 bytes) to `short` (16 bytes) may truncate value
fail_compilation/b12504.d(69):        Use an explicit cast (e.g., `cast(short)expr`) to silence this.
fail_compilation/b12504.d(70): Error: index type `short` cannot cover index range 0..32769
---
*/
void main()
{
    {
        int[0xFF + 2] sta;
        foreach (ubyte i; 0 .. sta.length) {}
        foreach (ubyte i, x; sta) {}
    }
    {
        int[0x7F + 2] sta;
        foreach (byte i; 0 .. sta.length) {}
        foreach (byte i, x; sta) {}
    }
    {
        int[0xFFFF + 2] sta;
        foreach (ushort i; 0 .. sta.length) {}
        foreach (ushort i, x; sta) {}
    }
    {
        int[0x7FFF + 2] sta;
        foreach (short i; 0 .. sta.length) {}
        foreach (short i, x; sta) {}
    }
    {
        immutable int[0xFF + 2] sta;
        static foreach (ubyte i; 0 .. sta.length) {}
        static foreach (ubyte i, x; sta) {}
    }
    {
        immutable int[0x7F + 2] sta;
        static foreach (byte i; 0 .. sta.length) {}
        static foreach (byte i, x; sta) {}
    }
    {
        immutable int[0xFFFF + 2] sta;
        static foreach (ushort i; 0 .. sta.length) {}
        static foreach (ushort i, x; sta) {}
    }
    {
        immutable int[0x7FFF + 2] sta;
        static foreach (short i; 0 .. sta.length) {}
        static foreach (short i, x; sta) {}
    }
}
