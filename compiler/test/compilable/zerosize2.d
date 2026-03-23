// Test zero sized fields where TargetC.contributesToAlignment
extern(D)
{
    struct D0 { }
    struct D1 { byte : 0; }
    struct D2 { short : 0; }
    struct D3 { int : 0; }
    struct D4 { long : 0; }
    struct D5 { byte[0] f; }
    struct D6 { short[0] f; }
    struct D7 { int[0] f; }
    struct D8 { long[0] f; }
    struct D9 { int : 0; short[0] f; }
    align(16)
    {
        struct D10 { }
        struct D11 { byte : 0; }
        struct D12 { short : 0; }
        struct D13 { int : 0; }
        struct D14 { long : 0; }
        struct D15 { byte[0] f; }
        struct D16 { short[0] f; }
        struct D17 { int[0] f; }
        struct D18 { long[0] f; }
        struct D19 { int : 0; short[0] f; }
    }
}

extern(C)
{
    struct C0 { }
    struct C1 { byte : 0; }
    struct C2 { short : 0; }
    struct C3 { int : 0; }
    struct C4 { long : 0; }
    struct C5 { byte[0] f; }
    struct C6 { short[0] f; }
    struct C7 { int[0] f; }
    struct C8 { long[0] f; }
    struct C9 { int : 0; short[0] f; }
    align(16)
    {
        struct C10 { }
        struct C11 { byte : 0; }
        struct C12 { short : 0; }
        struct C13 { int : 0; }
        struct C14 { long : 0; }
        struct C15 { byte[0] f; }
        struct C16 { short[0] f; }
        struct C17 { int[0] f; }
        struct C18 { long[0] f; }
        struct C19 { int : 0; short[0] f; }
    }
}

version (Posix):

// Anonymous bitfields don't contribute to alignment.
version (X86_64)
{
    // Empty
    static assert(D0.sizeof == 1 && D0.alignof == 1);
    static assert(D10.sizeof == 16 && D10.alignof == 16);

    // Zero width bitfields
    static assert(D1.sizeof == 1 && D1.alignof == 1);
    static assert(D2.sizeof == 1 && D2.alignof == 1);
    static assert(D3.sizeof == 1 && D3.alignof == 1);
    static assert(D4.sizeof == 1 && D4.alignof == 1);
    static assert(D11.sizeof == 16 && D11.alignof == 16);
    static assert(D12.sizeof == 16 && D12.alignof == 16);
    static assert(D13.sizeof == 16 && D13.alignof == 16);
    static assert(D14.sizeof == 16 && D14.alignof == 16);

    // Zero sized arrays
    static assert(D5.sizeof == 1 && D5.alignof == 1);
    static assert(D6.sizeof == 2 && D6.alignof == 2);
    static assert(D7.sizeof == 4 && D7.alignof == 4);
    static assert(D8.sizeof == 8 && D8.alignof == 8);
    static assert(D15.sizeof == 16 && D15.alignof == 16);
    static assert(D16.sizeof == 16 && D16.alignof == 16);
    static assert(D17.sizeof == 16 && D17.alignof == 16);
    static assert(D18.sizeof == 16 && D18.alignof == 16);

    // Mixed zero sized bitfields and arrays
    static assert(D9.sizeof == 2 && D9.alignof == 2);
    static assert(D19.sizeof == 16 && D19.alignof == 16);

    // Empty
    static assert(C0.sizeof == 0 && C0.alignof == 1);
    static assert(C10.sizeof == 0 && C10.alignof == 16);

    // Zero width bitfields
    static assert(C1.sizeof == 0 && C1.alignof == 1);
    static assert(C2.sizeof == 0 && C2.alignof == 1);
    static assert(C3.sizeof == 0 && C3.alignof == 1);
    static assert(C4.sizeof == 0 && C4.alignof == 1);
    static assert(C11.sizeof == 0 && C11.alignof == 16);
    static assert(C12.sizeof == 0 && C12.alignof == 16);
    static assert(C13.sizeof == 0 && C13.alignof == 16);
    static assert(C14.sizeof == 0 && C14.alignof == 16);

    // Zero sized arrays
    static assert(C5.sizeof == 0 && C5.alignof == 1);
    static assert(C6.sizeof == 0 && C6.alignof == 2);
    static assert(C7.sizeof == 0 && C7.alignof == 4);
    static assert(C8.sizeof == 0 && C8.alignof == 8);
    static assert(C15.sizeof == 0 && C15.alignof == 16);
    static assert(C16.sizeof == 0 && C16.alignof == 16);
    static assert(C17.sizeof == 0 && C17.alignof == 16);
    static assert(C18.sizeof == 0 && C18.alignof == 16);

    // Mixed zero sized bitfields and arrays
    static assert(C9.sizeof == 0 && C9.alignof == 2);
    static assert(C19.sizeof == 0 && C19.alignof == 16);
}

// Anonymous bitfields *do* contribute to alignment.
version (AArch64)
{
    // Empty
    static assert(D0.sizeof == 1 && D0.alignof == 1);
    static assert(D10.sizeof == 16 && D10.alignof == 16);

    // Zero width bitfields
    static assert(D1.sizeof == 1 && D1.alignof == 1);
    static assert(D2.sizeof == 2 && D2.alignof == 2);
    static assert(D3.sizeof == 4 && D3.alignof == 4);
    static assert(D4.sizeof == 8 && D4.alignof == 8);
    static assert(D11.sizeof == 16 && D11.alignof == 16);
    static assert(D12.sizeof == 16 && D12.alignof == 16);
    static assert(D13.sizeof == 16 && D13.alignof == 16);
    static assert(D14.sizeof == 16 && D14.alignof == 16);

    // Zero sized arrays
    static assert(D5.sizeof == 1 && D5.alignof == 1);
    static assert(D6.sizeof == 2 && D6.alignof == 2);
    static assert(D7.sizeof == 3 && D7.alignof == 4);
    static assert(D8.sizeof == 4 && D8.alignof == 8);
    static assert(D15.sizeof == 16 && D15.alignof == 16);
    static assert(D16.sizeof == 16 && D16.alignof == 16);
    static assert(D17.sizeof == 16 && D17.alignof == 16);
    static assert(D18.sizeof == 16 && D18.alignof == 16);

    // Mixed zero sized bitfields and arrays
    static assert(D9.sizeof == 4 && D9.alignof == 4);
    static assert(D19.sizeof == 16 && D19.alignof == 16);

    /// extern(C):

    // Empty
    static assert(C0.sizeof == 0 && C0.alignof == 1);
    static assert(C10.sizeof == 0 && C10.alignof == 16);

    // Zero width bitfields
    static assert(C1.sizeof == 0 && C1.alignof == 1);
    static assert(C2.sizeof == 0 && C2.alignof == 2);
    static assert(C3.sizeof == 0 && C3.alignof == 4);
    static assert(C4.sizeof == 0 && C4.alignof == 8);
    static assert(C11.sizeof == 0 && C11.alignof == 16);
    static assert(C12.sizeof == 0 && C12.alignof == 16);
    static assert(C13.sizeof == 0 && C13.alignof == 16);
    static assert(C14.sizeof == 0 && C14.alignof == 16);

    // Zero sized arrays
    static assert(C5.sizeof == 0 && C5.alignof == 1);
    static assert(C6.sizeof == 0 && C6.alignof == 2);
    static assert(C7.sizeof == 0 && C7.alignof == 4);
    static assert(C8.sizeof == 0 && C8.alignof == 8);
    static assert(C15.sizeof == 0 && C15.alignof == 16);
    static assert(C16.sizeof == 0 && C16.alignof == 16);
    static assert(C17.sizeof == 0 && C17.alignof == 16);
    static assert(C18.sizeof == 0 && C18.alignof == 16);

    // Mixed zero sized bitfields and arrays
    static assert(C9.sizeof == 0 && C9.alignof == 4);
    static assert(C19.sizeof == 0 && C19.alignof == 16);
}
