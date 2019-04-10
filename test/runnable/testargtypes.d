
void chkArgTypes(S, V...)()
{
    pragma(msg, S);
    static if (is(S U == __argTypes))
    {
        foreach (T; U) { pragma(msg, T); }
        static assert(U.length == V.length);
        foreach (i, T; U)
            static assert(is(V[i] == T));
    }
    else
        static assert(0);
}

void chkSingle(T,U)()
{
    struct S { T a; }
    chkArgTypes!(S, U)();
}

void chkIdentity(T)()
{
    chkSingle!(T,T)();
}

void chkPair(T,U,V)()
{
    struct S { T a; U b; }
    chkArgTypes!(S, V)();
}

version (Posix) version (X86_64) version = Posix_X86_64;

version (Posix_X86_64)
{
    int main()
    {
        chkIdentity!byte();
        chkIdentity!short();
        chkIdentity!int();
        chkIdentity!long();

        version (DigitalMars)
        {
            chkIdentity!ubyte();
            chkIdentity!ushort();
            chkIdentity!uint();
            chkIdentity!ulong();

            chkSingle!(char,  ubyte)();
            chkSingle!(wchar, ushort)();
            chkSingle!(dchar, uint)();
        }
        else
        {
            chkSingle!(ubyte,  byte)();
            chkSingle!(ushort, short)();
            chkSingle!(uint,   int)();
            chkSingle!(ulong,  long)();

            chkSingle!(char,  byte)();
            chkSingle!(wchar, short)();
            chkSingle!(dchar, int)();
        }

        chkIdentity!float();
        chkIdentity!double();
        chkIdentity!real();

        version (DigitalMars)
            chkIdentity!(void*)();
        else
            chkSingle!(void*, ptrdiff_t)();

        version (DigitalMars)
        {
            chkIdentity!(__vector(byte[16]))();
            chkIdentity!(__vector(ubyte[16]))();
            chkIdentity!(__vector(short[8]))();
            chkIdentity!(__vector(ushort[8]))();
            chkIdentity!(__vector(int[4]))();
            chkIdentity!(__vector(uint[4]))();
            chkIdentity!(__vector(long[2]))();
            chkIdentity!(__vector(ulong[2]))();

            chkIdentity!(__vector(float[4]))();
            chkIdentity!(__vector(double[2]))();
        }
        else
        {
            chkSingle!(__vector(byte[16]),  __vector(double[2]))();
            chkSingle!(__vector(ubyte[16]), __vector(double[2]))();
            chkSingle!(__vector(short[8]),  __vector(double[2]))();
            chkSingle!(__vector(ushort[8]), __vector(double[2]))();
            chkSingle!(__vector(int[4]),    __vector(double[2]))();
            chkSingle!(__vector(uint[4]),   __vector(double[2]))();
            chkSingle!(__vector(long[2]),   __vector(double[2]))();
            chkSingle!(__vector(ulong[2]),  __vector(double[2]))();

            chkSingle!(__vector(float[4]),  __vector(double[2]))();
            chkSingle!(__vector(double[2]), __vector(double[2]))();

            version (D_AVX)
                chkSingle!(__vector(int[8]), __vector(double[4]))();
        }

        chkPair!(byte,  byte,  short);
        chkPair!(ubyte, ubyte, short);
        chkPair!(short, short, int);
        chkPair!(int,   int,   long);

        chkPair!(byte,  short, int);
        chkPair!(short, byte,  int);

        chkPair!(int,   float, long);
        chkPair!(float, int,   long);
        chkPair!(byte,  float, long);
        chkPair!(float, short, long);

        struct S1 { long a; long b; }
        chkArgTypes!(S1, long, long)();

        struct S2 { union { long a; double d; }}
        chkArgTypes!(S2, long)();

        struct S3 { union { double d; long a; }}
        chkArgTypes!(S3, long)();

        struct S4 { int a,b,c,d,e; }
        chkArgTypes!(S4)();

        struct S5 { align(1): char a; int b; }
        chkArgTypes!(S5)();

        struct S6 { align(1): int a; void* b; }
        chkArgTypes!(S6)();

        struct S7 { union { void* p; real r; }}
        chkArgTypes!(S7)();

        struct S8 { union { real r; void* p; }}
        chkArgTypes!(S8)();

        struct S9 { int a,b,c; }
        chkArgTypes!(S9, long, int)();
        chkArgTypes!(S9[1], long, int)();

        struct S10 { int[3] a; }
        chkArgTypes!(S10, long, int)();

        struct S11 { float a; struct { float b; float c; } }
        chkArgTypes!(S11, double, float)();

        struct RGB { ubyte r, g, b; }
        chkArgTypes!(RGB, int)();

        chkArgTypes!(int[3], long, int)();

        struct S12 { align(16) int a; }
        version (DigitalMars)
            chkArgTypes!(S12, int)();
        else
            chkArgTypes!(S12, long)();

        version (DigitalMars)
        {
        }
        else
        {
            struct S13 { short a; cfloat b; }
            chkArgTypes!(S13, long, float)();

            struct S13957 { double a; ulong b; }
            chkArgTypes!(S13957, double, long)();
        }

        return 0;
    }
}
else
{
    int main()
    {
        return 0;
    }
}
