// PERMUTE_ARGS:
// REQUIRED_ARGS: -w -o-

/*
TEST_OUTPUT:
---
test/fail_compilation/b5227.d(97): Error: index 2 is out of bounds: trying to get bytes [4:5] out of 4
test/fail_compilation/b5227.d(97):        called from here: paintIndex(16.5156F, 2)
test/fail_compilation/b5227.d(97):        while evaluating: static assert(cast(int)paintIndex(16.5156F, 2) == 0)
test/fail_compilation/b5227.d(20): Error: cannot convert &float to ulong* at compile time
test/fail_compilation/b5227.d(98):        called from here: paint(16.5156F)
test/fail_compilation/b5227.d(98):        while evaluating: static assert(paint(16.5156F) == 0LU)
---
*/

template paint(FromT, ToT)
{
    ToT paint(FromT f)
    {
        return *cast(ToT*)&f;
    }
}

template paintIndex(FromT, ToT)
{
    ToT paintIndex(FromT f, int offset)
    {
        return (cast(ToT*)&f)[offset];
    }
}

void main()
{
    // 16.515625 is:
    //   8658944 * 2E-19
    //   (note that the MSB is implicit for float and double, and explicit for Real)
    // Float:
    //   01000001_10000100_00100000_00000000
    // Double:
    //   01000000_00110000_10000100_00000000
    //   00000000_00000000_00000000_00000000
    // Real: 
    //   01000000_00000011_10000100_00100000
    //   00000000_00000000_00000000_00000000
    //   00000000_00000000


    // Whole type painting.
    static assert(paint!(int,float)(0x41842000) == 16.515625f);
    static assert(paint!(long,double)(0x4030840000000000L) == 16.515625f);

    static assert(paint!(float,int)(16.515625f) == 0x41842000);
    static assert(paint!(float,uint)(16.515625f) == 0x41842000u);
    static assert(paint!(double,long)(16.515625) == 0x4030840000000000L);
    static assert(paint!(double,ulong)(16.515625) == 0x4030840000000000UL);


    // Partial type painting with dereference.
    static assert(paint!(float,ushort)(16.515625f) == 0x2000);
    static assert(paint!(double,uint)(16.515625) == 0x0u);
    static assert(paint!(real,ulong)(16.515625) == 0x8420000000000000UL);


    // Partial type painting with indexing.
    static assert(paintIndex!(float,ubyte)(16.515625, 3) == 0x41);
    static assert(paintIndex!(float,ubyte)(16.515625, 2) == 0x84);
    static assert(paintIndex!(float,ubyte)(16.515625, 1) == 0x20);
    static assert(paintIndex!(float,ubyte)(16.515625, 0) == 0x00);

    static assert(paintIndex!(float,ushort)(16.515625, 1) == 0x4184);
    static assert(paintIndex!(float,ushort)(16.515625, 0) == 0x2000);

    static assert(paintIndex!(real,ubyte)(16.515625, 9) == 0x40);
    static assert(paintIndex!(real,ubyte)(16.515625, 8) == 0x03);
    static assert(paintIndex!(real,ubyte)(16.515625, 7) == 0x84);
    static assert(paintIndex!(real,ubyte)(16.515625, 6) == 0x20);
    static assert(paintIndex!(real,ubyte)(16.515625, 5) == 0x00);
    static assert(paintIndex!(real,ubyte)(16.515625, 4) == 0x00);
    static assert(paintIndex!(real,ubyte)(16.515625, 3) == 0x00);
    static assert(paintIndex!(real,ubyte)(16.515625, 2) == 0x00);
    static assert(paintIndex!(real,ubyte)(16.515625, 1) == 0x00);
    static assert(paintIndex!(real,ubyte)(16.515625, 0) == 0x00);

    static assert(paintIndex!(real,ushort)(16.515625, 4) == 0x4003);
    static assert(paintIndex!(real,ushort)(16.515625, 3) == 0x8420);
    static assert(paintIndex!(real,ushort)(16.515625, 2) == 0x0000);
    static assert(paintIndex!(real,ushort)(16.515625, 1) == 0x0000);
    static assert(paintIndex!(real,ushort)(16.515625, 0) == 0x0000);

    static assert(paintIndex!(real,uint)(16.515625, 1) == 0x84200000u);
    static assert(paintIndex!(real,uint)(16.515625, 0) == 0x00000000u);

    static assert(paintIndex!(real,ulong)(16.515625, 0) == 0x8420000000000000UL);
    

    // Failure tests:
    static assert(paintIndex!(float,ushort)(16.515625, 2) == 0);
    static assert(paint!(float,ulong)(16.515625f) == 0);
}