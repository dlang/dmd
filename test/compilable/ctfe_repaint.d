version (LittleEndian)
    enum isLE = true;
else
    enum isLE = false;

static assert (0x3F == {
    float f = 1.5f;
    return (*(cast(ubyte[4]*) &f))[isLE ? 3 : 0];
}());

// FIXME: This code executes under CTFE, but does the wrong thing:
static assert (-1.5f == {
    float f = 1.5f;
    (*(cast(ubyte[4]*) &f))[isLE ? 3 : 0] = 0xBF;
    return f;
}());

static assert (float.min_normal > {
    uint u = 0x007F_FFFFu;
    return *(cast(float*) &u);
}());

static assert (0x7FEF_FFFF_FFFF_FFFFuL == {
    double d = double.max;
    return *(cast(ulong*) &d);
}());

static assert (isLE ? [0, 0xFFF0_0000u] : [0xFFF0_0000u, 0] == {
    double d = -double.infinity;
    return *(cast(uint[2]*) &d);
}());

static assert ({
    ulong u = 0x7FF0_0000_0050_0000uL; // NaN
    return *(cast(double*) &u) != *(cast(double*) &u);
}());

static assert (0.0 == {
    ulong u = 0;
    return *(cast(double*) &u);
}());

// TODO: Test real.

// Bugzilla 14207
ubyte[8] ulongBytes()
{
    immutable ulong x = 1;
    return *cast(ubyte[8]*) &x;
}

auto digest()
{
    ubyte[8] bytes = ulongBytes();
    return bytes;
}

enum got = digest();
enum ubyte[8] expect = [isLE, 0, 0, 0, 0, 0, 0, !isLE];
static assert (got == expect);
