import core.simd;

version (D_AVX)
{
    __vector(ubyte[16]) test(ubyte val) { return val; }
    __vector(ubyte[16]) test(ubyte* pval) { return *pval; }
    __vector(byte[16]) test(byte val) { return val; }
    __vector(byte[16]) test(byte* pval) { return *pval; }

    __vector(ushort[8]) test(ushort val) { return val; }
    __vector(ushort[8]) test(ushort* pval) { return *pval; }
    __vector(short[8]) test(short val) { return val; }
    __vector(short[8]) test(short* pval) { return *pval; }

    __vector(uint[4]) test(uint val) { return val; }
    __vector(uint[4]) test(uint* pval) { return *pval; }
    __vector(int[4]) test(int val) { return val; }
    __vector(int[4]) test(int* pval) { return *pval; }

    __vector(ulong[2]) test(ulong val) { return val; }
    __vector(ulong[2]) test(ulong* pval) { return *pval; }
    __vector(long[2]) test(long val) { return val; }
    __vector(long[2]) test(long* pval) { return *pval; }

    __vector(float[4]) test(float val) { return val; }
    __vector(float[4]) test(float* pval) { return *pval; }
    __vector(double[2]) test(double val) { return val; }
    __vector(double[2]) test(double* pval) { return *pval; }

    __vector(ubyte[32]) test2(ubyte val) { return val; }
    __vector(ubyte[32]) test2(ubyte* pval) { return *pval; }
    __vector(byte[32]) test2(byte val) { return val; }
    __vector(byte[32]) test2(byte* pval) { return *pval; }

    __vector(ushort[16]) test2(ushort val) { return val; }
    __vector(ushort[16]) test2(ushort* pval) { return *pval; }
    __vector(short[16]) test2(short val) { return val; }
    __vector(short[16]) test2(short* pval) { return *pval; }

    __vector(uint[8]) test2(uint val) { return val; }
    __vector(uint[8]) test2(uint* pval) { return *pval; }
    __vector(int[8]) test2(int val) { return val; }
    __vector(int[8]) test2(int* pval) { return *pval; }

    __vector(ulong[4]) test2(ulong val) { return val; }
    __vector(ulong[4]) test2(ulong* pval) { return *pval; }
    __vector(long[4]) test2(long val) { return val; }
    __vector(long[4]) test2(long* pval) { return *pval; }

    __vector(float[8]) test2(float val) { return val; }
    __vector(float[8]) test2(float* pval) { return *pval; }
    __vector(double[4]) test2(double val) { return val; }
    __vector(double[4]) test2(double* pval) { return *pval; }
}
else version (D_AVX)
{
    __vector(ubyte[16]) test(ubyte val) { return val; }
    __vector(ubyte[16]) test(ubyte* pval) { return *pval; }
    __vector(byte[16]) test(byte val) { return val; }
    __vector(byte[16]) test(byte* pval) { return *pval; }

    __vector(ushort[8]) test(ushort val) { return val; }
    __vector(ushort[8]) test(ushort* pval) { return *pval; }
    __vector(short[8]) test(short val) { return val; }
    __vector(short[8]) test(short* pval) { return *pval; }

    __vector(uint[4]) test(uint val) { return val; }
    __vector(uint[4]) test(uint* pval) { return *pval; }
    __vector(int[4]) test(int val) { return val; }
    __vector(int[4]) test(int* pval) { return *pval; }

    __vector(ulong[2]) test(ulong val) { return val; }
    __vector(ulong[2]) test(ulong* pval) { return *pval; }
    __vector(long[2]) test(long val) { return val; }
    __vector(long[2]) test(long* pval) { return *pval; }

    __vector(float[4]) test(float val) { return val; }
    __vector(float[4]) test(float* pval) { return *pval; }
    __vector(double[2]) test(double val) { return val; }
    __vector(double[2]) test(double* pval) { return *pval; }

    __vector(ubyte[32]) test2(ubyte val) { return val; }
    __vector(ubyte[32]) test2(ubyte* pval) { return *pval; }
    __vector(byte[32]) test2(byte val) { return val; }
    __vector(byte[32]) test2(byte* pval) { return *pval; }

    __vector(ushort[16]) test2(ushort val) { return val; }
    __vector(ushort[16]) test2(ushort* pval) { return *pval; }
    __vector(short[16]) test2(short val) { return val; }
    __vector(short[16]) test2(short* pval) { return *pval; }

    __vector(uint[8]) test2(uint val) { return val; }
    __vector(uint[8]) test2(uint* pval) { return *pval; }
    __vector(int[8]) test2(int val) { return val; }
    __vector(int[8]) test2(int* pval) { return *pval; }

    __vector(ulong[4]) test2(ulong val) { return val; }
    __vector(ulong[4]) test2(ulong* pval) { return *pval; }
    __vector(long[4]) test2(long val) { return val; }
    __vector(long[4]) test2(long* pval) { return *pval; }

    __vector(float[8]) test2(float val) { return val; }
    __vector(float[8]) test2(float* pval) { return *pval; }
    __vector(double[4]) test2(double val) { return val; }
    __vector(double[4]) test2(double* pval) { return *pval; }
}
else
{
    __vector(ubyte[16]) test(ubyte val) { return val; }
    __vector(ubyte[16]) test(ubyte* pval) { return *pval; }
    __vector(byte[16]) test(byte val) { return val; }
    __vector(byte[16]) test(byte* pval) { return *pval; }

    __vector(ushort[8]) test(ushort val) { return val; }
    __vector(ushort[8]) test(ushort* pval) { return *pval; }
    __vector(short[8]) test(short val) { return val; }
    __vector(short[8]) test(short* pval) { return *pval; }

    __vector(uint[4]) test(uint val) { return val; }
    __vector(uint[4]) test(uint* pval) { return *pval; }
    __vector(int[4]) test(int val) { return val; }
    __vector(int[4]) test(int* pval) { return *pval; }

    __vector(ulong[2]) test(ulong val) { return val; }
    __vector(ulong[2]) test(ulong* pval) { return *pval; }
    __vector(long[2]) test(long val) { return val; }
    __vector(long[2]) test(long* pval) { return *pval; }

    __vector(float[4]) test(float val) { return val; }
    __vector(float[4]) test(float* pval) { return *pval; }
    __vector(double[2]) test(double val) { return val; }
    __vector(double[2]) test(double* pval) { return *pval; }
}
